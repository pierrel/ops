param ($VMName, $Domain, $RGName)

# Clean up the RG is if it exists already
# TODO: change this to check for everything and just update the ssl cert if
#       everything else looks good
$ExistingRG = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -eq $RGName}
If ($ExistingRG) {
    Write-Host "Resource Group " $RGName " exists, removing."
    Remove-AzResourceGroup -Name $RGName -Force
    # Write-Host "Done, exiting."
    # Exit
}

# Get the vm, ipconfig, vnet
$vm = Get-AzVm -Name $VMName
$location = $vm.Location
$interface = Get-AzNetworkInterface | Where-Object {$_.VirtualMachine.Id -EQ $vm.Id}
$beipconfig = $interface.IpConfigurations | Where-Object {$_.Primary -eq "True"}
$vmsubnet = $interface.IpConfigurations.Subnet
# If (!$vmsubnet.AddressPrefix) {
#     Write-Host "Oh no!"
#     Exit
# } Else {
#     Write-Host "OK..."
#     Exit
# }
#$subnetId = $subnet.Id
#$vnet = Get-AzVirtualNetwork -Name ($subnetid -split "/")[-3] # there must be a better way...

# Generate the cert
$Out = "cert.pfx"
$CertName = $Domain + "-cert"
$path = "/etc/letsencrypt/live/"
$inkey = $path + $Domain + "/privkey.pem"
$in = $path + $Domain + "/cert.pem"
$certfile = $path + $Domain + "/chain.pem"
$Password = -join ((33..126) | Get-Random -Count 32 | % {[char]$_})
$SPassword = ConvertTo-SecureString $Password -AsPlainText -Force

sudo openssl pkcs12 -export -out $Out -inkey $inkey -in $in -certfile $certfile -password pass:$Password
sudo chmod ugo+r $Out
$CertPath = Resolve-Path $Out

# Dummy RG so that I can destroy it quickly
$RG = New-AzResourceGroup -Name $RGName -Location $location

# Create a network-y stuff for the Gateway
$agSubnetConfig = New-AzVirtualNetworkSubnetConfig `
  -Name myAGSubnet `
  -AddressPrefix 10.0.2.0/24
$vnet = New-AzVirtualNetwork `
  -ResourceGroupName $RGName `
  -Location $location `
  -Name agVNet `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $vmsubnet,$agSubnetConfig

$pip = New-AzPublicIpAddress `
  -ResourceGroupName $RGName `
  -Location $location `
  -Name "test-gateway-ip-quirozlarochelle" `
  -AllocationMethod Dynamic `
  -Sku "Basic"

$gipconfig = New-AzApplicationGatewayIPConfiguration -Name "AGIPConfig" -Subnet $agSubnetConfig

$fipconfig = New-AzApplicationGatewayFrontendIPConfig -Name "AGFEIPConfig" -PublicIPAddress $pip

$frontendport = New-AzApplicationGatewayFrontendPort -Name "AFFEPort" -Port 443

$defaultPool = New-AzApplicationGatewayBackendAddressPool  -Name appGatewayBackendPool
$poolSettings = New-AzApplicationGatewayBackendHttpSettings `
  -Name myPoolSettings `
  -Port 80 `
  -Protocol Http `
  -CookieBasedAffinity Enabled `
  -RequestTimeout 120

$cert = New-AzApplicationGatewaySslCertificate -Name $CertName -CertificateFile $CertPath -Password $SPassword

$defaultlistener = New-AzApplicationGatewayHttpListener `
  -Name mydefaultListener `
  -Protocol Https `
  -FrontendIPConfiguration $fipconfig `
  -FrontendPort $frontendport `
  -SslCertificate $cert

$frontendRule = New-AzApplicationGatewayRequestRoutingRule `
  -Name rule1 `
  -RuleType "Basic"`
  -HttpListener $defaultlistener `
  -BackendAddressPool $defaultPool `
  -BackendHttpSettings $poolSettings

$sku = New-AzApplicationGatewaySku `
  -Name "Standard_Small" `
  -Tier "Standard" `
  -Capacity 1

$appgw = New-AzApplicationGateway `
  -Name myAppGateway `
  -ResourceGroupName $RGName `
  -Location $location`
  -BackendAddressPools $defaultPool `
  -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig `
  -GatewayIpConfigurations $gipconfig `
  -FrontendPorts $frontendport `
  -HttpListeners $defaultlistener `
  -RequestRoutingRules $frontendRule `
  -Sku $sku `
  -SslCertificates $cert

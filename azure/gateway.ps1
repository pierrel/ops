param ($VMName, $Domain)

# Get the vm, ipconfig, vnet
$vm = Get-AzVm -Name $VMName
$interface = Get-AzNetworkInterface | Where-Object {$_.VirtualMachine.Id -EQ $vm.Id}
$beipconfig = $interface.IpConfigurations | Where-Object {$_.Primary -eq "True"}
$subnet = $interface.IpConfigurations.Subnet
$subnetId = $subnet.Id
$vnet = Get-AzVirtualNetwork -Name ($subnetid -split "/")[-3] # there must be a better way...

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
$RGName = "api-gateway-testing-quirozlarochelle"
$RG = New-AzResourceGroup -Name $RGName -Location westus2
$pip = New-AzPublicIpAddress `
  -ResourceGroupName $RGName `
  -Location westus2 `
  -Name "test-gateway-ip-quirozlarochelle" `
  -AllocationMethod Static `
  -Sku "Standard"

$gipconfig = New-AzApplicationGatewayIPConfiguration -Name "AGIPConfig" -Subnet $subnet

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
  -Location westus2`
  -BackendAddressPools $defaultPool `
  -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig `
  -GatewayIpConfigurations $gipconfig `
  -FrontendPorts $frontendport `
  -HttpListeners $defaultlistener `
  -RequestRoutingRules $frontendRule `
  -Sku $sku `
  -SslCertificates $cert

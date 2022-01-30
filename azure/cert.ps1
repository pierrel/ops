param ($Domain, $GatewayName)

if (-Not $Domain) {
    throw "Domain param must be specified"
}
if (-Not $GatewayName) {
    throw "GatewayName parameter must be specified"
}

$Out = "cert.pfx"
$CertName = $Domain + "-cert"

$Gateway = Get-AzApplicationGateway -Name $GatewayName

$path = "/etc/letsencrypt/live/"
$inkey = $path + $Domain + "/privkey.pem"
$in = $path + $Domain + "/cert.pem"
$certfile = $path + $Domain + "/chain.pem"
$Password = -join ((33..126) | Get-Random -Count 32 | % {[char]$_})
$SPassword = ConvertTo-SecureString $Password -AsPlainText -Force

sudo openssl pkcs12 -export -out $Out -inkey $inkey -in $in -certfile $certfile -password pass:$Password
sudo chmod ugo+r $Out
$CertPath = Resolve-Path $Out

# For some reason creating the cert and adding it doesn't work
$newCert = New-AzApplicationGatewaySslCertificate -CertificateFile $CertPath -Name $CertName -Password $SPassword
Add-AzApplicationGatewaySslCertificate -ApplicationGateway $Gateway -Name $CertName
sudo rm -f $Out

$Listener = Get-AzApplicationGatewayHttpListener -ApplicationGateway $Gateway | `
  Where-Object {($_.HostName -eq $Domain) -and ($_.Protocol -eq "Https")}

# Not even here
Set-AzApplicationGatewayHttpListener -Name $Listener.Name -ApplicationGateway $Gateway -SslCertificate $newCert -Protocol "Https"

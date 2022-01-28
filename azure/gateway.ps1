param ($VMName)

$vm = Get-AzVm -Name $VMName
$interface = Get-AzNetworkInterface | Where-Object {$_.VirtualMachine.Id -EQ $vm.Id}
$ipconfig = $interface.IpConfigurations[0] # Maybe there's another way, if there are others?..
$subnetId = $interface.IpConfigurations.Subnet.Id
$vnet = Get-AzVirtualNetwork -Name ($subnetid -split "/")[-3] # there must be a better way...

# I also have to create a backend pool and some other stuff. Really not done yet.

Write-Output $ipconfig

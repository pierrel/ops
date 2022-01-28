Connect-AzAccount -UseDeviceAuthentication

Get-AzSubscription | Where-Object {$_.Name -like "*Studio*"} | Set-AzContext

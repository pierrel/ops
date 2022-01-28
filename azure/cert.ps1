param ($ResourceGroup, $Name)

New-AzKeyVault -Name $Name -ResourceGroup $ResourceGroup -Location "westus3"

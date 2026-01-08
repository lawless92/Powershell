
# Connect to ESXi hosts
$esxiHostTst1 = "10.32.136.14"
$esxiHostTst2 = "10.32.136.7"
$esxiHostZgz = "10.32.143.4"

$credential = Get-Credential
Connect-VIServer -Server $esxiHostZgz  -Credential $credential

# Shut down  virtual machines
$vmNames = @("ESTACNS01APP", "ESTACNS01DB", "ESTACNS01SRV" )
foreach ($vmName in $vmNames) {
    Stop-VM -VM $vmName -Confirm:$false
}

# Put ESXi host into maintenance mode
Set-VMHost -VMHost $esxiHostZgz -State Maintenance

# Power off the ESXi host
Shutdown-VMHost -VMHost $esxiHostZgz -Confirm:$false

# Instructions for manual power-on
Write-Host "Please manually power on the ESXi host."

# Exit maintenance mode after manual power-on
Set-VMHost -VMHost $esxiHostZgz      -State Connected

# Power on the virtual machines
foreach ($vmName in $vmNames) {
    Start-VM -VM $vmName
}

# Disconnect from ESXi host
Disconnect-VIServer -Server $esxiHostZgz -Confirm:$false

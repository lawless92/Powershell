
#Listado de servidores
HostsList = @("ESTACNS01APP", "ESTACNS01DB", "ESTACNS01SRV","ESTACNS01FS", "ESTACNS01AS", "ESTACNS02AS", "ESTACNS03AS")




$InfoMonitoring = @{

    Date = Get-Date
    $FreeSpace = (Get-PSDrive -PSProvider C ).Free
    $UsedSpace = (Get-PSDrive -PSProvider C ).Used
    $TotalSpace = (Get-PSDrive -PSProvider C ).Size
    $PercentFree = (Get-PSDrive -PSProvider C ).Free / (Get-PSDrive -PSProvider C ).Size * 100
    $PercentUsed = (Get-PSDrive -PSProvider C ).Used / (Get-PSDrive -PSProvider C ).Size * 100
    $TopCpu = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
    $TopMemory = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5
    $checkUpdates = Get-HotFix | Sort-Object -Property Installed  -Descending | Select-Object -First 3

}

foreach ($Host in $HostsList) {
    Invoke-Command -ComputerName $Host -ScriptBlock { $InfoMonitoring }
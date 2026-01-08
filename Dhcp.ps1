
# $ScopeTauste = 10.32.136.0 
# $ScopeAruba = 10.32.138.0 
# $ScopeIvitados = 10.32.138.128
# $ScopeVideoCamras = 10.32.139.50
# $ScopeFactory = 10.32.140.40


$scopes = @{
    # Main network scope
    "ScopeTauste"        = "10.32.136.0"
    
    # Aruba network equipment scope
    "ScopeAruba"         = "10.32.138.0"
    
    # Guest network scope
    "ScopeInvitados"     = "10.32.138.128"
    
    # Video surveillance cameras scope
    "ScopeVideoCamaras"  = "10.32.139.0"
    
    # Factory equipment scope
    "ScopeFactory"       = "10.32.140.0"
}



$totalFreeIPs = 0
$totalUsedIPs = 0

foreach ($scope in $scopes) {
    try {
        $scopeInfo = Get-DhcpServerv4Scope -ScopeId $scope
        $scopeStats = Get-DhcpServerv4ScopeStatistics -ScopeId $scope

        $freeIPs = $scopeStats.Free
        $usedIPs = $scopeStats.InUse

        $totalFreeIPs += $freeIPs
        $totalUsedIPs += $usedIPs

        Write-Host "Scope: $scope"
        Write-Host "Free IPs: $freeIPs"
        Write-Host "Used IPs: $usedIPs"
        Write-Host "Percentage Used: $([math]::round(($usedIPs / ($freeIPs + $usedIPs)) * 100, 2))%"
        Write-Host "----------------------------------------"
    } catch {
        Write-Host "Error consultando el scope $scope. Verifica que esté configurado correctamente."
    }
}

Write-Host "Resumen General:"
Write-Host "Total Free IPs: $totalFreeIPs"
Write-Host "Total Used IPs: $totalUsedIPs"
Write-Host "Overall Percentage Used: $([math]::round(($totalUsedIPs / ($totalFreeIPs + $totalUsedIPs)) * 100, 2))%"


if ($stats.InUse / ($stats.Free + $stats.InUse) -gt 0.8) {
    Write-Warning "¡Atención! El scope $scope está por encima del 80% de uso."
}


Get-DhcpServerv4Lease -ScopeId $scope | Where-Object { $_.AddressState -eq "Inactive" -or $_.LeaseExpiryTime -lt (Get-Date) }

Get-DhcpServerv4Conflict

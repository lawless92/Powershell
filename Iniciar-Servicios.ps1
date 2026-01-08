
Get-Service | Where-Object {$_.Status -eq "Stopped"} | Select-Object Name, DisplayName, Status

# Obtener servicios detenidos
$stoppedServices = Get-Service | Where-Object {$_.Status -eq "Stopped"}

# Iniciar cada servicio detenido
foreach ($service in $stoppedServices) {
    try {
        Start-Service -Name $service.Name
        Write-Host "Servicio iniciado: $($service.DisplayName)" -ForegroundColor Green
    } catch {
        Write-Host "No se pudo iniciar el servicio: $($service.DisplayName). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
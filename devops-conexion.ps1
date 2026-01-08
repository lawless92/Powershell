
# Get parameters from environment variables or use defaults
$RemoteServer = if ($env:REMOTE_SERVER) { $env:REMOTE_SERVER } else { "ESTACNS01APP" }
$PrimarySiteName = if ($env:PRIMARY_SITE_NAME) { $env:PRIMARY_SITE_NAME } else { "Nexus.Gateway" }
$PrimarySiteBak = if ($env:PRIMARY_SITE_BAK) { $env:PRIMARY_SITE_BAK } else { "Nexus.Gateway.BAK" }
$SecondarySiteName = if ($env:SECONDARY_SITE_NAME) { $env:SECONDARY_SITE_NAME } else { "NNexus.Gateway" }
$SecondarySiteBak = if ($env:SECONDARY_SITE_BAK) { $env:SECONDARY_SITE_BAK } else { "NNexus.Gateway.BAK" }

# Los de paremetros usados
Write-Output "=== Script Parameters ==="
Write-Output "RemoteServer: $RemoteServer"
Write-Output "PrimarySiteName: $PrimarySiteName"
Write-Output "PrimarySiteBak: $PrimarySiteBak"
Write-Output "SecondarySiteName: $SecondarySiteName"
Write-Output "SecondarySiteBak: $SecondarySiteBak"
Write-Output "========================="

#Funcion para obtener el estado del sitio web
function Get-WebsiteState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 5
    )
    
    $retryCount = 0
    $session = $null
    
    while ($retryCount -lt $MaxRetries) {
        try {
            $session = New-PSSession -ComputerName $ServerName -ErrorAction Stop
            
            $rawState = Invoke-Command -Session $session -ScriptBlock {
                param($SiteName)
                try {
                    $site = Get-Website -Name $SiteName -ErrorAction Stop
                    Write-Host "[DEBUG] Sitio encontrado: $($site.Name) - Estado: $($site.State)" -ForegroundColor Cyan
                    # Devolver solo el estado sin texto adicional
                    return @{
                        State = $site.State.ToString()
                        Name = $site.Name
                    }
                }
                catch {
                    Write-Host "[DEBUG] Error al obtener el sitio '$SiteName': $_" -ForegroundColor Yellow
                    throw $_
                }
            } -ArgumentList $SiteName -ErrorAction Stop
            
            # Extraer el estado del objeto devuelto
            $state = $rawState.State
            Write-Host "[DEBUG] Estado de '$($rawState.Name)': $state" -ForegroundColor Cyan
            return $state
        }
        catch {
            $retryCount++
            $errorMessage = $_.Exception.Message
            
            if ($retryCount -ge $MaxRetries) {
                Write-Error "Error al obtener el estado del sitio '$SiteName' después de $MaxRetries intentos: $errorMessage"
                return $null
            }
            
            Write-Warning "Intento $retryCount/$MaxRetries fallido para '$SiteName'. Reintentando en $RetryDelay segundos..."
            Write-Warning "Error: $errorMessage"
            Start-Sleep -Seconds $RetryDelay
        }
        finally {
            if ($null -ne $session) {
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
                $session = $null
            }
        }
    }
    
    return $null
}

#Funcion para iniciar o detener el sitio web
function Set-WebsiteState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerName,
        [Parameter(Mandatory=$true)]
        [string]$SiteName,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start','Stop')]
        [string]$Action,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 5
    )
    
    $retryCount = 0
    $session = $null
    $actionVerb = if ($Action -eq 'Stop') { 'detener' } else { 'iniciar' }
    
    while ($retryCount -lt $MaxRetries) {
        try {
            $session = New-PSSession -ComputerName $ServerName -ErrorAction Stop
            
            $result = Invoke-Command -Session $session -ScriptBlock {
                param($SiteName, $Action)
                
                try {
                    # Verificar si el sitio existe
                    $website = Get-Website -Name $SiteName -ErrorAction Stop
                    
                    if ($Action -eq 'Stop') {
                        if ($website.State -eq 'Stopped') {
                            Write-Host "[DEBUG] El sitio '$SiteName' ya está detenido" -ForegroundColor Cyan
                            return "Sitio web '$SiteName' ya estaba detenido"
                        }
                        Write-Host "[DEBUG] Deteniendo el sitio: $SiteName" -ForegroundColor Cyan
                        Stop-Website -Name $SiteName -ErrorAction Stop
                        return "Sitio web '$SiteName' detenido correctamente"
                    }
                    else {
                        if ($website.State -eq 'Started') {
                            Write-Host "[DEBUG] El sitio '$SiteName' ya está iniciado" -ForegroundColor Cyan
                            return "Sitio web '$SiteName' ya estaba iniciado"
                        }
                        Write-Host "[DEBUG] Iniciando el sitio: $SiteName" -ForegroundColor Cyan
                        Start-Website -Name $SiteName -ErrorAction Stop
                        return "Sitio web '$SiteName' iniciado correctamente"
                    }
                }
                catch {
                    Write-Host "[DEBUG] Error en el bloque de script remoto ($Action): $_" -ForegroundColor Red
                    throw $_
                }
            } -ArgumentList $SiteName, $Action -ErrorAction Stop
            
            Write-Output $result
            
            # Verificar el estado después de la acción con un pequeño retraso
            Start-Sleep -Seconds 2
            $state = Get-WebsiteState -ServerName $ServerName -SiteName $SiteName -MaxRetries 3 -RetryDelay 2
            $expectedState = if ($Action -eq 'Stop') { 'Stopped' } else { 'Started' }
            
            # Hacer la comparación de estado insensible a mayúsculas/minúsculas y espacios
            if ($state -ine $expectedState) {
                throw "El sitio no alcanzó el estado esperado '$expectedState' después de la operación. Estado actual: $state"
            } else {
                Write-Host "[DEBUG] Verificación de estado exitosa: $SiteName está en estado '$state'" -ForegroundColor Green
            }
            
            return $true
        }
        catch {
            $retryCount++
            $errorMessage = $_.Exception.Message
            
            if ($retryCount -ge $MaxRetries) {
                Write-Error "Error al $actionVerb el sitio '$SiteName' después de $MaxRetries intentos: $errorMessage"
                return $false
            }
            
            Write-Warning "Intento $retryCount/$MaxRetries fallado al $actionVerb '$SiteName'. Reintentando en $RetryDelay segundos..."
            Write-Warning "Error: $errorMessage"
            Start-Sleep -Seconds $RetryDelay
        }
        finally {
            if ($null -ne $session) {
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
                $session = $null
            }
        }
    }
    
    return $false
}

try {
    Write-Output "=== Iniciando el proceso de cambio a sitios de respaldo ==="
    
    # 1. Detener el sitio primario
    Write-Output "`n[PASO 1/4] Deteniendo el sitio primario '$PrimarySiteName'..."
    $success = Set-WebsiteState -ServerName $RemoteServer -SiteName $PrimarySiteName -Action 'Stop' -MaxRetries 3 -RetryDelay 10
    
    if ($success) {
        # Verificación adicional del estado del sitio primario
        $maxWaitTime = 60  # segundos
        $waitInterval = 5   # segundos
        $waitedTime = 0
        $primaryStopped = $false
        
        Write-Output "Verificando estado del sitio primario..."
        while ($waitedTime -lt $maxWaitTime -and -not $primaryStopped) {
            $primaryState = Get-WebsiteState -ServerName $RemoteServer -SiteName $PrimarySiteName -MaxRetries 2 -RetryDelay 2
            
            if ($primaryState -eq 'Stopped') {
                $primaryStopped = $true
                Write-Output "[OK] Sitio primario '$PrimarySiteName' se detuvo correctamente" -ForegroundColor Green
            } else {
                $remainingTime = $maxWaitTime - $waitedTime
                Write-Output "Esperando que el sitio primario se detenga... (Tiempo restante: ${remainingTime}s)"
                Start-Sleep -Seconds $waitInterval
                $waitedTime += $waitInterval
            }
        }
        
        if (-not $primaryStopped) {
            throw "No se pudo verificar que el sitio $PrimarySiteName se detuviera correctamente después de $maxWaitTime segundos"
        }
        
        # 2. Iniciar el sitio primario de respaldo
        if (-not [string]::IsNullOrEmpty($PrimarySiteBak)) {
            Write-Output "`n[PASO 2/4] Iniciando el sitio de respaldo primario '$PrimarySiteBak'..."
            
            # Verificar si el sitio de respaldo existe antes de intentar iniciarlo
            Write-Output "[DEBUG] Verificando si el sitio de respaldo existe..."
            $siteExists = $false
            try {
                $session = New-PSSession -ComputerName $RemoteServer -ErrorAction Stop
                $siteInfo = Invoke-Command -Session $session -ScriptBlock {
                    param($SiteName)
                    Get-Website -Name $SiteName -ErrorAction Stop
                } -ArgumentList $PrimarySiteBak -ErrorAction Stop
                $siteExists = $true
                Write-Output "[DEBUG] Sitio encontrado: $($siteInfo.Name) (Estado actual: $($siteInfo.State))"
            }
            catch {
                Write-Output "[DEBUG] No se pudo encontrar el sitio '$PrimarySiteBak': $_"
            }
            finally {
                if ($session) { Remove-PSSession -Session $session -ErrorAction SilentlyContinue }
            }
            
            if (-not $siteExists) {
                throw "El sitio de respaldo '$PrimarySiteBak' no existe en el servidor $RemoteServer"
            }
            
            # Intentar iniciar el sitio con más información de depuración
            Write-Output "[DEBUG] Intentando iniciar el sitio..."
            $success = Set-WebsiteState -ServerName $RemoteServer -SiteName $PrimarySiteBak -Action 'Start' -MaxRetries 3 -RetryDelay 10
            
            if ($success) {
                Write-Output "[DEBUG] Verificando estado después de iniciar..."
                $primaryBakState = Get-WebsiteState -ServerName $RemoteServer -SiteName $PrimarySiteBak -MaxRetries 3 -RetryDelay 5
                Write-Output "[DEBUG] Estado obtenido: $primaryBakState"
                
                if ($primaryBakState -ne 'Started') {
                    throw "No se pudo verificar que el sitio de respaldo $PrimarySiteBak se iniciara correctamente (Estado: $primaryBakState)"
                }
                Write-Output "[OK] Sitio de respaldo primario '$PrimarySiteBak' iniciado correctamente" -ForegroundColor Green
            }
            else {
                Write-Error "No se pudo iniciar el sitio de respaldo primario '$PrimarySiteBak'"
                # Intentar obtener más información sobre el error
                try {
                    $session = New-PSSession -ComputerName $RemoteServer -ErrorAction Stop
                    $errorDetails = Invoke-Command -Session $session -ScriptBlock {
                        param($SiteName)
                        try {
                            $site = Get-Website -Name $SiteName -ErrorAction Stop
                            return @{
                                Exists = $true
                                State = $site.State
                                Status = $site.Status
                            }
                        }
                        catch {
                            return @{
                                Exists = $false
                                Error = $_.Exception.Message
                            }
                        }
                    } -ArgumentList $PrimarySiteBak -ErrorAction Stop
                    
                    if ($errorDetails.Exists) {
                        Write-Output "[DEBUG] Estado del sitio: $($errorDetails.State) (Status: $($errorDetails.Status))"
                    }
                    else {
                        Write-Output "[DEBUG] El sitio no existe o no es accesible: $($errorDetails.Error)"
                    }
                }
                catch {
                    Write-Output "[DEBUG] No se pudo obtener información detallada del error: $_"
                }
                finally {
                    if ($session) { Remove-PSSession -Session $session -ErrorAction SilentlyContinue }
                }
                
                throw "No se pudo iniciar el sitio de respaldo primario. Verifica los permisos y la configuración del sitio."
            }
        }
        
        # 3. Detener el sitio secundario
        Write-Output "`n[PASO 3/4] Deteniendo el sitio secundario '$SecondarySiteName'..."
        $success = Set-WebsiteState -ServerName $RemoteServer -SiteName $SecondarySiteName -Action 'Stop' -MaxRetries 3 -RetryDelay 10
        
        if ($success) {
            $maxWaitTime = 60  # segundos
            $waitInterval = 5   # segundos
            $waitedTime = 0
            $secondaryStopped = $false
            
            Write-Output "Verificando estado del sitio secundario..."
            while ($waitedTime -lt $maxWaitTime -and -not $secondaryStopped) {
                $secondaryState = Get-WebsiteState -ServerName $RemoteServer -SiteName $SecondarySiteName -MaxRetries 2 -RetryDelay 2
                
                if ($secondaryState -eq 'Stopped') {
                    $secondaryStopped = $true
                    Write-Output "[OK] Sitio secundario '$SecondarySiteName' se detuvo correctamente" -ForegroundColor Green
                } else {
                    $remainingTime = $maxWaitTime - $waitedTime
                    Write-Output "Esperando que el sitio secundario se detenga... (Tiempo restante: ${remainingTime}s)"
                    Start-Sleep -Seconds $waitInterval
                    $waitedTime += $waitInterval
                }
            }
            
            if (-not $secondaryStopped) {
                throw "No se pudo verificar que el sitio $SecondarySiteName se detuviera correctamente después de $maxWaitTime segundos"
            }
            
            # 4. Iniciar el sitio secundario de respaldo
            if (-not [string]::IsNullOrEmpty($SecondarySiteBak)) {
                Write-Output "`n[PASO 4/4] Iniciando el sitio de respaldo secundario '$SecondarySiteBak'..."
                $success = Set-WebsiteState -ServerName $RemoteServer -SiteName $SecondarySiteBak -Action 'Start' -MaxRetries 3 -RetryDelay 10
                
                if ($success) {
                    $secondaryBakState = Get-WebsiteState -ServerName $RemoteServer -SiteName $SecondarySiteBak -MaxRetries 3 -RetryDelay 5
                    if ($secondaryBakState -ne 'Started') {
                        throw "No se pudo verificar que el sitio de respaldo $SecondarySiteBak se iniciara correctamente"
                    }
                    Write-Output "[OK] Sitio de respaldo secundario '$SecondarySiteBak' iniciado correctamente" -ForegroundColor Green
                }
            }
            
            # Resumen de la operación
            Write-Output "`n=== RESUMEN DE LA OPERACIÓN ===" -ForegroundColor Cyan
            Write-Output "[ESTADO FINAL]" -ForegroundColor Cyan
            Write-Output "- ${PrimarySiteName}: DETENIDO"
            if (-not [string]::IsNullOrEmpty($PrimarySiteBak)) {
                Write-Output "- ${PrimarySiteBak}: INICIADO" -ForegroundColor Green
            }
            Write-Output "- ${SecondarySiteName}: DETENIDO"
            if (-not [string]::IsNullOrEmpty($SecondarySiteBak)) {
                Write-Output "- ${SecondarySiteBak}: INICIADO" -ForegroundColor Green
            }
            
            Write-Output "`n[OPERACIÓN COMPLETADA CON ÉXITO]" -ForegroundColor Green
        }
    }
}
catch {
    Write-Error "Error en la ejecución: $_"
    exit 1
}


Write-Output "=== FIN DEL PROCESO ===  Esperando 1 minuto para cierre de procesos y archivos"
Start-Sleep -Seconds 120
Count-s
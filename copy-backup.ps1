
$RutaLocal = "E:\BKSQL"
$RutaRemota = "\\ESTACNS01APP\E$\BKSQL"

$BackupReciente = Get-ChildItem  -Path $RutaLocal -FIlter *.bak | Sort-Object LastWriteTime -Descending | Select-Object -First 3


if($BackupReciente) {

    Copy-Item $BackupReciente.FullName -Destination $RutaRemota

} 


param(
    [string]$Servidor='localhost',
    [ValidatePattern('\AClaudeETLLab(?:_Alumno[0-9]{2,3}_Pruebas)?\z')]
    [string]$BaseDatos='ClaudeETLLab',
    [pscredential]$Credencial,
    [switch]$ConfiarCertificadoLaboratorio,
    [string]$ArchivoServidor,
    [string]$Dtexec
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'scripts/Conexion.ps1')
$conexion=@{
    Servidor=$Servidor
    Credencial=$Credencial
    ConfiarCertificadoLaboratorio=$ConfiarCertificadoLaboratorio
}
$ejecucion=$conexion.Clone()
if ($Dtexec) { $ejecucion.Dtexec=$Dtexec }
function Query([string]$sql) {
    Invoke-LabSqlcmd @conexion -BaseDatos $BaseDatos -Consulta $sql
}

Query "IF EXISTS(SELECT 1 FROM dbo.Ventas) OR EXISTS(SELECT 1 FROM dbo.Ejecuciones) THROW 51100,'Se requiere una base de pruebas preparada y vacia. No se borraran datos.',1;"
$dir='C:\LabSSIS\data'
if ($BaseDatos -ne 'ClaudeETLLab') {
    $dir=Join-Path $dir $BaseDatos
}
if ($ArchivoServidor) {
    $file=$ArchivoServidor
} elseif ($BaseDatos -ne 'ClaudeETLLab') {
    $file=Join-Path $dir 'ventas.csv'
} else {
    if ($Credencial) { throw 'Indica -ArchivoServidor cuando uses SQL remoto con la base individual.' }
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    $file=Join-Path $dir ('ventas-ci-'+[guid]::NewGuid().ToString('N')+'.csv')
    Copy-Item -LiteralPath (Join-Path $root 'data/ventas.csv') -Destination $file
}
Invoke-LabSqlcmd @conexion -BaseDatos $BaseDatos -ArchivoSql (Join-Path $root 'sql/02_Procedimiento.sql')
& (Join-Path $root 'scripts/Ejecutar.ps1') @ejecucion -BaseDatos $BaseDatos -ArchivoServidor $file
Query @"
IF (SELECT COUNT(*) FROM dbo.Ventas)<>5 OR (SELECT SUM(Importe) FROM dbo.Ventas)<>149.99
 THROW 51101,'Regresion del resultado de negocio.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Ejecuciones WHERE Estado='CORRECTA' AND Leidas=12
 AND Aceptadas=5 AND Rechazadas=7 AND Insertadas=5 AND Actualizadas=0)
 THROW 51102,'Balance incorrecto en la primera carga.',1;
IF (SELECT COUNT(*) FROM dbo.Rechazos WHERE Motivo=N'VentaId duplicado en el archivo')<>2
 THROW 51103,'La politica de duplicados no se cumple.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Ventas WHERE VentaId=1001
 AND Cliente COLLATE Latin1_General_100_BIN2=N'ANA')
 THROW 51104,'No se ha aplicado la normalizacion a mayusculas del paso 8.',1;
"@
& (Join-Path $root 'scripts/Ejecutar.ps1') @ejecucion -BaseDatos $BaseDatos -ArchivoServidor $file
Query @"
IF (SELECT COUNT(*) FROM dbo.Ejecuciones WHERE Estado='CORRECTA')<>2
 THROW 51105,'Falta la segunda ejecucion.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Ejecuciones WHERE Estado='CORRECTA'
 AND Insertadas=0 AND Actualizadas=0 AND Aceptadas=5 AND Rechazadas=7)
 THROW 51106,'La repeticion no es idempotente.',1;
IF (SELECT COUNT(*) FROM dbo.Ventas)<>5 OR (SELECT SUM(Importe) FROM dbo.Ventas)<>149.99
 THROW 51107,'La repeticion ha cambiado el destino.',1;
"@
$failed=$false
try { & (Join-Path $root 'scripts/Ejecutar.ps1') @ejecucion -BaseDatos $BaseDatos -ArchivoServidor ($file+'.inexistente.csv') }
catch { $failed=$true; Write-Output 'Fallo tecnico provocado y capturado.' }
if(-not $failed) {throw 'El archivo inexistente deberia producir un error.'}
Query @"
IF (SELECT COUNT(*) FROM dbo.Ejecuciones WHERE Estado='ERROR')<>1
 THROW 51108,'El fallo tecnico no se ha registrado.',1;
IF (SELECT COUNT(*) FROM dbo.Ventas)<>5 OR (SELECT SUM(Importe) FROM dbo.Ventas)<>149.99
 THROW 51109,'El fallo ha alterado el destino.',1;
"@
Query @"
BEGIN TRY
 EXEC dbo.usp_CargarVentas @Archivo=N'C:\Windows\win.ini';
 THROW 51110,'No se ha rechazado la ruta externa.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51003 THROW;
END CATCH;
BEGIN TRY
 EXEC dbo.usp_CargarVentas @Archivo=N'$dir\..\otro.csv';
 THROW 51111,'No se ha rechazado el recorrido de directorio.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51003 THROW;
END CATCH;
IF DB_NAME()<>N'ClaudeETLLab'
BEGIN TRY
 EXEC dbo.usp_CargarVentas @Archivo=N'C:\LabSSIS\data\ventas.csv';
 THROW 51112,'No se ha rechazado un CSV fuera de la carpeta asignada.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51003 THROW;
END CATCH;
"@
Write-Output 'Integracion real terminada: carga, normalizacion, rechazos, idempotencia, fallo tecnico y limites de rutas.'
# Descartar la VM completa al terminar; no se borran tablas desde esta prueba.

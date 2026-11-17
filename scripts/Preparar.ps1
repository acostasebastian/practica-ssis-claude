param(
    [Parameter(Mandatory=$true)][string]$Servidor,
    [ValidatePattern('\AClaudeETLLab(?:_Alumno[0-9]{2,3}(?:_Pruebas)?)?\z')][string]$BaseDatos='ClaudeETLLab',
    [pscredential]$Credencial,
    [switch]$ConfiarCertificadoLaboratorio
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Conexion.ps1')
$root=Split-Path $PSScriptRoot -Parent
$conexion=@{
    Servidor=$Servidor
    Credencial=$Credencial
    ConfiarCertificadoLaboratorio=$ConfiarCertificadoLaboratorio
}

foreach ($archivo in '01_Preparar.sql','02_Procedimiento.sql') {
    $ruta = Join-Path $root "sql\$archivo"
    if (-not (Test-Path -LiteralPath $ruta -PathType Leaf)) {
        throw "Falta $ruta. Extrae el ZIP completo con las carpetas scripts y sql juntas."
    }
}
Invoke-LabSqlcmd @conexion -BaseDatos master -Consulta "IF DB_ID(N'$BaseDatos') IS NULL CREATE DATABASE [$BaseDatos];"
foreach ($archivo in '01_Preparar.sql','02_Procedimiento.sql') {
    Invoke-LabSqlcmd @conexion -BaseDatos $BaseDatos -ArchivoSql (Join-Path $root "sql\$archivo")
}
Write-Output "$BaseDatos preparada. No se ha ejecutado la carga."

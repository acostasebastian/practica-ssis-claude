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
Invoke-LabSqlcmd @conexion -BaseDatos $BaseDatos -ArchivoSql (Join-Path $root 'sql\03_Consultar.sql')

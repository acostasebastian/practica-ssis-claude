param(
    [Parameter(Mandatory=$true)][string]$Servidor,
    [Parameter(Mandatory=$true)][string]$ArchivoServidor,
    [ValidatePattern('\AClaudeETLLab(?:_Alumno[0-9]{2,3}(?:_Pruebas)?)?\z')][string]$BaseDatos='ClaudeETLLab',
    [pscredential]$Credencial,
    [string]$Dtexec='C:\Program Files\Microsoft SQL Server\160\DTS\Binn\DTExec.exe',
    [switch]$SoloValidar,
    [switch]$ConfiarCertificadoLaboratorio
)
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $Dtexec -PathType Leaf)) {
    throw 'No se encuentra DTExec de SSIS 2022 en este equipo. Instala el runtime o indica su ruta con -Dtexec.'
}
if ($ArchivoServidor -notmatch '^(?:[A-Za-z]:\\|\\\\)' -or
    $ArchivoServidor -match '[\r\n]' -or $ArchivoServidor.Length -gt 3500) {
    throw 'Indica la ruta absoluta del CSV en el servidor SQL.'
}

$root = Split-Path $PSScriptRoot -Parent
[xml]$pkg = Get-Content -LiteralPath (Join-Path $root 'ssis\CargarVentas.dtsx') -Raw
$ns = New-Object System.Xml.XmlNamespaceManager($pkg.NameTable)
$dtsNs = 'www.microsoft.com/SqlServer/Dts'
$sqlNs = 'www.microsoft.com/sqlserver/dts/tasks/sqltask'
$ns.AddNamespace('DTS',$dtsNs)
$ns.AddNamespace('SQL',$sqlNs)
$builder = New-Object System.Data.OleDb.OleDbConnectionStringBuilder
$builder['Provider'] = 'MSOLEDBSQL'
$builder['Data Source'] = $Servidor
$builder['Initial Catalog'] = $BaseDatos
if ($Credencial) {
    $builder['User ID'] = $Credencial.UserName
    $builder['Password'] = $Credencial.GetNetworkCredential().Password
} else {
    $builder['Integrated Security'] = 'SSPI'
}
$builder['Use Encryption for Data'] = $true
$builder['Trust Server Certificate'] = [bool]$ConfiarCertificadoLaboratorio

$pkg.SelectSingleNode('//DTS:Variable[@DTS:ObjectName="ConnectionString"]/DTS:VariableValue',$ns).InnerText = $builder.ConnectionString
$pkg.SelectSingleNode('//DTS:Variable[@DTS:ObjectName="Archivo"]/DTS:VariableValue',$ns).InnerText = $ArchivoServidor
$manager = $pkg.SelectSingleNode('//DTS:ConnectionManager/DTS:ObjectData/DTS:ConnectionManager',$ns)
$null = $manager.SetAttribute('ConnectionString',$dtsNs,$builder.ConnectionString)
$tarea = $pkg.SelectSingleNode('//DTS:Executable[@DTS:ObjectName="ComprobarEntorno"]/DTS:ObjectData/SQL:SqlTaskData',$ns)
$consulta = $tarea.GetAttribute('SqlStatementSource',$sqlNs)
if (-not $consulta.Contains("N'ClaudeETLLab'")) {
    throw 'Falta la comprobacion de base de datos en ComprobarEntorno.'
}
$null = $tarea.SetAttribute('SqlStatementSource',$sqlNs,$consulta.Replace("N'ClaudeETLLab'","N'$BaseDatos'"))

# La copia temporal queda fuera del repositorio y solo existe durante DTExec.
$run = Join-Path ([IO.Path]::GetTempPath()) ('CargarVentas-'+[guid]::NewGuid().ToString('N')+'.dtsx')
try {
    $pkg.Save($run)
    & $Dtexec /FILE $run /VALIDATE /REPORTING E
    if ($LASTEXITCODE -ne 0) {
        throw "Validacion SSIS fallida. Codigo $LASTEXITCODE. Revisa runtime, proveedor y conexion."
    }
    if ($SoloValidar) {
        Write-Output 'Validacion finalizada. No se ha ejecutado el ETL.'
        return
    }
    & $Dtexec /FILE $run /REPORTING E
    if ($LASTEXITCODE -ne 0) {
        throw "Ejecucion SSIS fallida. Codigo $LASTEXITCODE. Consulta dbo.Ejecuciones."
    }
    Write-Output "Paquete finalizado en $BaseDatos. Consulta con scripts\Consultar.ps1."
} finally {
    if (Test-Path -LiteralPath $run) { Remove-Item -LiteralPath $run -Force }
}

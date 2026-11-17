$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
function Require($ok,[string]$message) { if(-not $ok) {throw $message} }
foreach($path in 'scripts/Conexion.ps1','scripts/Preparar-Aula.ps1','scripts/Consultar.ps1','ssis/CargarVentas.dtsx','sql/01_Preparar.sql','sql/02_Procedimiento.sql','sql/03_Consultar.sql','data/ventas.csv') {
 Require (Test-Path -LiteralPath (Join-Path $root $path) -PathType Leaf) "Falta $path"
}
Get-ChildItem $root -Recurse -Force -File -Filter '*.ps1' | ForEach-Object {
 $tokens=$null;$errors=$null
 $null=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
 Require ($errors.Count -eq 0) "Sintaxis PowerShell incorrecta en $($_.Name): $errors"
}
$settings=[System.Xml.XmlReaderSettings]::new()
$settings.DtdProcessing=[System.Xml.DtdProcessing]::Prohibit
$settings.XmlResolver=$null
$reader=[System.Xml.XmlReader]::Create((Join-Path $root 'ssis/CargarVentas.dtsx'),$settings)
try { $pkg=[System.Xml.XmlDocument]::new();$pkg.Load($reader) } finally { $reader.Dispose() }
$ns=[System.Xml.XmlNamespaceManager]::new($pkg.NameTable)
$ns.AddNamespace('D','www.microsoft.com/SqlServer/Dts')
$ns.AddNamespace('S','www.microsoft.com/sqlserver/dts/tasks/sqltask')
$uri=$ns.LookupNamespace('D')
$tasks=@($pkg.SelectNodes('/D:Executable/D:Executables/D:Executable',$ns))
Require ($tasks.Count -eq 3) 'El paquete debe conservar sus tres tareas.'
$ids=@($tasks | ForEach-Object {$_.GetAttribute('refId',$uri)})
Require (($ids | Sort-Object -Unique).Count -eq 3) 'Tareas con referencias duplicadas.'
$edges=@($pkg.SelectNodes('//D:PrecedenceConstraint',$ns))
Require ($edges.Count -eq 2) 'Deben existir dos precedencias.'
foreach($edge in $edges) {
 Require ($edge.GetAttribute('From',$uri) -in $ids) 'Precedencia con origen inexistente.'
 Require ($edge.GetAttribute('To',$uri) -in $ids) 'Precedencia con destino inexistente.'
 Require ($edge.GetAttribute('Value',$uri) -in @('','0')) 'La precedencia debe requerir exito.'
}
$pairs=@($edges | ForEach-Object {$_.GetAttribute('From',$uri)+'>'+ $_.GetAttribute('To',$uri)})
Require ('Package\ComprobarEntorno>Package\CargarVentas' -in $pairs) 'Falta la precedencia de inicio.'
Require ('Package\CargarVentas>Package\ComprobarBalance' -in $pairs) 'Falta la precedencia de balance.'
$param=@($pkg.SelectNodes('//S:ParameterBinding',$ns))
Require ($param.Count -eq 1) 'Debe existir un parametro SQL.'
Require ($param[0].GetAttribute('DtsVariableName',$ns.LookupNamespace('S')) -eq 'User::Archivo') 'Vinculo de archivo incorrecto.'
$connection=$pkg.SelectSingleNode('//D:ConnectionManager/D:ObjectData/D:ConnectionManager',$ns).GetAttribute('ConnectionString',$uri)
Require ($connection -match 'Use Encryption for Data=True') 'La conexion debe cifrar los datos.'
Require ($connection -match 'Trust Server Certificate=False') 'La conexion debe validar el certificado.'
$guard=$pkg.SelectSingleNode('//D:Executable[@D:ObjectName="ComprobarEntorno"]/D:ObjectData/S:SqlTaskData',$ns)
Require ($guard.GetAttribute('SqlStatementSource',$ns.LookupNamespace('S')).Contains("N'ClaudeETLLab'")) 'Falta el nombre base para configurar la comprobacion de destino.'
foreach ($script in '01_Preparar.sql','02_Procedimiento.sql','03_Consultar.sql') {
 $sql=Get-Content (Join-Path $root "sql/$script") -Raw
 Require ($sql -notmatch '(?im)^\s*USE\s+') 'Selecciona la base por la conexion, no con USE fijo.'
}
$lines=Get-Content (Join-Path $root 'data/ventas.csv') -Encoding utf8
Require ($lines[0] -ceq 'VentaId;Fecha;Cliente;Cantidad;Precio') 'Cabecera incorrecta.'
Require ((Import-Csv (Join-Path $root 'data/ventas.csv') -Delimiter ';').Count -eq 12) 'La muestra de regresion debe conservar 12 registros.'
foreach($workflow in Get-ChildItem (Join-Path $root '.github/workflows') -File -Filter '*.yml') {
 $text=Get-Content $workflow.FullName -Raw
 Require ($text -notmatch '(?m)^\s*pull_request_target\s*:') 'No se permite pull_request_target en esta practica.'
 foreach($action in [regex]::Matches($text,'(?m)^\s*uses:\s+([^\s#]+)')) {
  Require ($action.Groups[1].Value -match '@[0-9a-f]{40}$') 'Fija cada action externa a un SHA completo verificado.'
 }
 Require ($text -match 'persist-credentials:\s*false') 'El checkout no debe persistir credenciales.'
}
# Este control valida estructura y sintaxis PowerShell. No ejecuta SSIS,
# no compila T-SQL y no sustituye un analizador YAML ni un escaner de secretos.
Write-Output 'Comprobaciones estaticas correctas. SQL y SSIS no se han ejecutado.'

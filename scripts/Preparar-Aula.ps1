param(
    [Parameter(Mandatory=$true)][ValidateRange(1,999)][int]$Cantidad
)

$ErrorActionPreference='Stop'
$Directorio='C:\LabSSIS\data'
$root = Split-Path $PSScriptRoot -Parent
$muestra = Join-Path $root 'data\ventas.csv'
$cabecera = 'VentaId;Fecha;Cliente;Cantidad;Precio'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$volumen = @($cabecera) + @(1..10000 | ForEach-Object {
    "$($_ + 20000);2026-11-01;Cliente $_;1;10.00"
})
function Guardar-Fixture([string]$Ruta, [string[]]$Lineas) {
    if (-not (Test-Path -LiteralPath $Ruta)) {
        [IO.File]::WriteAllLines($Ruta, $Lineas, $utf8)
    }
}

foreach ($numero in 1..$Cantidad) {
    $base = 'ClaudeETLLab_Alumno{0:00}' -f $numero
    $pruebas = "$($base)_Pruebas"
    foreach ($nombre in $base,$pruebas) {
        $dir = Join-Path $Directorio $nombre
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        $destino = Join-Path $dir 'ventas.csv'
        if (-not (Test-Path -LiteralPath $destino)) { Copy-Item -LiteralPath $muestra -Destination $destino }
    }

    $dir = Join-Path $Directorio $pruebas
    Guardar-Fixture (Join-Path $dir 'ventas-vacio.csv') @()
    Guardar-Fixture (Join-Path $dir 'ventas-cabecera-incorrecta.csv') @('Cabecera incorrecta')
    Guardar-Fixture (Join-Path $dir 'ventas-precio-invalido.csv') @($cabecera, '9010;2026-11-01;Prueba;1;10.123')
    Guardar-Fixture (Join-Path $dir 'ventas-precio-cambiado.csv') @($cabecera, '1001;2026-11-01;Ana;2;11.00')
    Guardar-Fixture (Join-Path $dir 'ventas-volumen.csv') $volumen
    [pscustomobject]@{ Alumno=$numero; BaseDatos=$base; BasePruebas=$pruebas }
}

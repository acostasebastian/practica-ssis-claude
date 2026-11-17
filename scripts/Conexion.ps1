function Invoke-LabSqlcmd {
    param(
        [string]$Servidor,
        [string]$BaseDatos,
        [pscredential]$Credencial,
        [switch]$ConfiarCertificadoLaboratorio,
        [string]$Consulta,
        [string]$ArchivoSql
    )
    if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
        throw 'Instala sqlcmd en este equipo.'
    }
    $opciones = @('-S', $Servidor, '-d', $BaseDatos, '-N', '-b')
    if ($ConfiarCertificadoLaboratorio) { $opciones += '-C' }
    if ($ArchivoSql) { $opciones += @('-i', $ArchivoSql) }
    else { $opciones += @('-Q', $Consulta) }
    if ($Credencial) { $opciones += @('-U', $Credencial.UserName) }
    else { $opciones += '-E' }

    $claveAnterior = $env:SQLCMDPASSWORD
    try {
        if ($Credencial) { $env:SQLCMDPASSWORD = $Credencial.GetNetworkCredential().Password }
        & sqlcmd @opciones
        if ($LASTEXITCODE -ne 0) {
            throw "sqlcmd fallo en $Servidor / $BaseDatos. Codigo $LASTEXITCODE. Revisa el mensaje anterior."
        }
    } finally {
        $env:SQLCMDPASSWORD = $claveAnterior
    }
}

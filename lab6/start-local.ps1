param(
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin',
    [int]$Port = 55436,
    [switch]$Stop
)
$ErrorActionPreference = 'Stop'
$localDir = Join-Path $PSScriptRoot '.lab6-local'
$dataDir = Join-Path $localDir 'data'
$settingsFile = Join-Path $localDir 'connection.json'
$ctl = Join-Path $PgBin 'pg_ctl.exe'
$psql = Join-Path $PgBin 'psql.exe'
if (!(Test-Path -LiteralPath $ctl)) { throw "PostgreSQL not found in $PgBin" }
if ($Stop) {
    if (!(Test-Path -LiteralPath (Join-Path $dataDir 'PG_VERSION'))) { throw 'Local database is not initialized.' }
    & $ctl -D $dataDir -m fast -w stop
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop local PostgreSQL.' }
    return
}
New-Item -ItemType Directory -Path $localDir -Force | Out-Null
if (!(Test-Path -LiteralPath $settingsFile)) {
    if (Test-Path -LiteralPath $dataDir) { throw 'Data directory already exists without connection.json. Inspect it before continuing.' }
    $settings = @{
        adminPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        appPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        port = $Port
    }
    $settings | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
} else {
    $settings = Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json
    $Port = $settings.port
}
if (!(Test-Path -LiteralPath (Join-Path $dataDir 'PG_VERSION'))) {
    $pwFile = Join-Path $localDir 'init-password.tmp'
    [IO.File]::WriteAllText($pwFile, $settings.adminPassword)
    try {
        & (Join-Path $PgBin 'initdb.exe') -D $dataDir -U postgres --encoding=UTF8 --locale=C --auth-local=scram-sha-256 --auth-host=scram-sha-256 "--pwfile=$pwFile"
        if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL initialization failed.' }
    } finally { Remove-Item -LiteralPath $pwFile -Force -ErrorAction SilentlyContinue }
}
& $ctl -D $dataDir status *> $null
if ($LASTEXITCODE -ne 0) {
    & $ctl -D $dataDir -l (Join-Path $localDir 'server.log') -o "-h 127.0.0.1 -p $Port" -w start
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL failed to start. Check .lab6-local/server.log and the port.' }
}
$oldPassword = $env:PGPASSWORD
$oldCatalogPassword = $env:CATALOG_DB_PASSWORD
try {
    $env:PGPASSWORD = $settings.adminPassword
    $env:CATALOG_DB_PASSWORD = $settings.appPassword
    $dbExists = & $psql -X -h 127.0.0.1 -p $Port -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='catalog_lab6'"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot connect to the local PostgreSQL cluster.' }
    if ($dbExists -ne '1') {
        & $psql -X -h 127.0.0.1 -p $Port -U postgres -d postgres -f (Join-Path $PSScriptRoot 'bootstrap.sql')
        if ($LASTEXITCODE -ne 0) { throw 'Role/database creation failed.' }
    }
    $env:PGPASSWORD = $settings.appPassword
    $tableExists = & $psql -X -h 127.0.0.1 -p $Port -U catalog_app -d catalog_lab6 -tAc "SELECT to_regclass('public.courses') IS NOT NULL"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot connect as catalog_app.' }
    if ($tableExists -eq 'f') {
        & (Join-Path $PSScriptRoot 'run-lab6.ps1') -Port $Port -PgBin $PgBin
    } else {
        & $psql -X -h 127.0.0.1 -p $Port -U catalog_app -d catalog_lab6 -c 'SELECT id, title, likes FROM courses ORDER BY id;'
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read the existing schema.' }
        Write-Host 'Existing lab database preserved. See results/ for the recorded verification.'
    }
    Write-Host "Database: 127.0.0.1:$Port/catalog_lab6; role: catalog_app" -ForegroundColor Green
    Write-Host 'Local credentials: .lab6-local/connection.json (keep private; excluded from Git).'
    Write-Host 'Stop server: powershell -ExecutionPolicy Bypass -File .\lab6\start-local.ps1 -Stop'
} finally {
    $env:PGPASSWORD = $oldPassword
    $env:CATALOG_DB_PASSWORD = $oldCatalogPassword
}

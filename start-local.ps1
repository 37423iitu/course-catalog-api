param(
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin',
    [int]$Port = 55437,
    [switch]$Stop
)
$ErrorActionPreference = 'Stop'
$localPath = Join-Path $PSScriptRoot '.lab7-local'
$dataPath = Join-Path $localPath 'data'
$settingsPath = Join-Path $localPath 'connection.json'
$ctl = Join-Path $PgBin 'pg_ctl.exe'
$psql = Join-Path $PgBin 'psql.exe'
if (!(Test-Path -LiteralPath $ctl)) { throw "PostgreSQL not found: $PgBin" }
if ($Stop) {
    & $ctl -D $dataPath -m fast -w stop
    if ($LASTEXITCODE -ne 0) { throw 'Cannot stop local PostgreSQL.' }
    return
}
New-Item -ItemType Directory -Path $localPath -Force | Out-Null
if (!(Test-Path -LiteralPath $settingsPath)) {
    if (Test-Path -LiteralPath $dataPath) { throw 'Inspect the existing data directory before initializing.' }
    @{ adminPassword = [guid]::NewGuid().ToString('N'); port = $Port } |
        ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding utf8
}
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$Port = $settings.port
if (!(Test-Path -LiteralPath (Join-Path $dataPath 'PG_VERSION'))) {
    $passwordPath = Join-Path $localPath 'init-password.tmp'
    [IO.File]::WriteAllText($passwordPath, $settings.adminPassword)
    try {
        & (Join-Path $PgBin 'initdb.exe') -D $dataPath -U postgres --encoding=UTF8 --locale=C --auth=scram-sha-256 "--pwfile=$passwordPath"
        if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL initialization failed.' }
    } finally { Remove-Item -LiteralPath $passwordPath -Force -ErrorAction SilentlyContinue }
}
& $ctl -D $dataPath status *> $null
if ($LASTEXITCODE -ne 0) {
    & $ctl -D $dataPath -l (Join-Path $localPath 'server.log') -o "-h 127.0.0.1 -p $Port" -w start
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL did not start; inspect .lab7-local/server.log.' }
}
$previousPassword = $env:PGPASSWORD
try {
    $env:PGPASSWORD = $settings.adminPassword
    $exists = & $psql -X -h 127.0.0.1 -p $Port -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='catalog_app'"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot connect to the local cluster.' }
    if ($exists -ne '1') {
        & $psql -X -h 127.0.0.1 -p $Port -U postgres -d postgres -v ON_ERROR_STOP=1 -c "CREATE ROLE catalog_app LOGIN PASSWORD 'change-me';"
        if ($LASTEXITCODE -ne 0) { throw 'Cannot create catalog_app.' }
    }
    $exists = & $psql -X -h 127.0.0.1 -p $Port -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='course_catalog'"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect databases.' }
    if ($exists -ne '1') {
        & $psql -X -h 127.0.0.1 -p $Port -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE course_catalog OWNER catalog_app;'
        if ($LASTEXITCODE -ne 0) { throw 'Cannot create course_catalog.' }
    }
} finally { $env:PGPASSWORD = $previousPassword }
$envPath = Join-Path $PSScriptRoot '.env'
if (!(Test-Path -LiteralPath $envPath)) {
    "DATABASE_URL=postgresql+psycopg://catalog_app:change-me@127.0.0.1:$Port/course_catalog" |
        Set-Content -LiteralPath $envPath -Encoding ascii
}
Write-Host "Local PostgreSQL ready: 127.0.0.1:$Port/course_catalog"
Write-Host 'Existing data preserved. Next: python -m alembic upgrade head'

param(
    [string]$PgHost = '127.0.0.1',
    [int]$Port = 5432,
    [string]$PgUser = 'catalog_app',
    [string]$Database = 'catalog_lab6',
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin'
)
$ErrorActionPreference = 'Stop'
$psql = Join-Path $PgBin 'psql.exe'
if (!(Test-Path -LiteralPath $psql)) { throw "PostgreSQL not found: $psql" }
& $psql -X -h $PgHost -p $Port -U $PgUser -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $PSScriptRoot 'run.sql')
if ($LASTEXITCODE -ne 0) { throw 'Lab verification failed. See PostgreSQL output above.' }
Write-Host 'Lab 6 completed successfully.' -ForegroundColor Green

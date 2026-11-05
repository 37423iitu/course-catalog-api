param([int]$ApiPort = 8000, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (!(Test-Path -LiteralPath '.venv\Scripts\python.exe')) {
        python -m venv .venv
        if ($LASTEXITCODE -ne 0) { throw 'Python 3.11 or newer is required.' }
    }
    $pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    & $pythonPath -c 'import fastapi, sqlalchemy, psycopg, alembic, pydantic_settings, email_validator; assert tuple(map(int, sqlalchemy.__version__.split(".")[:2])) >= (2,1)' 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $pythonPath -m pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
    }
    & (Join-Path $PSScriptRoot 'start-local.ps1')
    & $pythonPath -m alembic upgrade head
    if ($LASTEXITCODE -ne 0) { throw 'Migration failed.' }
    $seedCode = @'
from pathlib import Path
from sqlalchemy import text
from db import engine
with engine.begin() as c:
    if c.scalar(text('SELECT count(*) FROM courses')) == 0:
        body = '\n'.join(line for line in Path('seed.sql').read_text(encoding='utf-8').splitlines() if not line.startswith('\\'))
        c.exec_driver_sql(body)
        print('Initial data loaded: 6 courses, 3 students, 6 enrollments')
    else:
        print('Existing catalog data preserved')
'@
    & $pythonPath -c $seedCode
    if ($LASTEXITCODE -ne 0) { throw 'Initial data check failed.' }
    & $pythonPath check_models.py
    if ($LASTEXITCODE -ne 0) { throw 'Model check failed.' }
    & $pythonPath -m alembic check
    if ($LASTEXITCODE -ne 0) { throw 'Schema check failed.' }
    if (!$CheckOnly) {
        Write-Host "Swagger: http://127.0.0.1:$ApiPort/docs" -ForegroundColor Green
        & $pythonPath -m uvicorn main:app --host 127.0.0.1 --port $ApiPort
    }
} finally { Pop-Location }

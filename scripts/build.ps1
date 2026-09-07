$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskGodot = Join-Path $taskRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $taskGodot)) { throw 'Godot portátil não encontrado em tools/godot.' }
Push-Location -LiteralPath $taskRoot
try {
    & $taskGodot --headless --path $taskRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Falha na importação.' }
    & $taskGodot --headless --path $taskRoot --script tests/rules.gd
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de regras.' }
    New-Item -ItemType Directory -Force -Path (Join-Path $taskRoot 'builds') | Out-Null
    & $taskGodot --headless --path $taskRoot --export-release 'Windows Desktop' 'builds/FallingSkies.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Falha na exportação.' }
    Write-Output 'Executável gerado: builds/FallingSkies.exe'
} finally { Pop-Location }

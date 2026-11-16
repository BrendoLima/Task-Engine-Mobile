# Roda o Metro (bundler) em uma janela propria, gravando o log em dist\metro.log.
# Chamado por scripts\dev.ps1; tambem pode ser usado direto:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\metro.ps1
$Root = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $Root "dist"
$Log = Join-Path $LogDir "metro.log"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Host "Metro - Task Engine (log: $Log)"
Write-Host ""

& node (Join-Path $Root "node_modules\react-native\cli.js") start *>&1 |
  Tee-Object -FilePath $Log

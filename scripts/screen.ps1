# Troca a resolucao/densidade do emulador em execucao, mantendo 411x891 dp (19,5:9).
#
#   npm run screen                          -> lista as opcoes e mostra a atual
#   npm run screen -- -Size 1080x2340 -Density 420   -> resolucao real do A15 (pesado)
#   npm run screen -- -Reset                -> volta para o config.ini do AVD
#
# Densidade para manter 411x891 dp: densidade = largura * 160 / 411
param(
  [string]$Size,
  [int]$Density = 0,
  [switch]$Reset
)

$ErrorActionPreference = "Continue"

function Get-Adb {
  $sdk = $env:ANDROID_HOME
  if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
  if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
  return Join-Path $sdk "platform-tools\adb.exe"
}

$Adb = Get-Adb
if (-not (Test-Path $Adb)) { throw "adb nao encontrado em $Adb" }
if (-not ((& $Adb devices 2>$null | Out-String) -match "device$")) { throw "Nenhum emulador/aparelho conectado." }

if (-not $Size -and -not $Reset) {
  Write-Host "Tela atual:" -ForegroundColor Cyan
  & $Adb shell wm size
  & $Adb shell wm density
  Write-Host ""
  Write-Host "Opcoes medidas nesta maquina (411x891 dp, 19,5:9):" -ForegroundColor Cyan
  Write-Host "  432x936  @168   0,40 MP   p50 16 ms  p90 24-25 ms   jank 3,8-16,9%   (mais fluido)"
  Write-Host "  576x1248 @240   0,72 MP   p50 18 ms  p90 27-28 ms   jank 4,7-13,2%"
  Write-Host "  648x1404 @252   0,91 MP   p50 21-22 ms  p90 29-31 ms  jank 6,2-23,9%  (padrao do AVD)"
  Write-Host "  720x1560 @280   1,12 MP   p50 24 ms  p90 32-34 ms   jank 8,4-29,1%"
  Write-Host "  864x1872 @336   1,62 MP   p50 30 ms  p90 40 ms      jank 17,0-41,7%"
  Write-Host "  1080x2340 @420  2,53 MP   p50 38-40 ms  p90 53 ms   jank 37,9-54,0%  (resolucao real do A15, lento)"
  Write-Host ""
  Write-Host "Ex.: npm run screen -- -Size 1080x2340 -Density 420"
  exit 0
}

if ($Reset) {
  & $Adb shell wm size reset | Out-Null
  & $Adb shell wm density reset | Out-Null
  Write-Host "Tela restaurada para a configuracao do AVD:" -ForegroundColor Green
  & $Adb shell wm size
  & $Adb shell wm density
  exit 0
}

if ($Size -notmatch "^(\d+)x(\d+)$") { throw "Use -Size LARGURAxALTURA, ex.: -Size 1080x2340" }
$w = [int]$Matches[1]
$h = [int]$Matches[2]
if ($Density -le 0) { $Density = [int][math]::Round($w * 160.0 / 411.0) }

& $Adb shell "wm size ${w}x${h}" | Out-Null
& $Adb shell "wm density $Density" | Out-Null

$dpW = [math]::Round($w * 160.0 / $Density, 1)
$dpH = [math]::Round($h * 160.0 / $Density, 1)
Write-Host ("Aplicado: {0}x{1} @{2} dpi = {3}x{4} dp" -f $w, $h, $Density, $dpW, $dpH) -ForegroundColor Green
Write-Host "Dica: 'npm run screen -- -Reset' para voltar ao padrao do AVD."

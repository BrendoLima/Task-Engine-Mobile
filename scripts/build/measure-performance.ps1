# Mede a fluidez do app release no dispositivo conectado: boot + install + launch + carga de UI,
# e imprime as estatisticas de frames (jank e percentis) do dumpsys gfxinfo.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\measure-performance.ps1
#   ... -SkipInstall -Apk dist\task-engine-arm64.apk
param(
  [string]$Package = "com.taskengine.mobile",
  [string]$Apk,
  [string]$OutDir,
  [switch]$SkipInstall
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $Apk) { $Apk = Join-Path $Root "dist\task-engine-arm64.apk" }
if (-not $OutDir) { $OutDir = Join-Path $Root "dist" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Remove-Item "$OutDir\screenshot.png" -Force -ErrorAction SilentlyContinue

# --- boot ---
$t0 = Get-Date
$boot = ""
for ($i = 0; $i -lt 150; $i++) {
  $boot = (adb shell getprop sys.boot_completed 2>$null | Out-String).Trim()
  if ($boot -eq "1") { break }
  Start-Sleep -Seconds 2
}
if ($boot -ne "1") { Write-Output "FALHA: boot nao concluiu"; exit 1 }
Write-Output ("boot_s={0}" -f [math]::Round(((Get-Date) - $t0).TotalSeconds, 1))

adb shell settings put global window_animation_scale 0 | Out-Null
adb shell settings put global transition_animation_scale 0 | Out-Null
adb shell settings put global animator_duration_scale 0 | Out-Null

if (-not $SkipInstall) {
  $t = Get-Date
  $install = adb install -r $Apk 2>&1 | Out-String
  Write-Output ("install_s={0} success={1}" -f [math]::Round(((Get-Date) - $t).TotalSeconds, 1), ($install -match "Success"))
  adb shell cmd package compile -m speed -f $Package | Out-Null
}

# --- tamanho da tela ---
$sizeLine = (adb shell wm size 2>$null | Select-Object -Last 1) -as [string]
$sizeLine = $sizeLine.Trim()
if ($sizeLine -match "(\d+)x(\d+)") { $W = [int]$Matches[1]; $H = [int]$Matches[2] } else { $W = 432; $H = 936 }
Write-Output "tela=${W}x${H}"

# --- abre o app ---
adb shell am force-stop $Package | Out-Null
$t = Get-Date
adb shell am start -n "$Package/.MainActivity" | Out-Null
$focus = ""
for ($i = 0; $i -lt 80; $i++) {
  $focus = (adb shell dumpsys window 2>$null | Select-String "mCurrentFocus" | Select-Object -First 1 | Out-String)
  if ($focus -match [regex]::Escape($Package)) { break }
  Start-Sleep -Milliseconds 500
}
Write-Output ("launch_s={0} focado={1}" -f [math]::Round(((Get-Date) - $t).TotalSeconds, 1), ($focus -match [regex]::Escape($Package)))
Start-Sleep -Seconds 4

# --- descobre as abas de filtro no dump de UI ---
function Get-TabCenter([string]$label) {
  adb shell uiautomator dump /sdcard/u.xml 2>&1 | Out-Null
  adb pull /sdcard/u.xml "$env:TEMP\te-u.xml" 2>&1 | Out-Null
  $x = Get-Content "$env:TEMP\te-u.xml" -Raw -ErrorAction SilentlyContinue
  if (-not $x) { return $null }
  $m = [regex]::Match($x, 'text="' + [regex]::Escape($label) + '"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
  if (-not $m.Success) { return $null }
  return @{
    x = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
    y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
  }
}
$tabTodas = Get-TabCenter "Todas"
$tabAtivas = Get-TabCenter "Ativas"
$tabFeitas = Get-TabCenter "Feitas"
if (-not $tabTodas) { $tabTodas = @{ x = [int]($W * 0.2); y = [int]($H * 0.45) } }
if (-not $tabAtivas) { $tabAtivas = @{ x = [int]($W * 0.5); y = $tabTodas.y } }
if (-not $tabFeitas) { $tabFeitas = @{ x = [int]($W * 0.8); y = $tabTodas.y } }
Write-Output ("abas: Todas=({0},{1}) Ativas=({2},{3}) Feitas=({4},{5})" -f $tabTodas.x, $tabTodas.y, $tabAtivas.x, $tabAtivas.y, $tabFeitas.x, $tabFeitas.y)

$cx = [int]($W / 2)
$y1 = [int]($H * 0.75)
$y2 = [int]($H * 0.32)

# --- carga de UI: rolagem + troca de filtros ---
adb shell dumpsys gfxinfo $Package reset | Out-Null
for ($i = 0; $i -lt 6; $i++) {
  adb shell input tap $tabTodas.x $tabTodas.y | Out-Null
  adb shell input swipe $cx $y1 $cx $y2 150 | Out-Null
  adb shell input swipe $cx $y2 $cx $y1 150 | Out-Null
  adb shell input tap $tabAtivas.x $tabAtivas.y | Out-Null
  adb shell input swipe $cx $y1 $cx $y2 150 | Out-Null
  adb shell input swipe $cx $y2 $cx $y1 150 | Out-Null
  adb shell input tap $tabFeitas.x $tabFeitas.y | Out-Null
}
Start-Sleep -Seconds 2

$gfx = adb shell dumpsys gfxinfo $Package 2>$null | Out-String
($gfx -split "`n" | Select-String -Pattern "Total frames|Janky frames:|50th percentile|90th percentile|95th percentile|99th percentile|Number Missed Vsync|Number Slow UI thread|Number Slow issue draw commands|Number Slow bitmap" | ForEach-Object { $_.Line.Trim() }) | ForEach-Object { Write-Output $_ }

# --- screenshot ---
adb shell screencap -p /sdcard/te-shot.png 2>$null | Out-Null
adb pull /sdcard/te-shot.png "$OutDir\screenshot.png" 2>&1 | Out-Null
Get-Item "$OutDir\screenshot.png" -ErrorAction SilentlyContinue | Select-Object Length | Format-List

# --- textos na tela ---
adb shell uiautomator dump /sdcard/u.xml 2>&1 | Out-Null
adb pull /sdcard/u.xml "$OutDir\uifinal.xml" 2>&1 | Out-Null
$u = Get-Content "$OutDir\uifinal.xml" -Raw -ErrorAction SilentlyContinue
if ($u) { [regex]::Matches($u,'text="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ } | ForEach-Object { Write-Output $_ } }

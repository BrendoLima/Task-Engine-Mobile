# Instala um APK release no dispositivo conectado, abre o app e salva screenshot + dump de UI.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-and-verify.ps1
#   ... -Apk dist\task-engine-arm64.apk -Package com.taskengine.mobile
param(
  [string]$Apk,
  [string]$OutDir,
  [string]$Package = "com.taskengine.mobile"
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Apk) { $Apk = Join-Path $Root "dist\task-engine-arm64.apk" }
if (-not $OutDir) { $OutDir = Join-Path $Root "dist" }
if (-not (Test-Path $Apk)) { throw "APK nao encontrado: $Apk (rode 'npm run apk')" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Evita sobras de execucoes anteriores
Remove-Item "$OutDir\screenshot.png","$OutDir\uifinal.xml" -Force -ErrorAction SilentlyContinue

Write-Output "Aguardando boot_completed..."
$boot = ""
for ($i = 0; $i -lt 120; $i++) {
  $boot = (adb shell getprop sys.boot_completed 2>$null | Out-String).Trim()
  if ($boot -eq "1") { break }
  Start-Sleep -Seconds 5
}
if ($boot -ne "1") { Write-Output "FALHA: boot nao concluiu"; adb devices; exit 1 }
Write-Output "Boot concluido."

adb shell settings put global window_animation_scale 0 | Out-Null
adb shell settings put global transition_animation_scale 0 | Out-Null
adb shell settings put global animator_duration_scale 0 | Out-Null

Write-Output "Instalando APK..."
$install = adb install -r $Apk 2>&1 | Out-String
Write-Output $install
if ($LASTEXITCODE -ne 0 -or $install -notmatch "Success") {
  Write-Output "FALHA: instalacao do APK nao concluiu"
  adb devices
  exit 1
}

$state = (adb get-state 2>$null | Out-String).Trim()
if ($state -ne "device") { Write-Output "FALHA: dispositivo offline ($state)"; exit 1 }

Write-Output "Compilando app em modo speed (AOT)..."
adb shell cmd package compile -m speed -f $Package 2>&1 | Out-String | Write-Output

Write-Output "Iniciando app..."
adb shell am force-stop $Package | Out-Null
adb shell am start -n "$Package/.MainActivity" 2>&1 | Out-String | Write-Output

Start-Sleep -Seconds 20

Write-Output "Capturando tela..."
cmd /c "adb exec-out screencap -p > `"$OutDir\screenshot.png`""
Get-Item "$OutDir\screenshot.png" -ErrorAction SilentlyContinue | Select-Object Length,LastWriteTime | Format-List

Write-Output "Dump de UI..."
adb shell uiautomator dump /sdcard/uifinal.xml 2>&1 | Out-String | Write-Output
adb pull /sdcard/uifinal.xml "$OutDir\uifinal.xml" 2>&1 | Out-String | Write-Output

$x = Get-Content "$OutDir\uifinal.xml" -Raw -ErrorAction SilentlyContinue
if ($x) {
  Write-Output "---- textos na tela ----"
  [regex]::Matches($x, 'text="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ } | ForEach-Object { Write-Output $_ }
}

Write-Output "---- foco ----"
adb shell dumpsys window 2>$null | Select-String -Pattern "mCurrentFocus" | Select-Object -First 1 | ForEach-Object { Write-Output $_.Line.Trim() }


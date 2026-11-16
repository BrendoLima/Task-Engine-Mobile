# Diagnostico: sobe o AVD sem as flags extras usadas pelo dev.ps1 e confere se o app abre.
# Serve para confirmar se o problema de boot e do emulador (advancedFeatures.ini) ou das flags.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\diagnostics\verify-studio-launch.ps1
#   ... -Avd TaskEngine33
param(
  [string]$Avd = "GalaxyA15",
  [string]$AvdHome = $(if ($env:ANDROID_AVD_HOME) { $env:ANDROID_AVD_HOME } else { Join-Path $env:USERPROFILE ".android\avd" }),
  [string]$Package = "com.taskengine.mobile"
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:ANDROID_AVD_HOME = $AvdHome

$Sdk = $env:ANDROID_HOME
if (-not $Sdk) { $Sdk = $env:ANDROID_SDK_ROOT }
if (-not $Sdk) { $Sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$Emulator = Join-Path $Sdk "emulator\emulator.exe"
if (-not (Test-Path $Emulator)) { throw "emulator nao encontrado em $Emulator" }

Write-Output "Encerrando emulador atual..."
adb emu kill | Out-Null
Start-Sleep -Seconds 5
Get-Process -Name "qemu-system-x86_64-headless", "emulator" -ErrorAction SilentlyContinue |
  Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$LogDir = Join-Path $Root "dist"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$log = Join-Path $LogDir "emu-studio-sim.log"
$err = Join-Path $LogDir "emu-studio-sim.err"
Remove-Item $log, $err -ErrorAction SilentlyContinue

Write-Output "Iniciando sem -feature (apenas advancedFeatures.ini), como o Android Studio faz..."
$p = Start-Process -FilePath $Emulator `
  -ArgumentList @("-avd", $Avd, "-no-window", "-no-audio", "-gpu", "swiftshader_indirect") `
  -RedirectStandardOutput $log -RedirectStandardError $err -PassThru -WindowStyle Hidden
Write-Output "emulator PID=$($p.Id)"

$ok = $false
for ($i = 0; $i -lt 100; $i++) {
  Start-Sleep -Seconds 6
  if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) {
    Write-Output "PROCESSO DO EMULADOR TERMINOU (iteracao $i)"
    break
  }
  $b = (adb shell getprop sys.boot_completed 2>$null | Out-String).Trim()
  if ($b -eq "1") { $ok = $true; break }
}

if ($ok) {
  Write-Output "BOOT OK sem flags extras"
  adb shell am start -n "$Package/.MainActivity" | Out-Null
  Start-Sleep -Seconds 10
  adb shell uiautomator dump /sdcard/us.xml 2>&1 | Out-Null
  $local = Join-Path $LogDir "us.xml"
  adb pull /sdcard/us.xml $local 2>&1 | Out-Null
  $ui = Get-Content $local -Raw -ErrorAction SilentlyContinue
  if ($ui) {
    Write-Output "---- textos ----"
    [regex]::Matches($ui, 'text="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } |
      Where-Object { $_ } | ForEach-Object { Write-Output $_ }
  }
} else {
  Write-Output "FALHOU sem flags extras"
  Write-Output "---- ultimas linhas do log ----"
  Get-Content $log -Tail 20 -ErrorAction SilentlyContinue
}

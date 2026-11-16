# Inicia o AVD configurado para esta maquina.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-emulator.ps1 [-Avd GalaxyA15] [-Headless]
param(
  [string]$Avd = "GalaxyA15",
  [string]$AvdHome = $(if ($env:ANDROID_AVD_HOME) { $env:ANDROID_AVD_HOME } else { Join-Path $env:USERPROFILE ".android\avd" }),
  [switch]$Headless
)

$ErrorActionPreference = "Stop"
$env:ANDROID_AVD_HOME = $AvdHome

$Sdk = $env:ANDROID_HOME
if (-not $Sdk) { $Sdk = $env:ANDROID_SDK_ROOT }
if (-not $Sdk) { $Sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$Emulator = Join-Path $Sdk "emulator\emulator.exe"
if (-not (Test-Path $Emulator)) { throw "emulator nao encontrado em $Emulator" }

$emuArgs = @(
  "-avd", $Avd,
  "-no-audio",
  "-no-boot-anim",
  "-gpu", "swiftshader",
  "-no-snapshot",
  "-no-snapshot-save"
)
if ($Headless) { $emuArgs += "-no-window" }

Write-Host "Iniciando $Avd (Ctrl+C encerra)..."
& $Emulator @emuArgs

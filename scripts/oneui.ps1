# Reaplica a aparencia estilo One UI no emulador: launcher + wallpaper.
#
#   npm run oneui
#
# O "home" preferido nao sobrevive a todo boot frio do AOSP, entao rode isto depois de
# reiniciar o emulador (ou use junto com npm run dev). O wallpaper e aplicado via
# WallpaperManager (scripts/set-wallpaper.ps1), sem abrir a galeria.
param(
  [string]$LauncherApk = (Join-Path (Split-Path -Parent $PSScriptRoot) "dist\tools\lawnchair.apk"),
  [switch]$SkipWallpaper
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Text) {
  Write-Host ""
  Write-Host "==> $Text" -ForegroundColor Cyan
}

$Sdk = $env:ANDROID_HOME
if (-not $Sdk) { $Sdk = $env:ANDROID_SDK_ROOT }
if (-not $Sdk) { $Sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$Adb = Join-Path $Sdk "platform-tools\adb.exe"
if (-not (Test-Path $Adb)) { throw "adb nao encontrado em $Adb" }
if ((& $Adb get-state 2>$null | Out-String).Trim() -ne "device") {
  throw "Nenhum emulador/aparelho conectado. Rode 'npm run dev' antes."
}

# --- launcher ---
Write-Step "Launcher (Lawnchair)"
$installed = (& $Adb shell "pm list packages app.lawnchair" 2>$null | Out-String) -match "app.lawnchair"
if (-not $installed) {
  if (-not (Test-Path $LauncherApk)) {
    Write-Host "AVISO: $LauncherApk nao existe; mantendo o launcher atual." -ForegroundColor Yellow
    Write-Host "       Baixe em https://github.com/LawnchairLauncher/lawnchair/releases" -ForegroundColor Yellow
  } else {
    & $Adb install -r $LauncherApk 2>&1 | Select-Object -Last 2
    $installed = (& $Adb shell "pm list packages app.lawnchair" 2>$null | Out-String) -match "app.lawnchair"
  }
}

if ($installed) {
  & $Adb shell "cmd package set-home-activity app.lawnchair/app.lawnchair.LawnchairLauncher" 2>&1 | Out-Null
  Start-Sleep -Seconds 1
  & $Adb shell input keyevent 3 | Out-Null

  # O resolver pode demorar a trocar de home enquanto o launcher novo sobe.
  $homeActivity = ""
  for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    $homeActivity = (& $Adb shell "cmd package resolve-activity -c android.intent.category.HOME -a android.intent.action.MAIN" 2>$null | Out-String)
    if ($homeActivity -match "app\.lawnchair") { break }
  }
  if ($homeActivity -match "app\.lawnchair") {
    Write-Host "home = app.lawnchair (OK)" -ForegroundColor Green
  } else {
    Write-Host "AVISO: o sistema ainda resolve outro home; veja 'cmd package set-home-activity'." -ForegroundColor Yellow
  }
} else {
  Write-Host "Lawnchair nao instalado; pulando." -ForegroundColor Yellow
}

# --- wallpaper ---
if (-not $SkipWallpaper) {
  Write-Step "Wallpaper"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "set-wallpaper.ps1")
}

Write-Host ""
Write-Host "Pronto. Reverter: npm run oneui -- -SkipWallpaper nao reverte o launcher;" -ForegroundColor Cyan
Write-Host "para voltar ao AOSP:" -ForegroundColor Cyan
Write-Host "    adb shell cmd package set-home-activity com.android.launcher3/com.android.launcher3.uioverrides.QuickstepLauncher"

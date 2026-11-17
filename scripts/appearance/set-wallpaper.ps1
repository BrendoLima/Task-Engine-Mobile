# Aplica o wallpaper no emulador sem abrir nenhuma tela (via app_process + WallpaperManager).
#
#   npm run wallpaper                          -> gera (se preciso) e aplica dist\tools\wallpaper-oneui.png
#   npm run wallpaper -- -Image C:\foto.png    -> aplica outra imagem
#
# Requisitos: adb root no emulador (imagem AOSP userdebug, que e o caso do GalaxyA15),
# JDK (javac) e build-tools do SDK (d8). Se a imagem nao existir, roda make-wallpaper.ps1.
#
# Por que nao usar a galeria: o picker/cropper do AOSP usa SurfaceView com renderizacao GL
# e derrubou o emulador (SwiftShader) mais de uma vez. Aqui o wallpaper e gravado direto
# pelo servico do sistema, sem UI.
param(
  [string]$Image = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "dist\tools\wallpaper-oneui.png")
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$Sdk = $env:ANDROID_HOME
if (-not $Sdk) { $Sdk = $env:ANDROID_SDK_ROOT }
if (-not $Sdk) { $Sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$Adb = Join-Path $Sdk "platform-tools\adb.exe"
if (-not (Test-Path $Adb)) { throw "adb nao encontrado em $Adb" }

$bt = Get-ChildItem (Join-Path $Sdk "build-tools") -Directory -ErrorAction SilentlyContinue |
  Sort-Object {
    $p = ($_.Name -replace '^[^0-9]*', '') -split '\.'
    $a = [int]$p[0]; $b = if ($p.Count -gt 1) { [int]$p[1] } else { 0 }; $c = if ($p.Count -gt 2) { [int]$p[2] } else { 0 }
    $a * 10000 + $b * 100 + $c
  } -Descending |
  Select-Object -First 1
if (-not $bt) { throw "build-tools do SDK nao encontrado" }
$D8 = Join-Path $bt.FullName "d8.bat"
$Platform = Get-ChildItem (Join-Path $Sdk "platforms") -Directory -ErrorAction SilentlyContinue |
  Sort-Object {
    $p = ($_.Name -replace '^[^0-9]*', '') -split '\.'
    $a = [int]$p[0]; $b = if ($p.Count -gt 1) { [int]$p[1] } else { 0 }
    $a * 10000 + $b * 100
  } -Descending |
  Select-Object -First 1
$Jar = Join-Path $Platform.FullName "android.jar"
if (-not (Test-Path $Jar)) { throw "android.jar nao encontrado em $Jar" }

$Javac = (Get-Command javac -ErrorAction SilentlyContinue).Source
if (-not $Javac) {
  $jdk = Get-ChildItem "C:\Program Files\Microsoft\jdk-*\bin\javac.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($jdk) { $Javac = $jdk.FullName }
}
if (-not $Javac) { throw "javac nao encontrado (instale um JDK ou use o do Android Studio)" }

if (-not (Test-Path $Image)) {
  Write-Host "Imagem nao existe; gerando em $Image..." -ForegroundColor Yellow
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "make-wallpaper.ps1") -Out $Image | Out-Null
}
if (-not (Test-Path $Image)) { throw "imagem nao encontrada: $Image" }

# --- dispositivo + root ---
$state = (& $Adb get-state 2>$null | Out-String).Trim()
if ($state -ne "device") { throw "Nenhum emulador/aparelho conectado." }

$who = (& $Adb shell id 2>$null | Out-String)
if ($who -notmatch "uid=0") {
  Write-Host "Ativando adb root..." -ForegroundColor Cyan
  & $Adb root 2>$null | Out-Null
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    $who = (& $Adb shell id 2>$null | Out-String)
    if ($who -match "uid=0") { break }
  }
  if ($who -notmatch "uid=0") {
    throw "Precisa de root (adb root). Em aparelho fisico isso nao esta disponivel; use a galeria."
  }
}

# --- compila o helper ---
$Build = Join-Path $Root "dist\tools\wallpaper-build"
New-Item -ItemType Directory -Force -Path (Join-Path $Build "classes"), (Join-Path $Build "dex") | Out-Null
& $Javac -nowarn -source 8 -target 8 -cp $Jar -d (Join-Path $Build "classes") (Join-Path $PSScriptRoot "wallpaper\SetWallpaper.java") 2>&1 |
  Where-Object { $_ -notmatch "^Note:" } | Out-Null
if ($LASTEXITCODE -ne 0) { throw "falha ao compilar SetWallpaper.java" }

& $D8 --lib $Jar --output (Join-Path $Build "dex") (Join-Path $Build "classes\wpset\SetWallpaper.class") 2>&1 |
  Out-Null
if ($LASTEXITCODE -ne 0) { throw "falha no d8" }

# --- envia e executa como system (uid 1000) ---
& $Adb push (Join-Path $Build "dex\classes.dex") /data/local/tmp/wpset.dex 2>&1 | Out-Null
& $Adb push $Image /data/local/tmp/wallpaper.png 2>&1 | Out-Null
& $Adb shell chmod 644 /data/local/tmp/wpset.dex /data/local/tmp/wallpaper.png | Out-Null

$out = (& $Adb shell "su 1000,1000 sh -c 'CLASSPATH=/data/local/tmp/wpset.dex app_process /system/bin wpset.SetWallpaper /data/local/tmp/wallpaper.png'" 2>&1 | Out-String)
Write-Host $out.Trim()

if ($out -notmatch "OK wallpaperId") {
  throw "o servico de wallpaper recusou a chamada (veja 'adb logcat | grep wpset')"
}

& $Adb shell input keyevent 3 | Out-Null
Write-Host "Wallpaper aplicado (home + tela de bloqueio)." -ForegroundColor Green
& $Adb shell "dumpsys wallpaper" 2>$null | Select-String -Pattern "mBindSource|mWhich" |
  Select-Object -First 2 | ForEach-Object { Write-Host "    $($_.Line.Trim())" }

# Gera um APK release para instalar no celular (sem Metro, JS embutido).
#
#   npm run apk                            -> arm64-v8a (Galaxy A15 e praticamente todo celular atual)
#   npm run apk -- -Arch armeabi-v7a       -> celulares 32 bits antigos
#   npm run apk -- -Arch arm64-v8a,armeabi-v7a,x86_64  -> APK universal (maior)
#
# O APK sai em dist\task-engine-arm64.apk (ou task-engine-arm64-armv7.apk etc.).
# A assinatura usa android\app\debug.keystore, a mesma do template do React Native:
# serve para testar no aparelho, nao para publicar na Play Store.
param(
  [string]$Arch = "arm64-v8a",
  [string]$Out,
  [switch]$NoClean
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$Android = Join-Path $Root "android"

function Write-Step([string]$Text) {
  Write-Host ""
  Write-Host "==> $Text" -ForegroundColor Cyan
}

# --- SDK / tools ---
$Sdk = $env:ANDROID_HOME
if (-not $Sdk) { $Sdk = $env:ANDROID_SDK_ROOT }
if (-not $Sdk) { $Sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
if (-not (Test-Path $Sdk)) { throw "SDK Android nao encontrado em $Sdk" }

. (Join-Path $PSScriptRoot "fix-ninja.ps1")

$bt = Get-ChildItem (Join-Path $Sdk "build-tools") -Directory -ErrorAction SilentlyContinue |
  Sort-Object {
    $p = ($_.Name -replace '^[^0-9]*', '') -split '\.'
    $a = [int]$p[0]; $b = if ($p.Count -gt 1) { [int]$p[1] } else { 0 }; $c = if ($p.Count -gt 2) { [int]$p[2] } else { 0 }
    $a * 10000 + $b * 100 + $c
  } -Descending |
  Select-Object -First 1
$aapt2 = if ($bt) { Join-Path $bt.FullName "aapt2.exe" } else { $null }

if (-not $Out) {
  # nomes curtos e estaveis: arm64-v8a -> arm64, armeabi-v7a -> armv7
  $suffix = ($Arch -split "," | ForEach-Object {
    switch ($_.Trim()) {
      "arm64-v8a" { "arm64" }
      "armeabi-v7a" { "armv7" }
      default { $_.Trim() }
    }
  }) -join "-"
  $Out = Join-Path $Root "dist\task-engine-$suffix.apk"
}

Write-Step "Build release ($Arch)"
Ensure-Ninja -Sdk $Sdk -Root $Root

$tasks = @("assembleRelease", "-PreactNativeArchitectures=$Arch", "--console=plain")
if (-not $NoClean) { $tasks = @("clean") + $tasks }

Push-Location $Android
& cmd /c "gradlew.bat $($tasks -join ' ')"
$code = $LASTEXITCODE
Pop-Location

if ($code -ne 0) {
  Write-Host "FALHA: gradle retornou $code." -ForegroundColor Red
  exit $code
}

$apk = Join-Path $Android "app\build\outputs\apk\release\app-release.apk"
if (-not (Test-Path $apk)) {
  Write-Host "FALHA: APK nao encontrado em $apk" -ForegroundColor Red
  exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
Copy-Item $apk $Out -Force

$size = [math]::Round((Get-Item $Out).Length / 1MB, 1)
Write-Host ""
Write-Host ("==> APK pronto: {0} ({1} MB)" -f $Out, $size) -ForegroundColor Green

if ($aapt2 -and (Test-Path $aapt2)) {
  $badging = (& $aapt2 dump badging $Out 2>$null | Out-String)
  $lines = $badging -split "`r?`n" | Where-Object {
    $_ -match "^package:|^(min|target)?[Ss]dkVersion|^native-code|^application-label:"
  }
  $lines | ForEach-Object { Write-Host "    $_" }
  if ($badging -notmatch [regex]::Escape("arm64-v8a") -and $Arch -match "arm64") {
    Write-Host "    AVISO: o APK nao declara arm64-v8a." -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "Instalar no celular (USB com depuracao ativada):" -ForegroundColor Cyan
Write-Host "    adb install -r `"$Out`""
Write-Host "    adb shell am start -n com.taskengine.mobile/.MainActivity"
Write-Host "Sem cabo: copie o APK para o celular e abra pelo gerenciador de arquivos"
Write-Host "(permita 'instalar apps desconhecidos' para o app usado)."

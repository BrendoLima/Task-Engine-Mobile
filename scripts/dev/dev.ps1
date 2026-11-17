# Um comando para rodar o app no emulador Android:
#   npm run dev                 -> GalaxyA15 (Android 16): emulador + Metro + build/install + aparencia One UI + abre o app
#   npm run dev:33              -> mesmo fluxo no TaskEngine33 (Android 13)
#   npm run dev:fast            -> sem rebuild: sobe emulador + Metro e abre o app ja instalado
#   npm run dev -- -Avd <nome>  -> escolhe outro AVD
#   npm run dev -- -Restart     -> reinicia o emulador do zero
#   npm run dev -- -NoMetro     -> nao sobe Metro (use se ja tiver um rodando fora do script)
#   npm run dev -- -NoOneUI     -> nao mexe em launcher/wallpaper
param(
  [string]$Avd = "GalaxyA15",
  [switch]$SkipBuild,
  [switch]$NoMetro,
  [switch]$NoOneUI,
  [switch]$Restart
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Package = "com.taskengine.mobile"
$MetroPort = 8081

function Write-Step([string]$Text) {
  Write-Host ""
  Write-Host "==> $Text" -ForegroundColor Cyan
}

# --- ferramentas do SDK ---
$Sdk = $env:ANDROID_HOME
if (-not $Sdk) { $Sdk = $env:ANDROID_SDK_ROOT }
if (-not $Sdk) { $Sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }

$Adb = Join-Path $Sdk "platform-tools\adb.exe"
$Emulator = Join-Path $Sdk "emulator\emulator.exe"
if (-not (Test-Path $Adb)) { throw "adb nao encontrado em $Adb" }
if (-not (Test-Path $Emulator)) { throw "emulator nao encontrado em $Emulator" }

function Get-OnlineDevice {
  $lines = (& $Adb devices 2>$null | Out-String) -split "`r?`n"
  foreach ($line in $lines) {
    if ($line -match "^(emulator-\d+)\s+device$") { return $Matches[1] }
  }
  foreach ($line in $lines) {
    if ($line -match "^(\S+)\s+device$") { return $Matches[1] }
  }
  return $null
}

function Test-EmulatorProcess {
  return [bool](Get-Process -Name "qemu-system-x86_64" -ErrorAction SilentlyContinue |
    Select-Object -First 1)
}

function Wait-Boot([int]$TimeoutSeconds = 300) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $state = (& $Adb get-state 2>$null | Out-String).Trim()
    if ($state -eq "device") {
      $boot = (& $Adb shell getprop sys.boot_completed 2>$null | Out-String).Trim()
      if ($boot -eq "1") { return $true }
    }
    Start-Sleep -Seconds 2
  }
  return $false
}

function Test-Metro {
  return [bool](Get-NetTCPConnection -LocalPort $MetroPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1)
}

# O ninja 1.10.2 que acompanha o CMake 3.22.1 do SDK falha neste Windows/projeto
# com "missing and no known rule to make it" em qualquer arquivo dentro de
# node_modules. Ensure-Ninja (scripts\dev\fix-ninja.ps1) troca por ninja >= 1.12.
. (Join-Path $PSScriptRoot "fix-ninja.ps1")

function Start-Emulator([string]$Name) {
  $cmdLine = '"{0}" -avd {1} -no-audio -no-boot-anim -gpu swiftshader -no-snapshot -no-snapshot-save' -f $Emulator, $Name
  $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine      = $cmdLine
    CurrentDirectory = $Root
  }
  if ($r.ReturnValue -ne 0) { throw "Falha ao iniciar o emulador (ReturnValue=$($r.ReturnValue))" }
  Write-Host "emulator pid=$($r.ProcessId)"
}

# --- 1. emulador ---
Write-Step "Emulador ($Avd)"
$device = Get-OnlineDevice

if ($Restart) {
  if ($device) {
    Write-Host "Reiniciando: encerrando o emulador atual..."
    & $Adb emu kill 2>$null | Out-Null
    for ($i = 0; $i -lt 30 -and (Get-OnlineDevice); $i++) { Start-Sleep -Seconds 1 }
  }
  $device = $null
}

if ($device) {
  Write-Host "Reutilizando dispositivo ja conectado: $device"
} elseif (Test-EmulatorProcess) {
  Write-Host "Emulador ja esta iniciando; aguardando o boot..."
  if (-not (Wait-Boot 300)) {
    Write-Host "FALHA: o emulador nao terminou o boot." -ForegroundColor Red
    & $Adb devices
    exit 1
  }
  $device = Get-OnlineDevice
  Write-Host "Boot concluido: $device"
} else {
  Write-Host "Subindo o AVD $Avd (SwiftShader, sem snapshot)..."
  Start-Emulator $Avd
  Write-Host "Aguardando boot (pode levar ~2 min na primeira vez)..."
  if (-not (Wait-Boot 300)) {
    Write-Host "FALHA: o emulador nao terminou o boot." -ForegroundColor Red
    & $Adb devices
    exit 1
  }
  $device = Get-OnlineDevice
  Write-Host "Boot concluido: $device"
}

# --- 2. ajustes de fluidez ---
Write-Step "Ajustes (tela do AVD, animacoes desligadas)"
& $Adb shell wm size reset 2>$null | Out-Null
& $Adb shell wm density reset 2>$null | Out-Null
& $Adb shell settings put global window_animation_scale 0 2>$null | Out-Null
& $Adb shell settings put global transition_animation_scale 0 2>$null | Out-Null
& $Adb shell settings put global animator_duration_scale 0 2>$null | Out-Null
& $Adb shell input keyevent 82 2>$null | Out-Null
Write-Host "OK"

# --- 3. Metro ---
$MetroLog = Join-Path $Root "dist\metro.log"
if ($NoMetro) {
  Write-Step "Metro ignorado (-NoMetro)"
} elseif (Test-Metro) {
  Write-Step "Metro ja esta rodando na porta $MetroPort"
} else {
  Write-Step "Iniciando Metro em uma janela separada (log: dist\metro.log)"
  New-Item -ItemType Directory -Force -Path (Join-Path $Root "dist") | Out-Null
  Remove-Item $MetroLog -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "`"$(Join-Path $PSScriptRoot 'metro.ps1')`"" `
    -WorkingDirectory $Root | Out-Null

  for ($i = 0; $i -lt 120 -and -not (Test-Metro); $i++) { Start-Sleep -Seconds 1 }

  if (Test-Metro) {
    Write-Host "Metro pronto."
  } else {
    Write-Host "FALHA: Metro nao abriu a porta $MetroPort em 120s." -ForegroundColor Red
    if (Test-Path $MetroLog) {
      Write-Host "---- ultimas linhas de dist\metro.log ----"
      Get-Content $MetroLog -Tail 20
      Write-Host "------------------------------------------"
    }
    exit 1
  }
}

& $Adb reverse "tcp:$MetroPort" "tcp:$MetroPort" 2>$null | Out-Null

# --- 4. build + install + launch ---
$RnCli = Join-Path $Root "node_modules\react-native\cli.js"
Push-Location $Root

if ($SkipBuild) {
  Write-Step "Abrindo o app ja instalado (sem rebuild)"
  & $Adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 2>$null | Out-Null
} else {
  Write-Step "Compilando e instalando (primeira vez demora alguns minutos)"
  Ensure-Ninja -Sdk $Sdk -Root $Root
  $buildArgs = @("run-android", "--active-arch-only", "--no-packager")
  if ($device) { $buildArgs += @("--device", $device) }
  & node $RnCli @buildArgs
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FALHA: build/install retornou codigo $($LASTEXITCODE)." -ForegroundColor Red
    Pop-Location
    exit $LASTEXITCODE
  }
  & $Adb reverse "tcp:$MetroPort" "tcp:$MetroPort" 2>$null | Out-Null
}

Pop-Location

# --- 5. aparencia estilo One UI (idempotente) ---
# O "home" preferido nao sobrevive a todo boot frio do AOSP e o wallpaper pode voltar ao padrao,
# entao o proprio dev reaplica o que faltar. Use -NoOneUI para nao mexer nisso.
if (-not $NoOneUI) {
  try {
  $homePkg = ""
  $wallInfo = ""
  $lookArgs = @()
  $needsLauncher = $true
  $needsWallpaper = $true

  $homeOut = (& $Adb shell "cmd package resolve-activity -c android.intent.category.HOME -a android.intent.action.MAIN" 2>$null | Out-String)
  if ($homeOut -match "packageName=([\w\.]+)") { $homePkg = $Matches[1] }
  $needsLauncher = ($homePkg -ne "app.lawnchair")

  $wallInfo = (& $Adb shell "dumpsys wallpaper" 2>$null | Out-String)
  $needsWallpaper = ($wallInfo -notmatch "mBindSource=SET_STATIC")

  if ($needsLauncher -or $needsWallpaper) {
    Write-Step "Aparencia One UI (launcher: $needsLauncher, wallpaper: $needsWallpaper)"
    if (-not $needsWallpaper) { $lookArgs += "-SkipWallpaper" }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path -Parent $PSScriptRoot) "appearance\oneui.ps1") @lookArgs
    # adb root (usado pelo wallpaper) reinicia o adbd; espera voltar antes de reabrir o app.
    for ($i = 0; $i -lt 30; $i++) {
      if ((& $Adb get-state 2>$null | Out-String).Trim() -eq "device") { break }
      Start-Sleep -Seconds 1
    }
    & $Adb shell am start -n "$Package/.MainActivity" 2>$null | Out-Null
  } else {
    Write-Step "Aparencia One UI ja aplicada (Lawnchair + wallpaper)"
  }
  } catch {
    Write-Host "AVISO: nao consegui aplicar a aparencia One UI ($($_.Exception.Message))." -ForegroundColor Yellow
    Write-Host "       O app segue funcionando; rode 'npm run oneui' quando quiser." -ForegroundColor Yellow
  }
}

# --- 6. confirma que o app abriu ---
$focus = ""
for ($i = 0; $i -lt 60; $i++) {
  $focus = (& $Adb shell dumpsys window 2>$null | Select-String "mCurrentFocus" |
    Select-Object -First 1 | Out-String)
  if ($focus -match [regex]::Escape($Package)) { break }
  Start-Sleep -Seconds 1
}

Write-Host ""
if ($focus -match [regex]::Escape($Package)) {
  Write-Host "==> Pronto! App aberto em $device." -ForegroundColor Green
} else {
  Write-Host "==> Build/instalacao OK, mas o app nao apareceu em foco." -ForegroundColor Yellow
  Write-Host "    Abra manualmente: adb shell am start -n $Package/.MainActivity"
}
Write-Host "    Parar o emulador: npm run emu:stop"

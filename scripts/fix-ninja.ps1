# Correcao do ninja do SDK (usada por dev.ps1 e build-apk.ps1).
#
# O ninja 1.10.2 que acompanha o CMake 3.22.1 do SDK falha neste Windows/projeto com
# "missing and no known rule to make it" em qualquer arquivo dentro de node_modules
# (o arquivo existe; o ninja antigo nao consegue enxerga-lo). Usamos ninja >= 1.12,
# mantendo o binario original como ninja.exe.bak e o novo em cache em dist\tools.

function Ensure-Ninja {
  param(
    [Parameter(Mandatory = $true)][string]$Sdk,
    [Parameter(Mandatory = $true)][string]$Root
  )

  $cmakeRoot = Join-Path $Sdk "cmake"
  if (-not (Test-Path $cmakeRoot)) { return }

  $targets = Get-ChildItem $cmakeRoot -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "bin\ninja.exe" } |
    Where-Object { Test-Path $_ }

  $outdated = @()
  foreach ($n in $targets) {
    $v = (& $n --version 2>$null | Out-String).Trim()
    if ($v -match '^(\d+)\.(\d+)' -and ([int]$Matches[1] -lt 1 -or ([int]$Matches[1] -eq 1 -and [int]$Matches[2] -lt 12))) {
      $outdated += [pscustomobject]@{ Path = $n; Version = $v }
    }
  }
  if ($outdated.Count -eq 0) { return }

  $cacheDir = Join-Path $Root "dist\tools"
  $cached = Join-Path $cacheDir "ninja.exe"
  if (-not (Test-Path $cached)) {
    Write-Host "ninja $($outdated[0].Version) e antigo demais; baixando ninja 1.13.1..."
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    $zip = Join-Path $cacheDir "ninja-win.zip"
    try {
      Invoke-WebRequest -Uri "https://github.com/ninja-build/ninja/releases/download/v1.13.1/ninja-win.zip" `
        -OutFile $zip -UseBasicParsing -TimeoutSec 120
      Expand-Archive -Path $zip -DestinationPath $cacheDir -Force
      Remove-Item $zip -Force -ErrorAction SilentlyContinue
    } catch {
      Write-Host "AVISO: nao consegui baixar o ninja novo ($($_.Exception.Message))." -ForegroundColor Yellow
      Write-Host "       O build C++ pode falhar; veja 'ninja' no README." -ForegroundColor Yellow
      return
    }
  }

  foreach ($n in $outdated) {
    $bak = "$($n.Path).bak"
    if (-not (Test-Path $bak)) { Copy-Item $n.Path $bak -Force }
    Copy-Item $cached $n.Path -Force
    Write-Host "ninja $($n.Version) -> $((& $n.Path --version 2>$null | Out-String).Trim()) em $($n.Path)"
  }
}

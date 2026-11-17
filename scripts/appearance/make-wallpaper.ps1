# Gera o wallpaper "estilo One UI" (gradiente escuro + blobs suaves) em dist\tools.
#   pwsh/powershell -File scripts\appearance\make-wallpaper.ps1 [-Width 648] [-Height 1404] [-Seed 7]
param(
  [int]$Width = 648,
  [int]$Height = 1404,
  [int]$Seed = 7,
  [string]$Out = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "dist\tools\wallpaper-oneui.png")
)

Add-Type -AssemblyName System.Drawing

$rand = New-Object System.Random($Seed)
$bmp = New-Object System.Drawing.Bitmap($Width, $Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# --- fundo: gradiente diagonal escuro (azul-noite -> roxo -> verde-petroleo) ---
$rect = New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $rect,
  [System.Drawing.Color]::FromArgb(255, 10, 16, 38),
  [System.Drawing.Color]::FromArgb(255, 4, 18, 26),
  [single]72)
$blend = New-Object System.Drawing.Drawing2D.ColorBlend(3)
$blend.Colors = @(
  [System.Drawing.Color]::FromArgb(255, 10, 16, 38),
  [System.Drawing.Color]::FromArgb(255, 26, 18, 58),
  [System.Drawing.Color]::FromArgb(255, 4, 18, 26)
)
$blend.Positions = @([single]0.0, [single]0.55, [single]1.0)
$bg.InterpolationColors = $blend
$g.FillRectangle($bg, $rect)
$bg.Dispose()

# --- blobs: elipses com gradiente radial (centro forte, borda transparente) ---
function Add-Blob([double]$cx, [double]$cy, [double]$r, [System.Drawing.Color]$c) {
  $rx = $r
  $ry = $r * (0.85 + 0.5 * $rand.NextDouble())
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse([single]($cx - $rx), [single]($cy - $ry), [single]($rx * 2), [single]($ry * 2))
  $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $pgb.CenterColor = $c
  $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
  $pgb.FocusScales = New-Object System.Drawing.PointF(0.30, 0.30)
  $g.FillPath($pgb, $path)
  $pgb.Dispose()
  $path.Dispose()
}

Add-Blob ($Width * 0.18) ($Height * 0.16) ($Width * 0.72) ([System.Drawing.Color]::FromArgb(190, 96, 70, 255))
Add-Blob ($Width * 0.92) ($Height * 0.34) ($Width * 0.66) ([System.Drawing.Color]::FromArgb(150, 40, 96, 255))
Add-Blob ($Width * 0.10) ($Height * 0.55) ($Width * 0.60) ([System.Drawing.Color]::FromArgb(120, 40, 200, 170))
Add-Blob ($Width * 0.88) ($Height * 0.74) ($Width * 0.55) ([System.Drawing.Color]::FromArgb(115, 255, 122, 96))
Add-Blob ($Width * 0.45) ($Height * 0.92) ($Width * 0.80) ([System.Drawing.Color]::FromArgb(165, 74, 48, 168))

# --- vinheta suave nas bordas ---
$vpath = New-Object System.Drawing.Drawing2D.GraphicsPath
$vpath.AddEllipse([single](-$Width * 0.35), [single](-$Height * 0.15), [single]($Width * 1.7), [single]($Height * 1.3))
$vpgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($vpath)
$vpgb.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
$vpgb.SurroundColors = @([System.Drawing.Color]::FromArgb(215, 2, 3, 8))
$g.FillPath($vpgb, $vpath)
$vpgb.Dispose()
$vpath.Dispose()

# --- grao (ruido sutil): desenha em um bitmap menor e amplia com bilinear ---
$nw = [int]($Width / 3); $nh = [int]($Height / 3)
$noise = New-Object System.Drawing.Bitmap($nw, $nh)
for ($y = 0; $y -lt $nh; $y++) {
  for ($x = 0; $x -lt $nw; $x++) {
    $v = $rand.Next(0, 255)
    $a = if ($rand.NextDouble() -gt 0.5) { 26 } else { 0 }
    $noise.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $v, $v, $v))
  }
}
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($noise, (New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)))
$noise.Dispose()

$g.Dispose()
$dir = Split-Path -Parent $Out
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("wallpaper: {0} ({1}x{2}, {3} bytes)" -f $Out, $Width, $Height, (Get-Item $Out).Length)

# Ajusta o AVD GalaxyA15 para imitar a tela/RAM do Galaxy A15 (SM-A155M)
# mantendo a fluidez: mesma area logica do A15 (411x891 dp, 19,5:9) com 648x1404 @252 dpi.
# Para tentar a resolucao real (1080x2340 @420) sem mexer no AVD: npm run screen -- -Size 1080x2340 -Density 420
param(
  [string]$Avd = "GalaxyA15",
  [string]$AvdHome = $(if ($env:ANDROID_AVD_HOME) { $env:ANDROID_AVD_HOME } else { Join-Path $env:USERPROFILE ".android\avd" })
)

$p = Join-Path $AvdHome "$Avd.avd\config.ini"
if (-not (Test-Path $p)) { throw "config.ini nao encontrado: $p" }

$map = @{
  '^PlayStore\.enabled\s*=.*'                     = 'PlayStore.enabled=no'
  '^hw\.audioInput\s*=.*'                         = 'hw.audioInput=no'
  '^hw\.audioOutput\s*=.*'                        = 'hw.audioOutput=no'
  '^hw\.camera\.back\s*=.*'                       = 'hw.camera.back=none'
  '^hw\.gps\s*=.*'                                = 'hw.gps=no'
  '^hw\.gpu\.enabled\s*=.*'                       = 'hw.gpu.enabled=yes'
  '^hw\.gpu\.mode\s*=.*'                          = 'hw.gpu.mode=swiftshader'
  '^hw\.keyboard\s*=.*'                           = 'hw.keyboard=yes'
  '^hw\.sdCard\s*=.*'                             = 'hw.sdCard=no'
  '^hw\.ramSize\s*=.*'                            = 'hw.ramSize=4096'
  '^vm\.heapSize\s*=.*'                           = 'vm.heapSize=512M'
  '^hw\.lcd\.width\s*=.*'                         = 'hw.lcd.width=648'
  '^hw\.lcd\.height\s*=.*'                        = 'hw.lcd.height=1404'
  '^hw\.lcd\.density\s*=.*'                       = 'hw.lcd.density=252'
  '^hw\.lcd\.depth\s*=.*'                         = 'hw.lcd.depth=16'
  '^showDeviceFrame\s*=.*'                        = 'showDeviceFrame=no'
  '^disk\.dataPartition\.size\s*=.*'              = 'disk.dataPartition.size=2147483648'
  '^fastboot\.forceColdBoot\s*=.*'                = 'fastboot.forceColdBoot=yes'
  '^fastboot\.forceFastBoot\s*=.*'                = 'fastboot.forceFastBoot=no'
  '^firstboot\.bootFromDownloadableSnapshot\s*=.*'= 'firstboot.bootFromDownloadableSnapshot=no'
  '^firstboot\.bootFromLocalSnapshot\s*=.*'       = 'firstboot.bootFromLocalSnapshot=no'
  '^firstboot\.saveToLocalSnapshot\s*=.*'         = 'firstboot.saveToLocalSnapshot=no'
  '^hw\.sensors\.light\s*=.*'                     = 'hw.sensors.light=no'
  '^hw\.sensors\.pressure\s*=.*'                  = 'hw.sensors.pressure=no'
  '^hw\.sensors\.humidity\s*=.*'                  = 'hw.sensors.humidity=no'
  '^hw\.sensors\.proximity\s*=.*'                 = 'hw.sensors.proximity=no'
  '^hw\.sensors\.temperature\s*=.*'               = 'hw.sensors.temperature=no'
  '^hw\.sensors\.magnetic_field\s*=.*'            = 'hw.sensors.magnetic_field=no'
  '^hw\.sensors\.magnetic_field_uncalibrated\s*=.*'= 'hw.sensors.magnetic_field_uncalibrated=no'
}

$c = Get-Content $p
foreach ($k in $map.Keys) { $c = $c -replace $k, $map[$k] }
Set-Content $p $c -Encoding ASCII

Select-String -Path $p -Pattern 'lcd\.(width|height|density|depth)|ramSize|ncore|gpu\.|dataPartition\.size|audioInput|audioOutput|camera\.back=|gps=|sdCard|forceColdBoot|showDeviceFrame|heapSize' |
  ForEach-Object { $_.Line }

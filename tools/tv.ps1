param(
  [ValidateSet('connect', 'metrics', 'run', 'shot', 'nav', 'logs', 'install')]
  [string]$Command = 'metrics',
  [string]$Ip,
  [string]$Name = 'tv',
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Keys
)

$ErrorActionPreference = 'Stop'
$adb = 'C:\Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $adb)) { throw "ADB not found at $adb" }

function Get-Target {
  $device = & $adb devices | Select-String '\sdevice$' | Select-Object -First 1
  if (-not $device) { throw 'No authorized ADB device is connected.' }
  return ($device.Line -split '\s+')[0]
}

switch ($Command) {
  'connect' {
    if (-not $Ip) { throw 'Usage: .\tools\tv.ps1 connect -Ip 192.168.x.x:5555' }
    & $adb connect $Ip
  }
  'metrics' {
    $target = Get-Target
    Write-Output "Device: $target"
    & $adb -s $target shell getprop ro.product.manufacturer
    & $adb -s $target shell getprop ro.product.model
    & $adb -s $target shell wm size
    & $adb -s $target shell wm density
    & $adb -s $target shell dumpsys display | Select-String 'mDisplayInfo'
  }
  'run' {
    $target = Get-Target
    flutter run -d $target
  }
  'shot' {
    $target = Get-Target
    New-Item -ItemType Directory -Path screenshots -Force | Out-Null
    & $adb -s $target shell screencap -p "/sdcard/binge-$Name.png"
    & $adb -s $target pull "/sdcard/binge-$Name.png" "screenshots\binge-$Name.png"
  }
  'nav' {
    $target = Get-Target
    foreach ($key in $Keys) { & $adb -s $target shell input keyevent $key }
  }
  'logs' {
    $target = Get-Target
    & $adb -s $target logcat -s flutter:B BingeKeys:D '*:S'
  }
  'install' {
    $target = Get-Target
    flutter build apk --debug
    & $adb -s $target install -r build\app\outputs\flutter-apk\app-debug.apk
    & $adb -s $target shell monkey -p com.binge.app 1
  }
}

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$adbCandidates = @('C:\Android\Sdk\platform-tools\adb.exe')
if ($env:ANDROID_HOME) {
    $adbCandidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
}
if ($env:ANDROID_SDK_ROOT) {
    $adbCandidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
}
if ($env:LOCALAPPDATA) {
    $adbCandidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
}

$adb = $adbCandidates |
    Where-Object { $_ -and (Test-Path $_) } |
    Select-Object -First 1

if (-not $adb) {
    throw 'Android Debug Bridge was not found. Install Android SDK platform-tools or set ANDROID_HOME.'
}

Write-Host 'Checking connected Android devices...'
& $adb start-server | Out-Null
$deviceLines = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S+\s+device$' })
if ($deviceLines.Count -eq 0) {
    throw 'No authorized Android device was found. Connect it with USB debugging enabled and accept the authorization prompt.'
}

Write-Host 'Building the debug APK...'
Push-Location $repoRoot
try {
    & flutter build apk --debug
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter debug APK build failed.'
    }

    $apk = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    if (-not (Test-Path $apk)) {
        throw "Expected APK was not created: $apk"
    }

    Write-Host 'Installing Binge...'
    & $adb install -r $apk
    if ($LASTEXITCODE -ne 0) {
        throw 'APK installation failed.'
    }

    Write-Host 'Launching Binge...'
    & $adb shell monkey -p com.binge.app 1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Binge was installed but could not be launched.'
    }

    Write-Host 'Binge is installed and running.'
}
finally {
    Pop-Location
}

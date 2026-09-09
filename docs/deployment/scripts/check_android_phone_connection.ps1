# Check Android phone connection through ADB.

$adbCandidates = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "C:\Users\ROWEL DUMAGAT\AppData\Local\Android\Sdk\platform-tools\adb.exe"
)

$adbExe = $adbCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($adbExe)) {
    Write-Host "adb.exe was not found under the Android SDK platform-tools folder."
    Write-Host "Install Android SDK Platform Tools from Android Studio SDK Manager."
    exit 1
}

& $adbExe kill-server
& $adbExe start-server
& $adbExe devices

Write-Host ""
Write-Host 'If device shows "unauthorized", accept USB debugging prompt on phone.'
Write-Host "If no device appears, change USB cable/port and set phone USB mode to File Transfer."

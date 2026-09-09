$ErrorActionPreference = "Stop"

$sdkManager = Join-Path $env:LOCALAPPDATA "Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat"

if (Test-Path -LiteralPath $sdkManager) {
    & $sdkManager "platforms;android-36" "build-tools;36.0.0"
    exit $LASTEXITCODE
}

Write-Host "Open Android Studio > SDK Manager > install Android SDK Platform 36 and Build Tools 36.0.0"

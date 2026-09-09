# Run SILVAMANG AI Flutter app on the connected Android phone.
# The phone must have USB Debugging enabled.
# Choose the Android phone if Flutter asks.
# Do not run Chrome or Edge for offline ONNX prediction.

cd C:\laragon\www\SilvaMang-AI\silvamang_mobile

$flutterExe = "C:\flutter\bin\flutter.bat"
$deviceId = "AF2SVB3703003164"

$devicesOutput = & $flutterExe devices
$devicesOutput

if ($devicesOutput -notmatch [regex]::Escape($deviceId)) {
    Write-Host "Phone not detected. Enable USB Debugging, use File Transfer mode, then run flutter devices."
    exit 1
}

& $flutterExe clean
& $flutterExe pub get
& $flutterExe run -d $deviceId

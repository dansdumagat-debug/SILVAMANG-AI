cd C:\laragon\www\SilvaMang-AI\silvamang_mobile

Write-Host "Running Flutter analyze..."
& C:\flutter\bin\flutter.bat analyze

Write-Host "Building debug APK..."
& C:\flutter\bin\flutter.bat build apk --debug

Write-Host "Debug APK should be located at:"
Write-Host "C:\laragon\www\SilvaMang-AI\silvamang_mobile\build\app\outputs\flutter-apk\app-debug.apk"

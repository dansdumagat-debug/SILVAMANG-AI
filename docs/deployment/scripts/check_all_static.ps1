cd C:\laragon\www\SilvaMang-AI

Write-Host "Checking Laravel routes..."
cd C:\laragon\www\SilvaMang-AI\silvamang_api
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan route:list

Write-Host "Checking Python AI service files..."
cd C:\laragon\www\SilvaMang-AI\silvamang_ai_service
python -m compileall app

Write-Host "Checking Flutter analyze..."
cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\dart.bat format lib
& C:\flutter\bin\flutter.bat analyze

Write-Host "Static checks completed."

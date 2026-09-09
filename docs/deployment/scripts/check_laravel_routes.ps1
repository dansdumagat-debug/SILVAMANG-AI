cd C:\laragon\www\SilvaMang-AI\silvamang_api
$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName
& $phpExe artisan route:list

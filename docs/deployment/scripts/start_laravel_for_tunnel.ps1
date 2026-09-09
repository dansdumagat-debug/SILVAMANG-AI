# Use this when exposing Laravel through ngrok/cloudflared.
# Keep this terminal open while testing Flutter on a phone.

Set-Location "C:\laragon\www\SilvaMang-AI\silvamang_api"

$phpExe = (Get-ChildItem C:\laragon\bin\php -Recurse -Filter php.exe | Select-Object -First 1).FullName

& $phpExe artisan config:clear
& $phpExe artisan cache:clear
& $phpExe artisan serve --host=127.0.0.1 --port=8000

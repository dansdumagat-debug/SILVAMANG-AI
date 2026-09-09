$ipAddress = Read-Host "Enter your laptop IPv4 address, example 192.168.1.12"
$envPath = "C:\laragon\www\SilvaMang-AI\silvamang_mobile\.env"
$apiUrl = "http://$ipAddress`:8000/api"

$content = @(
    "API_BASE_URL=$apiUrl"
    "APP_NAME=SILVAMANG AI"
    "APP_TAGLINE=Identify. Measure. Protect."
)

Set-Content -Path $envPath -Value $content

Write-Host "Flutter API URL updated:"
Write-Host $apiUrl
Write-Host "Make sure your phone and laptop are connected to the same Wi-Fi network."

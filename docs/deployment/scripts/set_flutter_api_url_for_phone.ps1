# Set Flutter API_BASE_URL for testing on a physical Android phone.
# Phone and laptop must be on the same Wi-Fi.

$ipv4 = Read-Host "Enter laptop IPv4 address, example 192.168.1.12"
$ipv4 = $ipv4.Trim()

if ([string]::IsNullOrWhiteSpace($ipv4)) {
    Write-Host "No IPv4 address entered. Nothing was changed."
    exit 1
}

$apiUrl = "http://$ipv4`:8000/api"
$envPath = "C:\laragon\www\SilvaMang-AI\silvamang_mobile\.env"

@"
API_BASE_URL=$apiUrl
APP_NAME=SILVAMANG AI
APP_TAGLINE=Identify. Measure. Protect.
"@ | Set-Content -LiteralPath $envPath -Encoding UTF8

Write-Host "Flutter API URL set to $apiUrl"
Write-Host "Phone and laptop must be on the same Wi-Fi."
Write-Host "Do not use 127.0.0.1 for physical phone."
Write-Host "Do not use 10.0.2.2 for physical phone."

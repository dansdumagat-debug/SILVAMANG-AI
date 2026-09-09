# Set Flutter API_BASE_URL to an ngrok HTTPS forwarding URL.
# Example input: https://abc123.ngrok-free.app

$ngrokUrl = Read-Host "Paste ngrok HTTPS forwarding URL, example https://abc123.ngrok-free.app"

if ([string]::IsNullOrWhiteSpace($ngrokUrl)) {
    Write-Host "No ngrok URL entered. Nothing was changed."
    exit 1
}

$ngrokUrl = $ngrokUrl.Trim().TrimEnd("/")

if ($ngrokUrl.EndsWith("/api")) {
    $apiBaseUrl = $ngrokUrl
} else {
    $apiBaseUrl = "$ngrokUrl/api"
}

$envPath = "C:\laragon\www\SilvaMang-AI\silvamang_mobile\.env"

@"
API_BASE_URL=$apiBaseUrl
APP_NAME=SILVAMANG AI
APP_TAGLINE=Identify. Measure. Protect.
"@ | Set-Content -LiteralPath $envPath -Encoding UTF8

Write-Host "Flutter API_BASE_URL updated to: $apiBaseUrl"
Write-Host "Do not use http://127.0.0.1:8000/api on a physical phone."
Write-Host "Use the ngrok URL if phone and laptop are not on the same Wi-Fi."

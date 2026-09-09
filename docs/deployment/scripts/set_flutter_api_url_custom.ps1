# Set a custom public API URL for Flutter cellphone testing.
# Example input: https://abc123.ngrok-free.app/api

$apiBaseUrl = Read-Host "Enter Flutter API base URL, example https://abc123.ngrok-free.app/api"

if ([string]::IsNullOrWhiteSpace($apiBaseUrl)) {
    Write-Host "No API URL entered. Nothing was changed."
    exit 1
}

$apiBaseUrl = $apiBaseUrl.Trim()
$envPath = "C:\laragon\www\SilvaMang-AI\silvamang_mobile\.env"

@"
API_BASE_URL=$apiBaseUrl
APP_NAME=SILVAMANG AI
APP_TAGLINE=Identify. Measure. Protect.
"@ | Set-Content -LiteralPath $envPath -Encoding UTF8

Write-Host "Flutter API_BASE_URL updated successfully."
Write-Host "API_BASE_URL=$apiBaseUrl"
Write-Host "Reminder: use /api at the end of the URL."
Write-Host "Example: https://abc123.ngrok-free.app/api"

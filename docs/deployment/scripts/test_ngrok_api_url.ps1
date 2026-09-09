# Test the public ngrok URL that Flutter will use.

function Normalize-NgrokApiUrl {
    param ([string] $Url)

    $cleanUrl = $Url.Trim().TrimEnd("/")
    if ($cleanUrl.EndsWith("/api")) {
        return $cleanUrl
    }

    return "$cleanUrl/api"
}

function Test-Endpoint {
    param (
        [string] $Label,
        [string] $Url
    )

    try {
        $statusCode = & curl.exe -s -o NUL -w "%{http_code}" $Url
        $ok = $statusCode -match "^[23][0-9][0-9]$"
    } catch {
        $statusCode = "ERROR"
        $ok = $false
    }

    $result = if ($ok) { "YES" } else { "NO" }
    Write-Host "${Label}: $result ($statusCode)"
    return $ok
}

$ngrokUrl = Read-Host "Paste ngrok HTTPS forwarding URL, example https://abc123.ngrok-free.app"

if ([string]::IsNullOrWhiteSpace($ngrokUrl)) {
    Write-Host "No ngrok URL entered. Cannot test."
    exit 1
}

$apiBaseUrl = Normalize-NgrokApiUrl $ngrokUrl
Write-Host "Testing API URL: $apiBaseUrl"

$apiOk = Test-Endpoint "ngrok Laravel API reachable" "$apiBaseUrl/health"
$aiOk = Test-Endpoint "ngrok AI service health reachable" "$apiBaseUrl/ai/service-health"

if (-not ($apiOk -and $aiOk)) {
    Write-Host ""
    Write-Host "If the test fails:"
    Write-Host "- Check Laravel is running on 127.0.0.1:8000"
    Write-Host "- Check ngrok is running: ngrok http 8000"
    Write-Host "- Check ngrok URL is correct"
    Write-Host "- Check Laravel APP_URL/CORS if browser/app is blocked"
}

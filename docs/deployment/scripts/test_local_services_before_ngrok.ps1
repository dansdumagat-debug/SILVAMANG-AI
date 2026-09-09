# Test local services before exposing Laravel through ngrok.

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
}

Test-Endpoint "Laravel API reachable" "http://127.0.0.1:8000/api/health"
Test-Endpoint "Laravel AI health reachable" "http://127.0.0.1:8000/api/ai/service-health"
Test-Endpoint "Python AI reachable" "http://127.0.0.1:9000/health"

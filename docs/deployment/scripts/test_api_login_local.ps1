$ErrorActionPreference = "Stop"

$loginUrl = "http://127.0.0.1:8000/api/login"
$credentials = @(
    @{ Email = "user@silvamang.test"; Password = "password" },
    @{ Email = "admin@silvamang.test"; Password = "password" }
)

foreach ($credential in $credentials) {
    Write-Host "Testing login for $($credential.Email)..."

    try {
        $body = @{
            email = $credential.Email
            password = $credential.Password
        } | ConvertTo-Json

        $response = Invoke-RestMethod `
            -Uri $loginUrl `
            -Method Post `
            -ContentType "application/json" `
            -Headers @{ Accept = "application/json" } `
            -Body $body

        $token = $response.data.token
        if ($token) {
            Write-Host "Login succeeded for $($credential.Email)."
            Write-Host "Token received: YES"
            exit 0
        }

        Write-Host "Login response did not include a token."
    } catch {
        $message = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($errorResponse.message) {
                    $message = $errorResponse.message
                }
            } catch {
                $message = $_.ErrorDetails.Message
            }
        }

        Write-Host "Login failed for $($credential.Email): $message"
    }
}

Write-Host "No local demo login succeeded."
exit 1

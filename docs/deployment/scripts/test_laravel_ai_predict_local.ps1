$ErrorActionPreference = "Stop"

$projectRoot = "C:\laragon\www\SilvaMang-AI"
$loginUrl = "http://127.0.0.1:8000/api/login"
$predictUrl = "http://127.0.0.1:8000/api/ai/predict"
$imageExtensions = @(".jpg", ".jpeg", ".png", ".webp")
$plantPartNames = @("leaves", "bark", "roots", "flowers", "canopy", "full_tree", "other")
$candidateFolders = @(
    "dataset\raw\Rhizophora_stylosa",
    "dataset\raw\Avicennia_marina",
    "dataset\raw\Excoecaria_agallocha"
)

function Get-LocalToken {
    $credentials = @(
        @{ Email = "user@silvamang.test"; Password = "password" },
        @{ Email = "admin@silvamang.test"; Password = "password" }
    )

    foreach ($credential in $credentials) {
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

            if ($response.data.token) {
                Write-Host "Login succeeded for $($credential.Email)."
                Write-Host "Token received: YES"
                return $response.data.token
            }
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

    return $null
}

function Get-FirstDatasetImage {
    foreach ($folder in $candidateFolders) {
        $path = Join-Path $projectRoot $folder
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $image = Get-ChildItem -LiteralPath $path -Recurse -File |
            Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() } |
            Select-Object -First 1

        if ($image) {
            return $image
        }
    }

    return $null
}

function Get-PlantPartFromPath {
    param(
        [Parameter(Mandatory = $true)]$Image
    )

    $directory = $Image.Directory
    while ($directory -ne $null) {
        $name = $directory.Name.ToLowerInvariant()
        if ($plantPartNames -contains $name) {
            return $name
        }

        $directory = $directory.Parent
    }

    return "leaves"
}

function Get-MimeType {
    param(
        [Parameter(Mandatory = $true)][string]$Extension
    )

    switch ($Extension.ToLowerInvariant()) {
        ".png" { return "image/png" }
        ".webp" { return "image/webp" }
        default { return "image/jpeg" }
    }
}

$token = Get-LocalToken
if (-not $token) {
    Write-Host "Unable to get an API token. Run fix_laravel_mysql_local.ps1, start Laravel, then retry."
    exit 1
}

$image = Get-FirstDatasetImage
if (-not $image) {
    Write-Host "No test image found in the configured dataset folders."
    exit 1
}

if (-not (Test-Path -LiteralPath $image.FullName)) {
    Write-Host "Selected image path is not valid: $($image.FullName)"
    exit 1
}

$plantPart = Get-PlantPartFromPath -Image $image
$mimeType = Get-MimeType -Extension $image.Extension

Write-Host "Using image: $($image.FullName)"
Write-Host "Using plant part: $plantPart"

$curlArgs = @(
    "-s",
    "-X", "POST", $predictUrl,
    "-H", "Accept: application/json",
    "-H", "Authorization: Bearer $token",
    "-F", "images[]=@$($image.FullName);type=$mimeType",
    "-F", "plant_parts[]=$plantPart"
)

$rawResponse = & curl.exe @curlArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "curl failed while calling Laravel AI prediction."
    exit 1
}

try {
    $response = $rawResponse | ConvertFrom-Json
} catch {
    Write-Host "Laravel returned a non-JSON response:"
    Write-Host $rawResponse
    exit 1
}

if ($response.message -and -not $response.data) {
    Write-Host "Laravel response message: $($response.message)"
    exit 1
}

$data = $response.data
Write-Host "response mode: $($data.mode)"
Write-Host "response source: $($data.source)"
Write-Host "received.image_count: $($data.received.image_count)"
Write-Host "top_prediction.scientific_name: $($data.top_prediction.scientific_name)"

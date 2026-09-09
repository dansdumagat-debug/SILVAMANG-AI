$ErrorActionPreference = "Stop"

$projectRoot = "C:\laragon\www\SilvaMang-AI"
$rawRoot = Join-Path $projectRoot "dataset\raw"
$imageExtensions = @(".jpg", ".jpeg", ".png", ".webp")

$canonicalClasses = @(
    "Avicennia_marina",
    "Avicennia_marina_var_rumphiana",
    "Bruguiera_gymnorrhiza",
    "Ceriops_tagal",
    "Excoecaria_agallocha",
    "Rhizophora_apiculata",
    "Rhizophora_mucronata",
    "Rhizophora_stylosa",
    "Sonneratia_alba",
    "Xylocarpus_granatum"
)

$folderMappings = @(
    @{ Old = "Rhizophora_Stylosa"; New = "Rhizophora_stylosa" },
    @{ Old = "Excocaria_Galoca"; New = "Excoecaria_agallocha" },
    @{ Old = "Avicennia_ Rhumphiana"; New = "Avicennia_marina_var_rumphiana" },
    @{ Old = "Sonneratia Alba"; New = "Sonneratia_alba" }
)

function Get-SafeDestinationPath {
    param(
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        return $DestinationPath
    }

    $directory = Split-Path -Parent $DestinationPath
    $name = [System.IO.Path]::GetFileNameWithoutExtension($DestinationPath)
    $extension = [System.IO.Path]::GetExtension($DestinationPath)
    $counter = 1

    do {
        $candidate = Join-Path $directory ("{0}_copy{1}{2}" -f $name, $counter, $extension)
        $counter++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

New-Item -ItemType Directory -Force -Path $rawRoot | Out-Null

foreach ($classLabel in $canonicalClasses) {
    New-Item -ItemType Directory -Force -Path (Join-Path $rawRoot $classLabel) | Out-Null
}

foreach ($mapping in $folderMappings) {
    $oldPath = Join-Path $rawRoot $mapping.Old
    $newPath = Join-Path $rawRoot $mapping.New

    if (-not (Test-Path -LiteralPath $oldPath)) {
        Write-Host "Old folder not found, skipping: $oldPath"
        continue
    }

    Write-Host "Copying images from $($mapping.Old) to $($mapping.New)..."
    $sourceFiles = Get-ChildItem -LiteralPath $oldPath -Recurse -File |
        Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() }

    foreach ($file in $sourceFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($oldPath, $file.FullName)
        $destinationPath = Join-Path $newPath $relativePath
        $destinationDirectory = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null

        $safeDestinationPath = Get-SafeDestinationPath -DestinationPath $destinationPath
        Copy-Item -LiteralPath $file.FullName -Destination $safeDestinationPath
    }
}

Write-Host ""
Write-Host "Final canonical class image counts:"
foreach ($classLabel in $canonicalClasses) {
    $classPath = Join-Path $rawRoot $classLabel
    $count = 0
    if (Test-Path -LiteralPath $classPath) {
        $count = @(Get-ChildItem -LiteralPath $classPath -Recurse -File |
            Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() }).Count
    }

    if ($count -eq 0) {
        Write-Host "$classLabel : $count image(s) WARNING: empty class"
    } else {
        Write-Host "$classLabel : $count image(s)"
    }
}

Write-Host ""
Write-Host "Dataset canonicalization completed. Old folders were not deleted."

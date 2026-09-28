[CmdletBinding()]
param(
    [string] $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
)

$classificationRoot = Join-Path $ProjectRoot 'dataset\processed\cnn_classification'

foreach ($split in @('train', 'val', 'test')) {
    $unknownFolder = Join-Path $classificationRoot "$split\unknown"
    New-Item -ItemType Directory -Path $unknownFolder -Force | Out-Null

    $placeholder = Join-Path $unknownFolder '.gitkeep'
    if (-not (Test-Path -LiteralPath $placeholder)) {
        [System.IO.File]::WriteAllText($placeholder, "`n")
    }

    Write-Output "Prepared $unknownFolder"
}

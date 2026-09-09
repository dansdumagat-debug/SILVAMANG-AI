# Allow physical phones on the same Wi-Fi to reach Laravel on port 8000.
# Run this script in PowerShell as Administrator only if the phone browser
# cannot open http://<your-laptop-ip>:8000/api/health.

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host "Please run PowerShell as Administrator, then run this script again."
    exit 1
}

$ruleName = "SILVAMANG AI Laravel Port 8000"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Firewall rule already exists: $ruleName"
    exit 0
}

New-NetFirewallRule `
    -DisplayName $ruleName `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8000 `
    -Action Allow `
    -Profile Private

Write-Host "Firewall port 8000 opened for SILVAMANG AI Laravel local demo."

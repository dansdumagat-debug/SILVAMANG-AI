# Show the Laravel API URLs to test from the cellphone browser.

$ipv4 = Read-Host "Enter laptop IPv4 address, example 192.168.1.12"
$ipv4 = $ipv4.Trim()

if ([string]::IsNullOrWhiteSpace($ipv4)) {
    Write-Host "No IPv4 address entered."
    exit 1
}

Write-Host ""
Write-Host "Open these URLs on the cellphone browser:"
Write-Host "http://$ipv4`:8000/api/health"
Write-Host "http://$ipv4`:8000/api/ai/service-health"
Write-Host ""
Write-Host "Expected:"
Write-Host "/api/health should return Laravel API status."
Write-Host "/api/ai/service-health should show Python AI service availability."

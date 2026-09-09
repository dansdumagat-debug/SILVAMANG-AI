$root = "C:\laragon\www\SilvaMang-AI"
$pythonScript = Join-Path $root "docs\deployment\scripts\start_python_ai_service.ps1"
$laravelScript = Join-Path $root "docs\deployment\scripts\start_laravel_backend.ps1"

Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $pythonScript
Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $laravelScript

Write-Host "Python AI service and Laravel backend windows opened."
Write-Host "Now run:"
Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\deployment\scripts\run_flutter_phone.ps1"

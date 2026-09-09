cd C:\laragon\www\SilvaMang-AI\silvamang_ai_service
python -m compileall app
Write-Host "Start manually:"
Write-Host "python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload"

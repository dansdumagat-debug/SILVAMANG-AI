# Laravel connects to Python locally through AI_SERVICE_URL=http://127.0.0.1:9000.
# Keep this terminal open while testing predictions.

Set-Location "C:\laragon\www\SilvaMang-AI\silvamang_ai_service"
python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload

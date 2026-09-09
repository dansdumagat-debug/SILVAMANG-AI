# Keep this terminal open.
# Laravel will call this service locally.
# Do not expose Python directly through ngrok.

Set-Location "C:\laragon\www\SilvaMang-AI\silvamang_ai_service"
python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload

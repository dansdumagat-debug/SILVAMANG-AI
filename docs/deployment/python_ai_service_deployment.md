# Python AI Service Deployment Guide

## 1. Purpose

The Python FastAPI service provides AI inference endpoints for SILVAMANG AI.

## 2. Current AI Capabilities

- Health endpoint
- CNN baseline prediction when model and dependencies are available
- Mock fallback prediction
- Prototype measurement endpoint

## 3. Environment Setup

```powershell
cd silvamang_ai_service
python -m venv .venv
```

## 4. Dependencies

```powershell
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe -m pip install -r requirements-cnn.txt
```

## 5. Run Service Locally

```powershell
.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload
```

## 6. Health Check

```text
http://127.0.0.1:9000/health
```

Swagger docs:

```text
http://127.0.0.1:9000/docs
```

## 7. CNN Model Path

```text
silvamang_ai_service/models/cnn_classifier/baseline_cnn.pth
```

## 8. Laravel AI Service Configuration

In Laravel `.env`:

```env
AI_SERVICE_URL=http://127.0.0.1:9000
AI_SERVICE_TIMEOUT=30
AI_SERVICE_MODE=cnn
```

## 9. Production Notes

- Use a production ASGI server setup appropriate for the host.
- Keep models outside public web directories.
- Protect service endpoints if exposed outside the private network.
- Monitor memory and CPU usage during inference.

## 10. Limitations

- YOLOv8 pending annotation/training.
- MiDaS/depth estimation is not fully integrated.
- Measurement endpoint is prototype/mock.

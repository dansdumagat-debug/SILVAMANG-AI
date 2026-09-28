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

## 6. Health Checks

```text
http://127.0.0.1:9000/health
```

`/health` only confirms that the FastAPI process is running. Verify the loaded CNN release at:

```text
http://127.0.0.1:9000/ai/health
```

Confirm `models.cnn` and `readiness.cnn.available` are `true`, both image-size fields are 224,
and the class count, exact class order, and artifact hashes match the promotion receipt. The
overall service may report `partial` when unrelated optional models are absent.

Swagger docs:

```text
http://127.0.0.1:9000/docs
```

## 7. CNN Model Path

```text
silvamang_ai_service/models/cnn_classifier/efficientnet_b0_best.pth
silvamang_ai_service/models/cnn_classifier/class_order.json
```

Deploy these as one evaluated pair. The service caches them after first load, so stop or drain
the service before promotion and restart it afterward. A file copy without restart keeps the
old in-memory model.

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

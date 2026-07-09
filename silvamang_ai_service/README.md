# SILVAMANG AI Service

## Phase 14A - Python AI Service Initialization

This service is the future AI inference layer for SILVAMANG AI.

Current mode:
- Mock only

Implemented endpoints:
- GET /
- GET /health
- POST /predict
- POST /measure

Future AI modules:
- CNN species classification
- YOLOv8 plant-part detection
- YOLOv8-Seg segmentation
- MiDaS depth estimation

## Setup

python -m venv .venv

Windows:
.venv\Scripts\activate

Install:
pip install -r requirements.txt

Run manually:
uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload

Health check:
http://127.0.0.1:9000/health

Important:
Do not run uvicorn as a blocking command inside Codex.

## Next Phase

Phase 14B will connect Laravel to this Python AI service.


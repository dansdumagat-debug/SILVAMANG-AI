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

For full AI model support, the base requirements now include the CNN and YOLO runtime dependencies:

```bash
pip install -r requirements.txt
```

Optional MiDaS/depth runtime:

```bash
pip install -r requirements-midas.txt
```

Run manually:
uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload

Health check:
http://127.0.0.1:9000/health

Full model readiness check:

```bash
python scripts/check_ai_model_readiness.py
```

AI health endpoint:

```text
http://127.0.0.1:9000/ai/health
```

Required model files:

```text
models/cnn_classifier/efficientnet_b0_best.pth
models/cnn_classifier/class_order.json
models/yolo_detector/best.pt
models/yolo_segmenter/best.pt
models/midas/midas_torchscript.pt
```

Only the CNN model is currently present in the repository. YOLOv8 detector, YOLOv8 segmentation, and MiDaS require real trained model files before their endpoints can return real AI output.

Important:
Do not run uvicorn as a blocking command inside Codex.

## Next Phase

Phase 14B will connect Laravel to this Python AI service.

## Phase 16C - CNN Baseline Connected to Python AI Service

Implemented:
- CNN baseline inference service
- baseline_cnn.pth model loading
- image preprocessing
- top-k prediction output
- /predict endpoint now uses CNN when image and model are available
- mock fallback when CNN is unavailable
- /health reports CNN availability

Model path:
silvamang_ai_service/models/cnn_classifier/baseline_cnn.pth

Manual test:
Start the service:

```bash
python -m uvicorn app.main:app --host 127.0.0.1 --port 9000 --reload
```

Health:
http://127.0.0.1:9000/health

Prediction:
Use /docs and test POST /predict with an uploaded image.

Important:
If CNN dependencies are missing, install:

```bash
pip install -r silvamang_ai_service/requirements-cnn.txt
```

Next phase:
Phase 17 will prepare YOLOv8 plant-part detection and annotation workflow.

## Licensed candidate image collection

Audit image-bearing GBIF occurrences without downloading files:

```powershell
python scripts/collect_gbif_candidates.py --mode audit --all-new
```

Download a resumable species-level candidate pool for one species:

```powershell
python scripts/collect_gbif_candidates.py --mode download --species "Acanthus ebracteatus" --target 200
```

Candidates are stored under `../dataset/candidates/<species>/unclassified/` and recorded in
`../dataset/metadata/candidate_image_manifest.csv`. The downloader accepts only CC0, public-domain,
CC BY, and CC BY-SA media and excludes NC/ND licenses. Every candidate must still be reviewed for
the correct species and assigned to `leaves`, `bark`, `roots`, or `flowers` before it enters
`dataset/raw`. Do not use candidate files directly for training.

Review candidates locally in a browser without editing the CSV by hand:

```powershell
python scripts/review_gbif_candidates.py
```

Then open `http://127.0.0.1:8765`. Use the suggested-part filter to review leaves, flowers, roots,
or bark separately. Approving a candidate records its reviewed plant part in the candidate
manifest. It does not move the image into `dataset/raw` or make it training-ready by itself.

Search Wikimedia Commons for additional open-license candidates suggested by plant-part metadata:

```powershell
python scripts/collect_commons_part_candidates.py --mode download --all-new `
  --part leaves --part flowers --part roots --part bark --target-per-part 10
```

These search suggestions still require species and plant-part review. A matching search term is not
a verified image label.

## Phase 17A - YOLOv8 Detection and Segmentation Preparation

Created:
- YOLO detector training folder
- YOLO detection data.yaml
- YOLO segmentation data.yaml
- YOLO requirements file
- Dataset validation script
- Detection training script
- Segmentation training script
- Evaluation script
- Prediction script
- YOLO documentation

Current status:
- YOLO preparation only
- No YOLO model trained yet
- No YOLO integration into FastAPI yet

Next phase:
Phase 17B will train YOLOv8 detection after bounding-box annotations are completed.

## Phase 18A - Depth Estimation and Measurement Preparation

Implemented:
- Improved /measure mock response
- Measurement schema refinement
- Prototype height and canopy estimate response
- Future MiDaS integration path
- Measurement status in /health

Current status:
- Measurement is mock/prototype only
- Real MiDaS depth estimation is not yet integrated

Next phase:
Phase 18B will connect measurement results into the mobile workflow or prepare real MiDaS integration.

## Phase 19A - End-to-End CNN Prediction Workflow Finalization

Python `/predict` is now used as the CNN baseline prediction service when `baseline_cnn.pth` is available.

## Deployment Documentation

Deployment and demo preparation guides are available in:

```text
../docs/deployment/
```

Useful AI service documents:
- Python AI service deployment guide
- Environment variables guide
- Known limitations document
- Pre-defense checklist

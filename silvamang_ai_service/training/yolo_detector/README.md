# YOLOv8 Plant-Part Detection and Segmentation

Purpose:
Prepare YOLOv8 detection and YOLOv8-Seg segmentation for SILVAMANG AI.

Current phase:
Preparation only.

Classes:
- leaves
- bark
- roots
- flowers
- canopy
- full_tree

Workflow:
1. Collect verified images
2. Annotate plant parts with bounding boxes
3. Review annotations
4. Prepare YOLO dataset
5. Train YOLOv8 detection
6. Evaluate model
7. Test prediction
8. Later integrate model into FastAPI

Commands:

Validate YOLO dataset:

```bash
python silvamang_ai_service/training/yolo_detector/validate_yolo_dataset.py
```

Prepare YOLO dataset:

```bash
python silvamang_ai_service/training/yolo_detector/prepare_yolo_dataset.py
```

Prepare a weak starter dataset from existing plant-part folders:

```bash
python silvamang_ai_service/training/yolo_detector/prepare_yolo_dataset.py --weak-from-raw
```

This creates full-image boxes from folders such as `roots`, `bark`, `leaves`, and `canopy`. It is useful to unblock prototype training, but production detector accuracy still requires hand-reviewed bounding boxes.

Install YOLO dependencies:

```bash
pip install -r silvamang_ai_service/requirements-yolo.txt
```

Train detection:

```bash
python silvamang_ai_service/training/yolo_detector/train_yolo_detection.py --epochs 50
```

Train segmentation:

```bash
python silvamang_ai_service/training/yolo_detector/train_yolo_segmentation.py --epochs 50
```

Evaluate:

```bash
python silvamang_ai_service/training/yolo_detector/evaluate_yolo_detection.py
```

Predict:

```bash
python silvamang_ai_service/training/yolo_detector/predict_yolo_detection.py --image path/to/image.jpg
```

Important:
Do not report YOLO metrics until real annotated validation data is available.

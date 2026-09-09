# SILVAMANG AI System Completion Roadmap

This roadmap tracks the controlled phase-by-phase completion process. Codex
should complete only one phase per run, update this checklist, then stop.

## Checklist

- [x] Phase 1 - Stabilize Flutter Android Build
- [ ] Phase 2 - Verify Online CNN Identification
- [ ] Phase 3 - Fix Offline ONNX Identification
- [ ] Phase 4 - GPS Scan Location And Barangay Recording
- [ ] Phase 5 - Field Distance Meter
- [ ] Phase 6 - Height And Canopy Measurement Prototype
- [ ] Phase 7 - Honest AI Model Status In Admin
- [ ] Phase 8 - Functional AI Assistant Logs
- [ ] Phase 9 - User-Specific History, Edit, Delete
- [ ] Phase 10 - YOLOv8 Detector
- [ ] Phase 11 - YOLOv8-Seg Segmenter
- [ ] Phase 12 - MiDaS Depth Estimator

## Phase 1 Notes

Status: Complete

Confirmed Android build stabilization configuration:

- Flutter app `compileSdk` is set to `36`.
- Root Gradle config forces Android application/library subprojects to
  `compileSdk 36`.
- Flutter uses the local patched `third_party/onnxruntime` package.
- Local ONNX Runtime Android module uses `compileSdkVersion 36`.
- Analyzer excludes the local ONNX Runtime plugin example and test folders.
- Offline ONNX documentation states Android/native-only support and warns not
  to use Chrome/web for offline ONNX testing.

Manual verification is still required by the developer on the local machine.

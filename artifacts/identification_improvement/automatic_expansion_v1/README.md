# Automatically screened training expansion

60 candidates were screened against the original 5,918-image dataset, including evaluation images. 48 photos from 15 observations were added to the corrected training set. Nine photos were excluded because the observation already appeared in the existing dataset (including source links shared across providers). Three were excluded as possible visual duplicates using a 64-bit difference hash distance of six or less. No existing files, labels, or split assignments were edited.

The combined manifest contains 4,040 training, 866 validation, and 879 test images. Validation and test records were checked against the corrected EfficientNet reference run and remain unchanged. Original image files are read in place; `saved_path` is relative to the repository root. `baseline_manifest.csv` preserves the corrected baseline records with these resolved relative paths.

The added species labels come from recorded iNaturalist research-grade metadata. They are **not expert-verified**. Plant parts were not automatically assigned. Automated readability, minimum dimension, file integrity, license, observation overlap, exact pixel and visual similarity checks cannot prove botanical identity or exhaustive source independence. Existing manual rejection/flag decisions were respected. The global review manifest remains unchanged; `screening.csv` records the separate automated decisions.

## Training

A fresh ImageNet-initialized EfficientNet-B0 experiment is launched with:

```powershell
python colab/train_corrected_classifier.py --dataset-bundle artifacts/identification_improvement/automatic_expansion_v1 --compare-run artifacts/classifier_corrected/20260928T124128799011Z
```

The run uses the existing 25-epoch schedule, validation-based early stopping, and best-checkpoint selection. Outputs are in `artifacts/classifier_expanded/<run timestamp>/`. This does not deploy a model or evaluate the test split. Compare validation against the reference (71.25% accuracy, 67.26% macro F1); improvement is not guaranteed.

`training_process.json` identifies the launch, not completion. Check `training.stdout.log`, `training.stderr.log`, and the run's `status.json` for progress. Keep the computer awake while training. To resume an interrupted run, use the same command with `--resume artifacts/classifier_expanded/<run timestamp>`; do not start duplicate runs.

To check the dataset without training, append `--validate-only`.

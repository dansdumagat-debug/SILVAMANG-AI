# Identification improvement experiments

No candidate improved both validation accuracy and macro F1. No model was deployed or substituted in the mobile app. Existing checkpoints and dataset labels remain intact.

Reference: corrected EfficientNet-B0 epoch 20, checkpoint SHA-256 `d2ead19e55051bc96b336f718ecfaa8889ca16f933f22791e34eb87890f79c9c`. All comparisons use the same 866 validation images. The baseline was reproduced before comparing candidates. The test split was not evaluated.

| Experiment | Validation accuracy | Macro F1 |
|---|---:|---:|
| Reference center crop | 71.25% | 67.26% |
| Center crop + horizontal flip probability average | 70.55% | 66.18% |
| Center crop + full-image probability average | 71.13% | 67.65% |
| Balanced classifier head, C=0.01 | 69.40% | 65.76% |
| Balanced classifier head, C=0.1 | 69.98% | 66.21% |
| Balanced classifier head, C=1 | 69.98% | 66.47% |
| Equal blend of original and C=0.01 head weights | 70.44% | 66.83% |

The three alternative heads were fitted on 3,992 training images using frozen features from the corrected model. Validation images were used only for evaluation and candidate selection. The image-averaging alternatives and head settings were fixed before their respective evaluations. These are development comparisons, not independent final test results.

The full-image average had higher macro F1 and higher accuracy among accepted predictions, but accepted fewer images and lost one correct top-1 prediction overall. This is a tradeoff, not an established overall improvement. Selection required both accuracy and macro F1 to increase, without increasing false acceptance of the 25 validation images labeled unknown at the unchanged 70% threshold. That small unknown sample does not establish real-world rejection reliability.

## Next data work

`species_priorities.csv` lists per-species validation performance and training group counts. `training_photo_review.csv` contains up to 12 distinct training groups per species with validation F1 below 0.60. Every queued image is from the training split. An informed reviewer should verify species labels, plant-part visibility, and whether distinct groups still contain closely related images. A low model score alone is not evidence that a label is incorrect. No labels were changed.

Priorities include Ceriops zippeliana, Avicennia officinalis, Rhizophora mucronata, and Avicennia alba. Camptostemon philippinensis has only four validation examples, so its estimate is particularly uncertain. Obtain independently sourced, verified photos for the weaker species. Keep new final evaluation photos separate from training and development; the original test set has already informed earlier development.

## Reproduction

Run from the repository root with the existing Python training dependencies. Output directories must not already exist:

```sh
python colab/evaluate_identification_candidates.py --run artifacts/classifier_corrected/20260928T124128799011Z --output artifacts/identification_improvement/validation_inference_v1
python colab/refit_identification_head.py --run artifacts/classifier_corrected/20260928T124128799011Z --output artifacts/identification_improvement/regularized_head_v1
python colab/blend_identification_head.py
```

The blend script reads the preceding head experiment's cached validation features and C=0.01 parameters. A checkpoint would be written only if the selection requirements passed; none did in this experiment. The raw comparison JSON files, per-class reports, and prediction CSV files preserve the measured results.

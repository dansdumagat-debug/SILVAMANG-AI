# Staged 29-Class CNN Dataset

This workflow prepares a reviewed dataset for 28 mangrove species plus `unknown`. It is isolated from the active 10-class dataset, model checkpoint, and runtime class mapping.

## Manually sorted candidate folders

When the images have already been manually placed under the correct species and plant-part folders in `dataset/candidates`, those folders are treated as the bulk manual labels. You do not need to review each image in the browser.

From the project root, preview the generated manifest and current readiness gaps without writing anything:

```powershell
cd C:\laragon\www\SilvaMang-AI

python silvamang_ai_service/scripts/import_candidate_folders.py
```

After checking the report, write the generated manifest:

```powershell
python silvamang_ai_service/scripts/import_candidate_folders.py --apply
```

This leaves the original images and existing manifests untouched. It preserves usable source metadata, excludes exact hashes found under different species, and keeps previously flagged or rejected rows excluded from training.

Run the staging readiness check against the generated manifest:

```powershell
python silvamang_ai_service/training/cnn_classifier/build_staged_29_dataset.py `
  --manifest dataset/metadata/cnn_29_folder_approved_manifest.csv
```

Both commands print the remaining class and split coverage gaps. Create a staging copy only after the readiness check reports that the dataset is ready.

The canonical class order and safety policy are in:

```text
silvamang_ai_service/training/cnn_classifier/staged_29_class_config.json
```

`unknown` is the final class at index 28. The other 28 class names are alphabetically ordered so the saved order agrees with `torchvision.datasets.ImageFolder`.

## Collect reviewed `unknown` candidates

Use the Commons collector for a licensed, human-reviewed negative pool. Its
default mode audits search results without writing files:

```powershell
python silvamang_ai_service/scripts/collect_unknown_commons_candidates.py `
  --max-search-results 100
```

Download results into an isolated review queue, inspect the generated contact
sheets and full-size files, then move every rejected file out of
`dataset/incoming/unknown`:

```powershell
python silvamang_ai_service/scripts/collect_unknown_commons_candidates.py `
  --download --target-per-category 10 --max-search-results 200
```

Only an explicit promotion adds approved rows to the candidate manifest:

```powershell
python silvamang_ai_service/scripts/collect_unknown_commons_candidates.py `
  --promote --blur-variants 10 --dark-variants 10
```

Promoted files are stored under
`dataset/candidates/unknown/unclassified/<category>/`. Optional poor-capture
variants retain their base image's source record and license, so the staging
builder keeps each base and its variants in one split. Exact hashes are checked
against the queue, both manifests, and the candidate and raw trees.

Never collect nipa as an unknown negative: *Nypa fruticans* is the positive
`Nypa_fruticans` class at index 17. Full category, review, provenance, and safe
repeat instructions are in `docs/ai/unknown_class_dataset.md`.

## Input rules

The builder reads manifest rows, not arbitrary files found in a directory. A row is eligible only when all of these conditions are met:

- `review_status` or `approval_status` is exactly `approved`.
- `file_path` resolves inside `dataset/candidates` or `dataset/raw`.
- The class is one of the configured 29 canonical classes.
- `source` and `source_record_id`, `source_group_id`, or `observation_id` are present.
- `license` or `permission_status` is present.
- `sha256` is present, valid, and matches the current file bytes.
- Approved candidate rows for the 28 mangrove species also have a reviewed plant part. `unknown` examples are exempt because they may contain no plant.

Pending, flagged, and rejected rows are ignored. Invalid approved rows are blocking errors. Files that have no manifest row are never included.

The existing candidate manifest can be used after its approved paths and hashes have been reconciled. The current raw image manifest does not yet contain explicit approval, source-group, and SHA-256 fields, so its rows remain ineligible until those fields are recorded. A separate curated CSV with the supported columns can be passed with `--manifest` instead of changing historical metadata.

## Readiness check

The default command is read only:

```powershell
cd C:\laragon\www\SilvaMang-AI

python silvamang_ai_service/training/cnn_classifier/build_staged_29_dataset.py
```

It calculates hashes, deduplicates eligible rows, builds source groups, and prints the proposed class and split counts. It exits with status 2 when any approved row is invalid, a class is missing, or a class has fewer than the configured minimums.

To audit a separate curated manifest:

```powershell
python silvamang_ai_service/training/cnn_classifier/build_staged_29_dataset.py `
  --manifest dataset/metadata/cnn_29_approved_manifest.csv
```

Supplying one or more `--manifest` arguments replaces the configured default manifest list.

## Deduplication and grouping

The builder calculates SHA-256 from every eligible source file. It writes one staged image for each unique hash.

Rows are joined into the same indivisible group when they share either:

- an exact SHA-256 hash, or
- a normalized source plus source-record identifier, or the same normalized source-record URL.

The grouping is transitive. For example, if a duplicate connects records A and B, every image from both records stays in one split. An exact image or source record carrying conflicting class labels blocks the build.

Splits are deterministic for the configured seed. The builder aims for 70% train, 20% validation, and 10% test while preserving whole groups. Each class must have enough independent groups to appear in all three splits.

## Create a versioned staging copy

After readiness passes, explicitly apply a named version:

```powershell
python silvamang_ai_service/training/cnn_classifier/build_staged_29_dataset.py `
  --apply `
  --version 2026-09-24-v1
```

The output is created under:

```text
dataset/staging/cnn_classification_29/2026-09-24-v1/
```

Every version contains:

```text
train/<class>/<sha256>.<extension>
val/<class>/<sha256>.<extension>
test/<class>/<sha256>.<extension>
class_order.json
config_snapshot.json
dataset_manifest.csv
build_report.json
input_manifests/<versioned manifest snapshots>
BUILD_COMPLETE.json
```

The builder copies files and never moves or deletes source data. It refuses to write into an existing version directory. Source files and copied files are checked against the planned SHA-256 values. Input manifests are copied into the version and recorded with their SHA-256 values; `dataset_manifest.csv` retains the approval status, entry ID, source row, and the lineage of every exact duplicate folded into a staged image.

A `BUILD_INCOMPLETE` marker is created before copying and removed only after `BUILD_COMPLETE.json` is written. Use a version only when the completion file exists and the incomplete marker is absent.

### Immutable builder contract

Training requires the complete builder bundle. `BUILD_COMPLETE.json` records SHA-256 hashes
for `class_order.json`, `config_snapshot.json`, `dataset_manifest.csv`, and
`build_report.json`. The same input-manifest evidence list appears in the config snapshot,
build report, and completion marker; every referenced snapshot is hash-verified.

`dataset_manifest.csv` uses this exact ordered schema:

```text
staged_path, split, class_name, sha256, group_id, source_record_keys,
entry_id, approval_status, source_file, source_manifest,
source_manifest_sha256, source_manifest_snapshot, source_manifest_row,
source, source_record_id, source_record_url, source_image_url,
rights_or_license, reviewed_plant_part, lineage_json
```

The trainer checks that every staged image is represented exactly once, is approved, retains
rights and source lineage, matches its content hash and input snapshot row, and that no content
hash or source group crosses train, validation, and test. It rejects extra files, path
traversal, symlinks, junctions, reparse points, and any artifact mutation. Dataset images use
the builder-supported `.jpg`, `.jpeg`, `.png`, or `.webp` suffixes; legacy ImageFolder inputs
are limited to torchvision's `.jpg`, `.jpeg`, `.png`, `.ppm`, `.bmp`, `.pgm`, `.tif`, `.tiff`,
and `.webp` suffix set.

Treat a completed version as immutable. Never remove its manifests or config to make it appear
legacy. The explicit legacy option is unavailable for the 29-class or `unknown` workflows.

## Deployment boundary

This workflow does not edit:

- `dataset/processed/cnn_classification`
- `dataset/labels/species_labels.txt`
- `silvamang_ai_service/models/cnn_classifier/class_order.json`
- the active 10-output checkpoints

Train and evaluate a separate 29-output experiment from the versioned staging directory. Promote its checkpoint and matching `class_order.json` together only after held-out evaluation and application metadata are ready for every class.

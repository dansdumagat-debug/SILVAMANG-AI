# Unknown / Non-Mangrove Dataset

## Scope

The staged classifier has **29 classes: 28 supported mangrove species plus
`unknown`**. The canonical order is defined in
`silvamang_ai_service/training/cnn_classifier/staged_29_class_config.json`;
`unknown` is index 28.

`Acanthus_volubilis` was retired from this target on 2026-09-25 because the
available independently verified photographs did not meet the dataset minimum.
`Aegiceras_floridum` was retired from this target on the same date for the same
reason. Their images and provenance remain in the retired training archive.

An `unknown` example teaches the classifier to reject an unsupported plant,
background scene, unrelated object, or realistic bad capture. It must never be
an unverified mangrove image. The active production checkpoint and its class
mapping remain unchanged until a compatible 29-output model passes evaluation
and is promoted with its matching `class_order.json`.

## Category guidance

Build a balanced unknown class from these groups:

- Non-mangrove plants: coconut, banana, grass, hibiscus or other verified
  shrubs, mango or other verified ordinary trees, and papaya.
- Environmental scenes: sand, rocks, open water, buildings, people, and boats.
- Unrelated objects: bicycles and other clearly non-plant subjects.
- Incorrect captures: blurred or dark versions of reviewed unknown images.

Use exact, verified non-mangrove taxa when possible. Broad searches for
"shrubs" or "trees" can accidentally return a supported mangrove.

### Nipa is a positive class

**Never put nipa in `unknown`.** Nipa is *Nypa fruticans*, a supported mangrove
class (`Nypa_fruticans`, index 17). The collector rejects `nipa`, `nypa`, and
`Nypa fruticans` as unknown categories and blocks mangrove terms in Commons
metadata. Papaya is the configured non-mangrove replacement category.

## Commons review-queue collector

Run commands from the project root:

```powershell
cd C:\laragon\www\SilvaMang-AI
```

The collector accepts reusable Wikimedia Commons photographs with creator or
rights-holder metadata. It records the license, source record, source page,
image URL, timestamp, and SHA-256. It rejects restricted or contradictory
rights metadata and non-photo records.

### 1. Audit searches without downloading

The default mode is read only:

```powershell
python silvamang_ai_service/scripts/collect_unknown_commons_candidates.py `
  --max-search-results 100
```

Use `--category coconut` one or more times to limit a run. The supported
categories are `coconut`, `banana`, `grass`, `shrubs`, `ordinary_trees`,
`papaya`, `sand`, `rocks`, `water`, `buildings`, `people`, `boats`, and
`unrelated_objects`.

### 2. Download into the review queue

```powershell
python silvamang_ai_service/scripts/collect_unknown_commons_candidates.py `
  --download `
  --target-per-category 10 `
  --max-search-results 200
```

This writes only to the review area:

```text
dataset/incoming/unknown/<category>/
dataset/metadata/unknown_commons_review_queue.csv
dataset/review/unknown_contact_sheets/<category>.jpg
```

It does not approve candidates or place them in the training input. Repeating
the command is safe: existing source IDs, URLs, and hashes are skipped, and the
target is filled only with review files that still exist.

### 3. Review every queued image

Use each contact sheet as an index, then inspect the corresponding full-size
file. Keep a file only when all of the following are true:

- no supported mangrove is the intended subject;
- the image matches its unknown category;
- it is a usable photograph rather than an illustration, map, logo, or
  herbarium sheet; and
- its content is suitable for this classifier.

Move rejected files out of `dataset/incoming/unknown` before promotion. Do not
edit the queue CSV to mark a file approved. Re-run `--download` to refill a
category and regenerate its contact sheet after rejects are removed.

### 4. Explicitly promote reviewed files

```powershell
python silvamang_ai_service/scripts/collect_unknown_commons_candidates.py `
  --promote `
  --blur-variants 10 `
  --dark-variants 10
```

Promotion accepts only pending queue files that still exist and whose bytes,
license, attribution, source IDs, and URLs pass validation. Accepted bases are
copied to:

```text
dataset/candidates/unknown/unclassified/<category>/
```

Approved rows are added to
`dataset/metadata/candidate_image_manifest.csv`. The incoming copy is removed
only after both the manifest and queue update are durable. The operation is
resumable and safe to repeat.

Blur and dark variants are optional. They are generated only from base unknown
images accepted in that same promotion. They retain the base image's source,
license, and `source_record_id`, which keeps the base and its variants in one
split. Never create bad-capture variants from a supported mangrove image.

## Provenance, deduplication, and split safety

- Keep only CC0, public-domain, CC BY, or CC BY-SA material with attribution.
- Do not remove manifest provenance after promotion.
- Exact hashes are checked across the review queue, candidate manifest, raw
  image manifest, `dataset/candidates`, and `dataset/raw`.
- The 29-class builder deduplicates eligible files by SHA-256 and groups rows
  by source record. Exact copies and derived variants therefore cannot cross
  train, validation, and test splits.
- Keep burst shots, crops, or other near duplicates under one source record
  where possible. Exact-hash protection alone cannot identify every near
  duplicate.
- Balance categories and capture conditions. Do not let one easy scene type
  dominate `unknown`.
- Keep the held-out test split unavailable for model selection or confidence
  threshold tuning.

## Build the reviewed 29-class staging dataset

Preview the manifest generated from the manually sorted candidate folders:

```powershell
python silvamang_ai_service/scripts/import_candidate_folders.py
```

After checking the report, write it and run the readiness gate:

```powershell
python silvamang_ai_service/scripts/import_candidate_folders.py --apply

python silvamang_ai_service/training/cnn_classifier/build_staged_29_dataset.py `
  --manifest dataset/metadata/cnn_29_folder_approved_manifest.csv
```

The configured minimum is 30 unique images and three independent source groups
for every class, with every class represented in train, validation, and test.
Passing these minimums is only a build gate; a useful unknown class should have
substantially more diverse, human-reviewed negatives.

After readiness passes, create a new immutable version:

```powershell
python silvamang_ai_service/training/cnn_classifier/build_staged_29_dataset.py `
  --manifest dataset/metadata/cnn_29_folder_approved_manifest.csv `
  --apply `
  --version 2026-09-25-v1
```

Never write unknown files directly into an old processed split. The staging
builder creates clean, grouped splits under
`dataset/staging/cnn_classification_29/<version>/` and leaves current model
artifacts untouched. See
`silvamang_ai_service/training/cnn_classifier/README_staged_29_dataset.md` for
the full immutable build and deployment contract.

## Evaluation before deployment

Evaluate species accuracy, unknown precision and recall, non-mangrove false
acceptance, supported-mangrove false rejection, and per-category unknown
performance. Select the confidence threshold on validation data. Promote the
29-output checkpoint and its generated class mapping together only after the
held-out test results are acceptable.

# Dataset quality and split review

Original images, manifests, labels, and app models remain unchanged.

## Split issue discovered
The original filename pattern IMG_YYYYMMDD_HHMMSS_BurstNN identifies 254 images in 29 proposed burst groups. Of these, 22 groups cross original split boundaries. Groups each have one recorded species label. A visual inspection of Ceriops_zippeliana training previews also shows very similar Burst05 and Burst07 frames from the same timestamp. These are source-based leakage flags; they do not establish botanical identity.

`burst_group_review.csv` and `burst_split_counts.csv` contain the evidence.

## Proposed correction
`proposed_split_manifest.csv` joins original groups with filename-derived burst groups. It preserves test rows; for any joined group found in test, it excludes associated train/validation rows. For a group in validation but not test, it excludes associated training rows. No files are deleted or reassigned.

The proposal contains 3,992 train, 866 validation, and 879 test images. `proposed_exclusions.csv` lists 165 training and 16 validation exclusions. This is only a correction for the detected grouping issue, not proof that all remaining images are independent.

Do not fine-tune an old checkpoint and call this an independent evaluation: old checkpoints already saw related photos. A future experiment needs fresh ImageNet initialization and consistent preprocessing. Reserve new independent photos for final evaluation because the original test results have already informed development.

## Quality flags
`training_quality.csv` records image dimensions and heuristic detail/contrast measures. `quality_review_queue.csv` contains review flags, not confirmed bad images. `possible_visual_duplicates.csv` contains equal perceptual-hash candidates, not automatically confirmed duplicates. None of these flags authorize automatic species relabeling. Botanical label corrections need knowledgeable review.

# Researcher-approved VPS training

Saved signed-in observations already upload selected camera/gallery photos through `/api/scan-images`; offline saves use the existing sync queue. Guest photos stay local. Researchers review uploads in Admin > Dataset Verification and assign species, plant part, quality, and Verified status. No app release is required for this server workflow.

## Scheduled worker

The host `silvamang-reviewed-training.timer` checks hourly with a random delay up to five minutes, including after VPS restarts. Its oneshot service calls `dataset:training-snapshot`, then runs the existing inference Docker image in an isolated container. The container has no network, read-only application/model mounts, no added capabilities, 0.75 CPU, 1.5 GiB memory, and a separate writable `/opt/silvamang-reviewed-training` directory. The host skips runs with less than 2 GiB available memory. Existing production models are never overwritten.

The snapshot includes only verified/exported photos with recorded reviewer/time, corrected species, usable quality, and one of leaves/bark/roots/flowers. Full-tree/canopy and unknown parts are excluded. It contains internal image/group IDs and labels, not names, email addresses, or GPS. Content-addressed files and an atomic manifest prevent half-written snapshots. Revoked/rejected photos are absent from the next snapshot. Source uploads and research records are preserved.

The trigger requires at least 20 new unique approved photos and 5 or more photos each in at least 2 species. Unsupported species are excluded until a separately reviewed class expansion. Byte hashes, cropped pixel hashes, and conflicting labels are checked; exact/re-encoded duplicates of reference photos are excluded. These checks cannot detect every near-duplicate or the same tree photographed again: reviewers must also screen evaluation overlap.

## Reference data and training

`prepare_baseline.py` reads the existing `rebuild_20260926/split_manifest.csv` and its images. It preserves train/validation grouping, excludes canopy, normalizes approved historical species aliases, and creates compact 256-pixel PNG references for deterministic 224-pixel crops. Test images are not used. The baseline manifest includes source hash, split/group, file hash and pixel hash. Rebuild and review this baseline whenever the class set changes.

The worker freezes EfficientNet-B0's backbone, caches its features, and fine-tunes its classifier head for 15 epochs on original training references plus approved photos. It starts from the deployed checkpoint and preserves all classes. This is CPU-friendly species fine-tuning, not full-network retraining, plant-part detector training, or an assurance of improved accuracy.

Baseline and candidate use the same fixed validation data and preprocessing. A candidate must improve top-1 validation accuracy, not reduce macro-F1, and not reduce any class recall by more than 5 percentage points. Selecting candidates on this set means its metrics are validation metrics, not an independent test estimate. Independent held-out evaluation and human review remain necessary before deployment. No candidate is promoted automatically; mobile ONNX export/signing/publication is a separate reviewed release.

Results: `/opt/silvamang-reviewed-training/runs/<UTC timestamp>/report.json` and optional `candidate.pth`. `status.json` is copied to Laravel storage and shown on Dataset Verification in Philippine time. Features survive interruptions; an interrupted training head restarts on the next hourly run. Only completed batches are recorded as consumed. A changed baseline/checkpoint re-triggers eligibility. Deleted/relabelled approvals flag previous candidates for renewed review.

## Installation / operation

Commit the new PHP command, Console Kernel, Dataset Verification controller and template before a regular Dokploy deployment. The Console Kernel explicitly loads the command for existing containers with older optimized Composer class maps.

On the VPS, copy `worker.py`, `run_reviewed_training.sh`, and prepared `baseline/` under `/opt/silvamang-reviewed-training`. Install the included `.service` and `.timer` files under `/etc/systemd/system`, then run:

```sh
systemctl daemon-reload
systemctl enable --now silvamang-reviewed-training.timer
systemctl start --no-block silvamang-reviewed-training.service
systemctl status silvamang-reviewed-training.service
journalctl -u silvamang-reviewed-training.service -n 50 --no-pager
```

The runner uses this deployment's app/AI container names. Update those if Dokploy renames the application. It resolves the current AI image each run. Docker, model volume and application storage must be available. Do not mount writable production model paths into the worker.

To disable future runs: `systemctl disable --now silvamang-reviewed-training.timer`. To stop a currently running worker, also stop the service; do not stop the website containers.

## Validation

- Laravel tests cover researcher labeling, usable verified-only snapshots, exclusions, and revoked approval removal.
- Python tests cover duplicate/conflict filtering and rejection of accuracy-only improvements that regress F1/recall.
- A separate synthetic-data smoke run on the real VPS container completed feature extraction and 15 training epochs, produced `no_improvement`, and did not alter production. Synthetic test metrics are not model-quality measurements.
- Real training waits for the reviewed-photo threshold. The initially deployed snapshot had one eligible approved image.

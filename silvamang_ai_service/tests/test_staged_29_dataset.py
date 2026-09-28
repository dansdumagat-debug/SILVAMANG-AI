from __future__ import annotations

import csv
import hashlib
import json
import shutil
import uuid
from dataclasses import replace
from pathlib import Path

import pytest

from training.cnn_classifier.build_staged_29_dataset import (
    CANONICAL_CLASS_ORDER,
    BuildPolicy,
    DatasetBuildError,
    _normalized_url,
    build_staging_dataset,
    collect_approved_images,
    create_build_plan,
    load_policy,
)


MANIFEST_FIELDS = (
    "candidate_id",
    "file_path",
    "scientific_name",
    "reviewed_plant_part",
    "source",
    "source_record_id",
    "source_group_id",
    "observation_id",
    "source_record_url",
    "source_image_url",
    "license",
    "sha256",
    "review_status",
    "approval_status",
)


@pytest.fixture
def tmp_path() -> Path:
    """Use a normal workspace directory; restricted Windows rejects pytest's 0700 temp."""

    root = Path(__file__).resolve().parent / ".test-artifacts"
    root.mkdir(exist_ok=True)
    directory = root / f"staged-dataset-{uuid.uuid4().hex}"
    directory.mkdir()
    try:
        yield directory
    finally:
        shutil.rmtree(directory, ignore_errors=True)


def _hash(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _write_image(project_root: Path, relative_path: str, payload: bytes) -> Path:
    path = project_root / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return path


def _row(
    relative_path: str,
    class_name: str,
    payload: bytes,
    record_id: str,
    *,
    candidate_id: str,
    status: str = "approved",
    license_value: str = "CC BY 4.0",
) -> dict[str, str]:
    return {
        "candidate_id": candidate_id,
        "file_path": relative_path,
        "scientific_name": class_name.replace("_", " "),
        "reviewed_plant_part": "leaves",
        "source": "test collection",
        "source_record_id": record_id,
        "source_record_url": f"https://example.test/records/{record_id}",
        "source_image_url": f"https://example.test/images/{candidate_id}.jpg",
        "license": license_value,
        "sha256": _hash(payload),
        "review_status": status,
    }


def _write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def _policy(project_root: Path, manifest: Path) -> BuildPolicy:
    return BuildPolicy(
        class_order=("Species_alpha", "Species_beta"),
        split_ratios={"train": 0.7, "val": 0.2, "test": 0.1},
        seed=42,
        minimum_unique_images_per_class=3,
        minimum_source_groups_per_class=3,
        require_every_class_in_every_split=True,
        required_approval_status="approved",
        require_declared_sha256=True,
        require_source_record=True,
        require_rights_or_license=True,
        allowed_input_roots=(
            (project_root / "dataset" / "candidates").resolve(),
            (project_root / "dataset" / "raw").resolve(),
        ),
        input_manifests=(manifest.resolve(),),
        staging_root=(project_root / "dataset" / "staging" / "cnn29").resolve(),
    )


def _ready_fixture(tmp_path: Path) -> tuple[BuildPolicy, Path, list[Path]]:
    specifications = [
        ("Species_alpha", "alpha-1.jpg", b"alpha-one", "alpha-record-1"),
        ("Species_alpha", "alpha-1-copy.jpg", b"alpha-one", "alpha-record-2"),
        ("Species_alpha", "alpha-2.jpg", b"alpha-two", "alpha-record-2"),
        ("Species_alpha", "alpha-3.jpg", b"alpha-three", "alpha-record-3"),
        ("Species_alpha", "alpha-4.jpg", b"alpha-four", "alpha-record-4"),
        ("Species_beta", "beta-1.jpg", b"beta-one", "beta-record-1"),
        ("Species_beta", "beta-2.jpg", b"beta-two", "beta-record-2"),
        ("Species_beta", "beta-3.jpg", b"beta-three", "beta-record-3"),
    ]
    rows: list[dict[str, str]] = []
    source_paths: list[Path] = []
    for index, (class_name, filename, payload, record_id) in enumerate(specifications):
        relative_path = f"dataset/candidates/{class_name}/{filename}"
        source_paths.append(_write_image(tmp_path, relative_path, payload))
        rows.append(
            _row(
                relative_path,
                class_name,
                payload,
                record_id,
                candidate_id=f"candidate-{index}",
            )
        )
    manifest = tmp_path / "dataset" / "metadata" / "approved.csv"
    _write_manifest(manifest, rows)
    return _policy(tmp_path, manifest), manifest, source_paths


def test_production_config_is_canonical_and_separate_from_active_artifacts() -> None:
    config_path = (
        Path(__file__).resolve().parents[1]
        / "training"
        / "cnn_classifier"
        / "staged_29_class_config.json"
    )
    policy, payload = load_policy(config_path)

    assert policy.class_order == CANONICAL_CLASS_ORDER
    assert len(policy.class_order) == 29
    assert "Acanthus_volubilis" not in policy.class_order
    assert "Aegiceras_floridum" not in policy.class_order
    assert policy.class_order[-1] == "unknown"
    assert payload["unknown_class"] == {"name": "unknown", "index": 28}
    assert "silvamang_ai_service/models/cnn_classifier/class_order.json" in payload[
        "active_artifacts_untouched"
    ]


def test_only_explicitly_approved_traceable_rows_are_accepted(tmp_path: Path) -> None:
    approved_payload = b"approved"
    pending_payload = b"pending"
    invalid_payload = b"invalid"
    rows = []
    for name, payload in (
        ("approved.jpg", approved_payload),
        ("pending.jpg", pending_payload),
        ("invalid.jpg", invalid_payload),
    ):
        relative_path = f"dataset/candidates/Species_alpha/{name}"
        _write_image(tmp_path, relative_path, payload)
        rows.append(
            _row(
                relative_path,
                "Species_alpha",
                payload,
                name,
                candidate_id=name,
                status="pending" if name == "pending.jpg" else "approved",
                license_value="" if name == "invalid.jpg" else "CC BY 4.0",
            )
        )
    manifest = tmp_path / "dataset" / "metadata" / "approved.csv"
    _write_manifest(manifest, rows)
    policy = _policy(tmp_path, manifest)

    accepted, errors, stats, digests = collect_approved_images((manifest,), policy, tmp_path)

    assert [item.entry_id for item in accepted] == ["approved.jpg"]
    assert any("missing license/permission_status" in error for error in errors)
    manifest_stats = stats[str(manifest.resolve())]
    assert manifest_stats["not_approved"] == 1
    assert manifest_stats["invalid_approved_rows"] == 1
    assert digests[str(manifest.resolve())] == _hash(manifest.read_bytes())


def test_approved_unknown_candidate_does_not_require_a_mangrove_part(tmp_path: Path) -> None:
    payload = b"non-mangrove-scene"
    relative_path = "dataset/candidates/unknown/scene.jpg"
    _write_image(tmp_path, relative_path, payload)
    row = _row(
        relative_path,
        "unknown",
        payload,
        "unknown-record-1",
        candidate_id="unknown-1",
    )
    row["reviewed_plant_part"] = ""
    manifest = tmp_path / "dataset" / "metadata" / "unknown.csv"
    _write_manifest(manifest, [row])
    policy = replace(_policy(tmp_path, manifest), class_order=("unknown",))

    accepted, errors, _, _ = collect_approved_images((manifest,), policy, tmp_path)

    assert errors == []
    assert [item.class_name for item in accepted] == ["unknown"]


def test_conflicting_approval_columns_are_rejected(tmp_path: Path) -> None:
    payload = b"ambiguous-approval"
    relative_path = "dataset/candidates/Species_alpha/ambiguous.jpg"
    _write_image(tmp_path, relative_path, payload)
    row = _row(
        relative_path,
        "Species_alpha",
        payload,
        "ambiguous-record",
        candidate_id="ambiguous",
    )
    row["approval_status"] = "rejected"
    manifest = tmp_path / "dataset" / "metadata" / "ambiguous.csv"
    _write_manifest(manifest, [row])
    policy = _policy(tmp_path, manifest)

    accepted, errors, stats, _ = collect_approved_images((manifest,), policy, tmp_path)

    assert accepted == []
    assert any("conflicting review_status/approval_status" in error for error in errors)
    assert stats[str(manifest.resolve())]["invalid_approval_rows"] == 1


def test_source_record_url_normalization_preserves_semantic_query_values() -> None:
    first = _normalized_url("HTTPS://EXAMPLE.TEST/record?id=1&utm_source=a")
    second = _normalized_url("https://example.test/record?utm_source=b&id=2")

    assert first == "https://example.test/record?id=1"
    assert second == "https://example.test/record?id=2"
    assert first != second


def test_plan_deduplicates_hashes_and_keeps_source_groups_in_one_split(tmp_path: Path) -> None:
    policy, manifest, _ = _ready_fixture(tmp_path)

    plan = create_build_plan(policy, (manifest,), tmp_path)
    repeated_plan = create_build_plan(policy, (manifest,), tmp_path)
    with manifest.open("r", encoding="utf-8", newline="") as handle:
        reversed_rows = list(reversed(list(csv.DictReader(handle))))
    reversed_manifest = manifest.with_name("approved-reversed.csv")
    _write_manifest(reversed_manifest, reversed_rows)
    reordered_plan = create_build_plan(policy, (reversed_manifest,), tmp_path)

    assert plan.ready
    assert [(item.relative_path, item.split) for item in plan.images] == [
        (item.relative_path, item.split) for item in repeated_plan.images
    ]
    assert {item.image.sha256: item.split for item in plan.images} == {
        item.image.sha256: item.split for item in reordered_plan.images
    }
    assert len(plan.records) == 8
    assert len(plan.images) == 7
    assert plan.duplicate_rows_removed == 1
    assert len({item.image.sha256 for item in plan.images}) == len(plan.images)

    alpha_record_two = [
        item
        for item in plan.images
        if "id::test collection::alpha-record-2" in item.source_record_keys
    ]
    assert len(alpha_record_two) == 2
    assert len({item.split for item in alpha_record_two}) == 1

    for class_name in policy.class_order:
        assert {
            item.split for item in plan.images if item.image.class_name == class_name
        } == {"train", "val", "test"}


def test_all_source_identifiers_are_used_and_shared_group_connects_sequence(
    tmp_path: Path,
) -> None:
    policy, manifest, _ = _ready_fixture(tmp_path)
    with manifest.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    sequence_rows = [row for row in rows if row["candidate_id"] in {"candidate-3", "candidate-4"}]
    assert len(sequence_rows) == 2
    for index, row in enumerate(sequence_rows, start=1):
        row["source_group_id"] = "field-sequence-7"
        row["observation_id"] = f"observation-{index}"
    _write_manifest(manifest, rows)

    relaxed = replace(
        policy,
        minimum_source_groups_per_class=1,
        require_every_class_in_every_split=False,
    )
    plan = create_build_plan(relaxed, (manifest,), tmp_path)

    sequence = [
        item
        for item in plan.images
        if item.image.entry_id in {"candidate-3", "candidate-4"}
    ]
    assert len(sequence) == 2
    assert len({item.split for item in sequence}) == 1
    assert len({item.group_id for item in sequence}) == 1
    for item in sequence:
        assert "id::test collection::field-sequence-7" in item.source_record_keys
        assert f"id::test collection::{item.image.source_record_id}" in item.source_record_keys
        assert any(key.startswith("id::test collection::observation-") for key in item.source_record_keys)


def test_conflicting_labels_and_underrepresented_classes_block_build(tmp_path: Path) -> None:
    payload = b"same-image"
    rows = []
    for index, class_name in enumerate(("Species_alpha", "Species_beta")):
        relative_path = f"dataset/candidates/{class_name}/{index}.jpg"
        _write_image(tmp_path, relative_path, payload)
        rows.append(
            _row(
                relative_path,
                class_name,
                payload,
                f"record-{index}",
                candidate_id=f"candidate-{index}",
            )
        )
    manifest = tmp_path / "dataset" / "metadata" / "approved.csv"
    _write_manifest(manifest, rows)
    policy = _policy(tmp_path, manifest)

    plan = create_build_plan(policy, (manifest,), tmp_path)

    assert not plan.ready
    assert any("Conflicting class labels" in error for error in plan.errors)
    assert any("missing approved" in error for error in plan.errors)
    assert not policy.staging_root.exists()
    with pytest.raises(DatasetBuildError, match="Readiness checks failed"):
        build_staging_dataset(plan, "v1", {}, tmp_path)


def test_nonempty_underrepresented_classes_block_build(tmp_path: Path) -> None:
    policy, manifest, _ = _ready_fixture(tmp_path)
    strict_policy = replace(policy, minimum_unique_images_per_class=5)

    plan = create_build_plan(strict_policy, (manifest,), tmp_path)

    assert not plan.ready
    assert any("Species_alpha: 4 unique images; minimum is 5" in error for error in plan.errors)
    assert any("Species_beta: 3 unique images; minimum is 5" in error for error in plan.errors)
    assert not any("missing approved" in error for error in plan.errors)


def test_apply_copies_to_new_version_without_modifying_sources(tmp_path: Path) -> None:
    policy, manifest, source_paths = _ready_fixture(tmp_path)
    plan = create_build_plan(policy, (manifest,), tmp_path)
    original_payloads = {path: path.read_bytes() for path in source_paths}

    target = build_staging_dataset(
        plan,
        "2026-09-24-v1",
        {"schema_version": 1, "class_order": list(policy.class_order)},
        tmp_path,
    )

    assert target == policy.staging_root / "2026-09-24-v1"
    assert (target / "BUILD_COMPLETE.json").is_file()
    assert not (target / "BUILD_INCOMPLETE").exists()
    assert json.loads((target / "class_order.json").read_text(encoding="utf-8")) == list(
        policy.class_order
    )
    assert len(list((target / "train").rglob("*.jpg"))) + len(
        list((target / "val").rglob("*.jpg"))
    ) + len(list((target / "test").rglob("*.jpg"))) == 7
    assert all(path.read_bytes() == payload for path, payload in original_payloads.items())

    snapshots = list((target / "input_manifests").iterdir())
    assert len(snapshots) == 1
    assert snapshots[0].read_bytes() == manifest.read_bytes()
    with (target / "dataset_manifest.csv").open(
        "r", encoding="utf-8", newline=""
    ) as handle:
        staged_rows = list(csv.DictReader(handle))
    assert {row["approval_status"] for row in staged_rows} == {"approved"}
    assert all(row["entry_id"] for row in staged_rows)
    duplicate_row = next(row for row in staged_rows if row["sha256"] == _hash(b"alpha-one"))
    assert len(json.loads(duplicate_row["lineage_json"])) == 2
    build_report = json.loads((target / "build_report.json").read_text(encoding="utf-8"))
    assert build_report["input_manifests"][0]["sha256"] == _hash(manifest.read_bytes())

    with pytest.raises(DatasetBuildError, match="already exists"):
        build_staging_dataset(plan, "2026-09-24-v1", {}, tmp_path)


def test_source_mutation_and_output_boundary_are_rejected_before_write(tmp_path: Path) -> None:
    policy, manifest, source_paths = _ready_fixture(tmp_path)
    plan = create_build_plan(policy, (manifest,), tmp_path)
    source_paths[-1].write_bytes(b"changed-after-planning")

    with pytest.raises(DatasetBuildError, match="changed after planning"):
        build_staging_dataset(plan, "mutated", {}, tmp_path)
    assert not (policy.staging_root / "mutated").exists()

    lineage_policy, lineage_manifest, _ = _ready_fixture(tmp_path / "lineage")
    lineage_plan = create_build_plan(
        lineage_policy, (lineage_manifest,), tmp_path / "lineage"
    )
    deduplicated = next(item for item in lineage_plan.images if len(item.lineage) == 2)
    nonrepresentative = next(
        row for row in deduplicated.lineage if row.source_path != deduplicated.image.source_path
    )
    nonrepresentative.source_path.write_bytes(b"changed-duplicate-lineage")
    with pytest.raises(DatasetBuildError, match="changed after planning"):
        build_staging_dataset(
            lineage_plan,
            "mutated-lineage",
            {},
            tmp_path / "lineage",
        )
    assert not (lineage_policy.staging_root / "mutated-lineage").exists()

    clean_policy, clean_manifest, _ = _ready_fixture(tmp_path / "clean")
    clean_plan = create_build_plan(clean_policy, (clean_manifest,), tmp_path / "clean")
    active_like_root = tmp_path / "clean" / "dataset" / "processed" / "cnn_classification"
    with pytest.raises(DatasetBuildError, match="must stay under"):
        build_staging_dataset(
            clean_plan,
            "unsafe",
            {},
            tmp_path / "clean",
            staging_root=active_like_root,
        )
    assert not (active_like_root / "unsafe").exists()

    traversal_policy = replace(
        clean_policy,
        class_order=("../processed_escape", "Species_beta"),
    )
    traversal_plan = replace(clean_plan, policy=traversal_policy, errors=())
    with pytest.raises(DatasetBuildError, match="safe single directory component"):
        build_staging_dataset(
            traversal_plan,
            "unsafe-class",
            {},
            tmp_path / "clean",
        )
    assert not (clean_policy.staging_root / "unsafe-class").exists()


def test_copy_hash_mismatch_leaves_incomplete_marker(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    policy, manifest, _ = _ready_fixture(tmp_path)
    plan = create_build_plan(policy, (manifest,), tmp_path)
    original_copy = shutil.copy2

    def corrupt_first_image(source: str | Path, destination: str | Path, *args, **kwargs):
        result = original_copy(source, destination, *args, **kwargs)
        destination_path = Path(destination)
        if destination_path.suffix.casefold() == ".jpg":
            destination_path.write_bytes(b"corrupted-copy")
        return result

    monkeypatch.setattr(
        "training.cnn_classifier.build_staged_29_dataset.shutil.copy2",
        corrupt_first_image,
    )

    with pytest.raises(DatasetBuildError, match="failed SHA-256 verification"):
        build_staging_dataset(plan, "copy-failure", {}, tmp_path)

    target = policy.staging_root / "copy-failure"
    assert (target / "BUILD_INCOMPLETE").is_file()
    assert not (target / "BUILD_COMPLETE.json").exists()

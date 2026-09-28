from __future__ import annotations

import csv
import hashlib
from pathlib import Path

import pytest

from scripts.import_candidate_folders import (
    DEFAULT_CONFIG_PATH,
    INTERNAL_PERMISSION,
    INTERNAL_SOURCE,
    MANIFEST_FIELDS,
    create_import_plan,
    infer_source_group_id,
    main,
    normalize_part,
    write_manifest_atomic,
)
from training.cnn_classifier.build_staged_29_dataset import (
    BuildPolicy,
    collect_approved_images,
    create_build_plan,
)


SOURCE_FIELDS = (
    "candidate_id",
    "file_path",
    "scientific_name",
    "reviewed_plant_part",
    "source",
    "source_record_id",
    "source_record_url",
    "source_image_url",
    "creator",
    "rights_holder",
    "license",
    "country",
    "state_province",
    "locality",
    "downloaded_at",
    "sha256",
    "review_status",
    "review_notes",
)


def _image(project_root: Path, relative: str, payload: bytes) -> tuple[Path, str]:
    path = project_root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return path, hashlib.sha256(payload).hexdigest()


def _write_source_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=SOURCE_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def _source_row(
    digest: str,
    *,
    candidate_id: str = "candidate-1",
    status: str = "pending",
    note: str = "Original note.",
) -> dict[str, str]:
    return {
        "candidate_id": candidate_id,
        "file_path": "dataset/candidates/Old_species/unclassified/old.jpg",
        "scientific_name": "Old species",
        "reviewed_plant_part": "",
        "source": "GBIF occurrence media",
        "source_record_id": "record-123",
        "source_record_url": "https://example.test/record/123",
        "source_image_url": "https://example.test/image/123.jpg",
        "creator": "Example creator",
        "rights_holder": "Example rights holder",
        "license": "https://creativecommons.org/licenses/by/4.0/",
        "country": "Philippines",
        "state_province": "Leyte",
        "locality": "Test locality",
        "downloaded_at": "2026-09-25T00:00:00+00:00",
        "sha256": digest,
        "review_status": status,
        "review_notes": note,
    }


def _read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def test_dry_run_does_not_write_and_apply_is_idempotent(tmp_path: Path) -> None:
    image, _ = _image(
        tmp_path,
        "dataset/candidates/Avicennia_marina/Leaves/one.jpg",
        b"one-image",
    )
    source_manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_source_manifest(source_manifest, [])
    output = tmp_path / "dataset" / "metadata" / "cnn_29_folder_approved_manifest.csv"
    source_before = source_manifest.read_bytes()
    image_before = image.read_bytes()
    common_args = [
        "--project-root",
        str(tmp_path),
        "--config",
        str(DEFAULT_CONFIG_PATH),
    ]

    assert main(common_args) == 0
    assert not output.exists()
    assert source_manifest.read_bytes() == source_before
    assert image.read_bytes() == image_before

    assert main([*common_args, "--apply"]) == 0
    first_output = output.read_bytes()
    assert main([*common_args, "--apply"]) == 0
    assert output.read_bytes() == first_output
    assert source_manifest.read_bytes() == source_before
    assert image.read_bytes() == image_before


def test_apply_refuses_to_overwrite_source_manifest(tmp_path: Path) -> None:
    _image(
        tmp_path,
        "dataset/candidates/Avicennia_marina/Leaves/one.jpg",
        b"one-image",
    )
    source_manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_source_manifest(source_manifest, [])
    original = source_manifest.read_bytes()

    exit_code = main(
        [
            "--project-root",
            str(tmp_path),
            "--config",
            str(DEFAULT_CONFIG_PATH),
            "--output-manifest",
            str(source_manifest),
            "--apply",
        ]
    )

    assert exit_code == 2
    assert source_manifest.read_bytes() == original


@pytest.mark.parametrize(
    ("folder", "class_name", "expected"),
    [
        ("bark", "Avicennia_marina", "bark"),
        ("Barks", "Avicennia_marina", "bark"),
        ("Leaves", "Avicennia_marina", "leaves"),
        ("roots", "Avicennia_marina", "roots"),
        ("Flowers", "Avicennia_marina", "flowers"),
        ("canopy", "Avicennia_marina", "canopy"),
        ("unknown", "unknown", "unclassified"),
        ("unclassified", "unknown", "unclassified"),
        ("unclassified", "Avicennia_marina", ""),
    ],
)
def test_normalizes_supported_part_folders(
    folder: str, class_name: str, expected: str
) -> None:
    assert normalize_part(folder, class_name) == expected


def test_filename_groups_use_capture_minutes_and_local_sequence_blocks() -> None:
    digest = "0" * 64
    first_block = infer_source_group_id("Ceriops_tagal", "Ceriops (5).jpeg", digest)
    copied_first_block = infer_source_group_id(
        "Ceriops_tagal", "Ceriops (8) - Copy.jpeg", digest
    )
    second_block = infer_source_group_id("Ceriops_tagal", "Ceriops (15).jpeg", digest)
    first_minute = infer_source_group_id(
        "Ceriops_tagal", "Ceriops - 2026-07-16T160612.675.jpeg", digest
    )
    second_minute = infer_source_group_id(
        "Ceriops_tagal", "Ceriops - 2026-07-16T160712.675.jpeg", digest
    )

    assert first_block == copied_first_block
    assert first_block.endswith("series-ceriops-0001-0010")
    assert second_block.endswith("series-ceriops-0011-0020")
    assert first_block != second_block
    assert first_minute.endswith("capture-minute-20260716-1606")
    assert second_minute.endswith("capture-minute-20260716-1607")
    assert first_minute != second_minute


def test_cross_species_exact_hash_is_excluded(tmp_path: Path) -> None:
    _, digest = _image(
        tmp_path,
        "dataset/candidates/Avicennia_marina/Leaves/one.jpg",
        b"same-image",
    )
    _image(
        tmp_path,
        "dataset/candidates/Sonneratia_alba/roots/two.jpg",
        b"same-image",
    )
    source_manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_source_manifest(source_manifest, [_source_row(digest)])

    plan = create_import_plan(
        tmp_path / "dataset" / "candidates", source_manifest, tmp_path
    )

    assert digest in plan.cross_label_hashes
    assert {image.class_name for image in plan.cross_label_hashes[digest]} == {
        "Avicennia_marina",
        "Sonneratia_alba",
    }
    assert not [row for row in plan.rows if row["sha256"] == digest]


def test_rejected_and_flagged_rows_remain_excluded(tmp_path: Path) -> None:
    cases = (("rejected", b"rejected"), ("flagged", b"flagged"), ("pending", b"pending"))
    source_rows: list[dict[str, str]] = []
    expected: dict[str, tuple[str, str]] = {}
    for status, payload in cases:
        _, digest = _image(
            tmp_path,
            f"dataset/candidates/Avicennia_marina/Leaves/{status}.jpg",
            payload,
        )
        note = f"{status} note"
        source_rows.append(
            _source_row(digest, candidate_id=f"id-{status}", status=status, note=note)
        )
        expected[digest] = (status, note)
    source_manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_source_manifest(source_manifest, source_rows)

    plan = create_import_plan(
        tmp_path / "dataset" / "candidates", source_manifest, tmp_path
    )
    rows = {row["sha256"]: row for row in plan.rows}

    for digest, (old_status, old_note) in expected.items():
        expected_status = "approved" if old_status == "pending" else old_status
        assert rows[digest]["review_status"] == expected_status
        if old_status in {"rejected", "flagged"}:
            assert rows[digest]["review_notes"] == old_note
    assert plan.excluded_review_files == 2


def test_metadata_is_preserved_by_hash_while_folder_supplies_labels(tmp_path: Path) -> None:
    _, digest = _image(
        tmp_path,
        "dataset/candidates/Avicennia_marina/Barks/moved.jpg",
        b"moved-image",
    )
    _, other_digest = _image(
        tmp_path,
        "dataset/candidates/Sonneratia_alba/Leaves/other.jpg",
        b"different-image",
    )
    preserved = _source_row(digest, candidate_id="preserved-id")
    same_name_wrong_hash = _source_row(other_digest, candidate_id="wrong-id")
    same_name_wrong_hash["source"] = "Wrong metadata"
    source_manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_source_manifest(source_manifest, [same_name_wrong_hash, preserved])

    plan = create_import_plan(
        tmp_path / "dataset" / "candidates", source_manifest, tmp_path
    )
    row = next(item for item in plan.rows if item["sha256"] == digest)

    assert row["candidate_id"] == "preserved-id"
    assert row["file_path"] == "dataset/candidates/Avicennia_marina/Barks/moved.jpg"
    assert row["scientific_name"] == "Avicennia_marina"
    assert row["reviewed_plant_part"] == "bark"
    assert row["review_status"] == "approved"
    for field in (
        "source",
        "source_record_id",
        "source_record_url",
        "source_image_url",
        "creator",
        "rights_holder",
        "license",
        "country",
        "state_province",
        "locality",
        "downloaded_at",
    ):
        assert row[field] == preserved[field]
    assert "Original note." in row["review_notes"]
    assert row["source"] != "Wrong metadata"


def test_incomplete_matched_metadata_gets_truthful_builder_fallbacks(tmp_path: Path) -> None:
    _, digest = _image(
        tmp_path,
        "dataset/candidates/Avicennia_marina/Leaves/incomplete.jpg",
        b"incomplete-metadata",
    )
    incomplete = _source_row(digest)
    incomplete["candidate_id"] = ""
    incomplete["source"] = ""
    incomplete["source_record_id"] = ""
    incomplete["license"] = ""
    source_manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_source_manifest(source_manifest, [incomplete])

    plan = create_import_plan(
        tmp_path / "dataset" / "candidates", source_manifest, tmp_path
    )
    row = plan.rows[0]

    assert row["candidate_id"].startswith(f"folder_{digest[:16]}_")
    assert row["source"] == INTERNAL_SOURCE
    assert row["source_record_id"] == ""
    assert row["source_group_id"]
    assert row["license"] == ""
    assert row["permission_status"] == INTERNAL_PERMISSION


def test_internal_rows_are_structurally_accepted_by_staging_builder(tmp_path: Path) -> None:
    _, digest = _image(
        tmp_path,
        "dataset/candidates/Avicennia_marina/canopy/IMG20260718072440.jpg",
        b"internal-image",
    )
    source_manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_source_manifest(source_manifest, [])
    output = tmp_path / "dataset" / "metadata" / "cnn_29_folder_approved_manifest.csv"
    import_plan = create_import_plan(
        tmp_path / "dataset" / "candidates", source_manifest, tmp_path
    )
    write_manifest_atomic(output, import_plan.rows)

    row = _read_rows(output)[0]
    assert tuple(row) == MANIFEST_FIELDS
    assert row["sha256"] == digest
    assert row["source"] == INTERNAL_SOURCE
    assert row["license"] == ""
    assert row["permission_status"] == INTERNAL_PERMISSION
    assert row["source_record_id"] == ""
    assert row["source_group_id"]

    policy = BuildPolicy(
        class_order=("Avicennia_marina",),
        split_ratios={"train": 0.7, "val": 0.2, "test": 0.1},
        seed=42,
        minimum_unique_images_per_class=1,
        minimum_source_groups_per_class=1,
        require_every_class_in_every_split=False,
        required_approval_status="approved",
        require_declared_sha256=True,
        require_source_record=True,
        require_rights_or_license=True,
        allowed_input_roots=((tmp_path / "dataset" / "candidates").resolve(),),
        input_manifests=(output.resolve(),),
        staging_root=(tmp_path / "dataset" / "staging").resolve(),
    )
    records, errors, stats, _ = collect_approved_images((output,), policy, tmp_path)
    assert errors == []
    assert len(records) == 1
    assert stats[str(output.resolve())]["accepted_rows"] == 1
    build_plan = create_build_plan(policy, (output,), tmp_path)
    assert build_plan.ready
    assert len(build_plan.images) == 1

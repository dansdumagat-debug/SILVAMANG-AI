from __future__ import annotations

import csv
import hashlib
import json
import shutil
import uuid
from pathlib import Path

import pytest

from scripts.audit_candidate_dataset import (
    DEFAULT_STAGED_CONFIG_PATH,
    audit_candidate_dataset,
    configured_minimum_approved_unique_images,
    main,
    parse_args,
)


MANIFEST_FIELDS = (
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


@pytest.fixture
def tmp_path() -> Path:
    test_root = Path(__file__).resolve().parent / ".test-artifacts"
    test_root.mkdir(exist_ok=True)
    directory = test_root / f"candidate-audit-{uuid.uuid4().hex}"
    directory.mkdir()
    try:
        yield directory
    finally:
        shutil.rmtree(directory, ignore_errors=True)


def _write_image(path: Path, payload: bytes) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return hashlib.sha256(payload).hexdigest()


def _write_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def _manifest_row(
    *,
    file_path: str,
    digest: str,
    species: str = "Species one",
    status: str = "approved",
) -> dict[str, str]:
    return {
        "candidate_id": digest[:12],
        "file_path": file_path,
        "scientific_name": species,
        "reviewed_plant_part": "leaves",
        "source": "Test source",
        "source_record_id": "source-1",
        "source_record_url": "https://example.test/record/1",
        "source_image_url": "https://example.test/image/1.jpg",
        "creator": "Test creator",
        "rights_holder": "Test creator",
        "license": "https://creativecommons.org/licenses/by/4.0/",
        "country": "Philippines",
        "state_province": "",
        "locality": "",
        "downloaded_at": "2026-09-24T00:00:00+00:00",
        "sha256": digest,
        "review_status": status,
        "review_notes": "Reviewed for test.",
    }


def test_ready_when_unique_image_is_approved_and_manifest_is_consistent(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    image = candidates / "Species_one" / "leaves" / "one.jpg"
    digest = _write_image(image, b"unique-image-one")
    manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_manifest(
        manifest,
        [
            _manifest_row(
                file_path="dataset/candidates/Species_one/leaves/one.jpg",
                digest=digest,
            )
        ],
    )

    report = audit_candidate_dataset(
        candidates,
        manifest,
        project_root=tmp_path,
        minimum_approved_unique_images_per_class=1,
    )

    assert report["ready"] is True
    assert report["per_class"]["Species_one"]["approved_unique_hashes"] == 1
    assert report["blockers"] == []


def test_default_minimum_matches_staged_builder_policy() -> None:
    configured = configured_minimum_approved_unique_images(DEFAULT_STAGED_CONFIG_PATH)
    args = parse_args([])

    assert configured == 30
    assert args.minimum_approved_unique_images == configured


def test_audit_loads_minimum_from_selected_staged_config(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    image = candidates / "Species_one" / "leaves" / "one.jpg"
    digest = _write_image(image, b"unique-image-one")
    manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_manifest(
        manifest,
        [
            _manifest_row(
                file_path="dataset/candidates/Species_one/leaves/one.jpg",
                digest=digest,
            )
        ],
    )
    config = tmp_path / "staged_config.json"
    config.write_text(
        json.dumps({"readiness": {"minimum_unique_images_per_class": 2}}),
        encoding="utf-8",
    )

    report = audit_candidate_dataset(
        candidates,
        manifest,
        project_root=tmp_path,
        staged_config_path=config,
    )

    assert report["ready"] is False
    assert report["minimum_approved_unique_images_per_class"] == 2
    assert report["low_count_classes"] == ["Species_one"]
    assert "classes_below_minimum" in {
        blocker["code"] for blocker in report["blockers"]
    }


def test_cli_rejects_minimum_below_selected_staged_policy(
    tmp_path: Path, capsys
) -> None:
    config = tmp_path / "staged_config.json"
    config.write_text(
        json.dumps({"readiness": {"minimum_unique_images_per_class": 30}}),
        encoding="utf-8",
    )

    with pytest.raises(SystemExit) as error:
        parse_args(
            [
                "--staged-config",
                str(config),
                "--minimum-approved-unique-images",
                "20",
            ]
        )
    
    assert error.value.code == 2
    assert (
        "cannot be lower than the staged dataset policy minimum (30)"
        in capsys.readouterr().err
    )


def test_duplicate_under_different_species_is_a_cross_label_blocker(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    first = candidates / "Species_one" / "leaves" / "one.jpg"
    second = candidates / "Species_two" / "leaves" / "two.jpg"
    digest = _write_image(first, b"same-image")
    _write_image(second, b"same-image")
    manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_manifest(
        manifest,
        [
            _manifest_row(
                file_path="dataset/candidates/Species_one/leaves/one.jpg",
                digest=digest,
            )
        ],
    )

    report = audit_candidate_dataset(
        candidates,
        manifest,
        project_root=tmp_path,
        minimum_approved_unique_images_per_class=0,
    )
    blocker_codes = {blocker["code"] for blocker in report["blockers"]}

    assert report["ready"] is False
    assert report["summary"]["duplicate_groups"] == 1
    assert report["summary"]["cross_label_duplicate_groups"] == 1
    assert "cross_label_duplicate_groups" in blocker_codes
    assert "folder_manifest_label_conflicts" in blocker_codes


def test_hash_coverage_finds_moved_file_but_stale_path_still_blocks_review(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    moved = candidates / "Species_one" / "leaves" / "moved.jpg"
    digest = _write_image(moved, b"moved-image")
    manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_manifest(
        manifest,
        [
            _manifest_row(
                file_path="dataset/candidates/Species_one/unclassified/original.jpg",
                digest=digest,
            )
        ],
    )

    report = audit_candidate_dataset(
        candidates,
        manifest,
        project_root=tmp_path,
        minimum_approved_unique_images_per_class=1,
    )
    blocker_codes = {blocker["code"] for blocker in report["blockers"]}

    assert report["manifest"]["physical_files_matched_by_hash"] == 1
    assert report["manifest"]["untracked_physical_files"] == 0
    assert report["manifest"]["stale_actionable_paths"] == 1
    assert "stale_actionable_manifest_paths" in blocker_codes


def test_reference_overlap_is_reported_as_a_blocker(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    image = candidates / "Species_one" / "leaves" / "one.jpg"
    digest = _write_image(image, b"already-trained-image")
    reference = tmp_path / "dataset" / "raw"
    _write_image(reference / "Species_one" / "leaves" / "copy.jpg", b"already-trained-image")
    manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    _write_manifest(
        manifest,
        [
            _manifest_row(
                file_path="dataset/candidates/Species_one/leaves/one.jpg",
                digest=digest,
            )
        ],
    )

    report = audit_candidate_dataset(
        candidates,
        manifest,
        project_root=tmp_path,
        reference_roots=[reference],
        minimum_approved_unique_images_per_class=1,
    )

    assert report["ready"] is False
    assert report["reference_overlap"]["unique_candidate_hashes"] == 1
    assert "reference_overlap" in {blocker["code"] for blocker in report["blockers"]}


def test_cli_returns_nonzero_for_blocked_dataset(tmp_path: Path, capsys) -> None:
    candidates = tmp_path / "candidates"
    _write_image(candidates / "Species_one" / "leaves" / "one.jpg", b"untracked")
    missing_manifest = tmp_path / "missing.csv"

    exit_code = main(
        [
            "--candidate-root",
            str(candidates),
            "--manifest",
            str(missing_manifest),
            "--no-default-references",
            "--json",
        ]
    )

    assert exit_code == 1
    assert '"ready": false' in capsys.readouterr().out

from pathlib import Path

import pytest

from scripts.candidate_manifest_lock import (
    CandidateManifestBusyError,
    candidate_manifest_write_lock,
    lock_path_for,
)
from scripts.candidate_manifest_paths import CandidatePathResolver, sha256_for
from scripts.reconcile_candidate_manifest_paths import reconcile_rows


def _file(root: Path, relative: str, payload: bytes = b"image") -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return path


def test_reconciles_unique_stale_path(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    image = _file(candidates, "Test_species/Leaves/id-1.jpg")
    rows = [
        {
            "candidate_id": "id-1",
            "scientific_name": "Test species",
            "file_path": "dataset/candidates/Test_species/unclassified/id-1.jpg",
            "sha256": sha256_for(image),
            "reviewed_plant_part": "",
        }
    ]

    report = reconcile_rows(
        rows,
        CandidatePathResolver(tmp_path, candidates),
        tmp_path,
        candidates,
        apply_changes=True,
    )

    assert report.repairable == 1
    assert report.changed == 1
    assert rows[0]["file_path"] == "dataset/candidates/Test_species/Leaves/id-1.jpg"


def test_does_not_guess_between_ambiguous_copies(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    first = _file(candidates, "Test_species/Leaves/id-1.jpg")
    _file(candidates, "Test_species/Flowers/id-1.jpg")
    rows = [
        {
            "candidate_id": "id-1",
            "scientific_name": "Test species",
            "file_path": "dataset/candidates/Test_species/unclassified/id-1.jpg",
            "sha256": sha256_for(first),
            "reviewed_plant_part": "",
        }
    ]

    report = reconcile_rows(
        rows,
        CandidatePathResolver(tmp_path, candidates),
        tmp_path,
        candidates,
        apply_changes=True,
    )

    assert report.ambiguous == 1
    assert report.changed == 0
    assert "/unclassified/" in rows[0]["file_path"]


def test_reviewed_part_resolves_ambiguous_copy(tmp_path: Path) -> None:
    candidates = tmp_path / "dataset" / "candidates"
    first = _file(candidates, "Test_species/Leaves/id-1.jpg")
    _file(candidates, "Test_species/Barks/id-1.jpg")
    rows = [
        {
            "candidate_id": "id-1",
            "scientific_name": "Test species",
            "file_path": "dataset/candidates/Test_species/unclassified/id-1.jpg",
            "sha256": sha256_for(first),
            "reviewed_plant_part": "bark",
        }
    ]

    report = reconcile_rows(
        rows,
        CandidatePathResolver(tmp_path, candidates),
        tmp_path,
        candidates,
        apply_changes=True,
    )

    assert report.changed == 1
    assert rows[0]["file_path"].endswith("/Barks/id-1.jpg")


def test_manifest_write_lock_blocks_a_second_writer_and_cleans_up(tmp_path: Path) -> None:
    manifest = tmp_path / "candidate_image_manifest.csv"
    manifest.write_text("candidate_id,file_path\n", encoding="utf-8")

    with candidate_manifest_write_lock(manifest):
        assert lock_path_for(manifest).is_file()
        with pytest.raises(CandidateManifestBusyError):
            with candidate_manifest_write_lock(manifest):
                pass

    assert not lock_path_for(manifest).exists()
    with candidate_manifest_write_lock(manifest):
        assert lock_path_for(manifest).is_file()

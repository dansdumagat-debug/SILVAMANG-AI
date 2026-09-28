from pathlib import Path

from scripts.candidate_manifest_paths import (
    CandidatePathResolver,
    candidate_part_hint,
    sha256_for,
)


def _write_image(root: Path, relative: str, payload: bytes = b"image") -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return path


def test_resolves_stale_manifest_path_by_candidate_id_and_hash(tmp_path: Path) -> None:
    candidate_root = tmp_path / "dataset" / "candidates"
    moved = _write_image(
        candidate_root,
        "Acanthus_ebracteatus/Leaves/gbif_123_0_deadbeef.jpg",
    )
    resolver = CandidatePathResolver(tmp_path, candidate_root)
    row = {
        "candidate_id": "gbif_123_0_deadbeef",
        "scientific_name": "Acanthus ebracteatus",
        "file_path": (
            "dataset/candidates/Acanthus_ebracteatus/unclassified/"
            "gbif_123_0_deadbeef.jpg"
        ),
        "sha256": sha256_for(moved),
    }

    assert resolver.resolve(row) == moved.resolve()
    assert candidate_part_hint(row, resolver.resolve_all(row)) == "leaves"


def test_rejects_same_name_when_hash_does_not_match(tmp_path: Path) -> None:
    candidate_root = tmp_path / "dataset" / "candidates"
    _write_image(
        candidate_root,
        "Acanthus_ebracteatus/Leaves/gbif_123_0_deadbeef.jpg",
        b"wrong-image",
    )
    resolver = CandidatePathResolver(tmp_path, candidate_root)
    row = {
        "candidate_id": "gbif_123_0_deadbeef",
        "scientific_name": "Acanthus ebracteatus",
        "file_path": "dataset/candidates/Acanthus_ebracteatus/unclassified/file.jpg",
        "sha256": "0" * 64,
    }

    assert resolver.resolve(row) is None


def test_resolution_stays_inside_recorded_species_folder(tmp_path: Path) -> None:
    candidate_root = tmp_path / "dataset" / "candidates"
    wrong_species = _write_image(
        candidate_root,
        "Other_species/Leaves/shared_candidate.jpg",
    )
    resolver = CandidatePathResolver(tmp_path, candidate_root)
    row = {
        "candidate_id": "shared_candidate",
        "scientific_name": "Expected species",
        "file_path": "dataset/candidates/Expected_species/unclassified/shared_candidate.jpg",
        "sha256": sha256_for(wrong_species),
    }

    assert resolver.resolve(row) is None


def test_reviewed_part_selects_matching_copy(tmp_path: Path) -> None:
    candidate_root = tmp_path / "dataset" / "candidates"
    leaves = _write_image(candidate_root, "Test_species/Leaves/candidate.jpg")
    bark = _write_image(candidate_root, "Test_species/Barks/candidate.jpg")
    resolver = CandidatePathResolver(tmp_path, candidate_root)
    row = {
        "candidate_id": "candidate",
        "scientific_name": "Test species",
        "file_path": "dataset/candidates/Test_species/unclassified/candidate.jpg",
        "sha256": sha256_for(leaves),
        "reviewed_plant_part": "bark",
    }

    assert resolver.resolve(row) == bark.resolve()
    assert candidate_part_hint(row, resolver.resolve_all(row)) == "bark"


def test_missing_hash_is_not_resolved_by_filename(tmp_path: Path) -> None:
    candidate_root = tmp_path / "dataset" / "candidates"
    _write_image(candidate_root, "Test_species/Leaves/candidate.jpg")
    resolver = CandidatePathResolver(tmp_path, candidate_root)

    assert resolver.resolve(
        {
            "candidate_id": "candidate",
            "scientific_name": "Test species",
            "file_path": "dataset/candidates/Test_species/Leaves/candidate.jpg",
            "sha256": "",
        }
    ) is None


def test_conflicting_path_part_hints_remain_unclassified(tmp_path: Path) -> None:
    candidate_root = tmp_path / "dataset" / "candidates"
    leaves = _write_image(candidate_root, "Test_species/Leaves/candidate.jpg")
    flowers = _write_image(candidate_root, "Test_species/Flowers/candidate.jpg")
    resolver = CandidatePathResolver(tmp_path, candidate_root)
    row = {
        "candidate_id": "candidate",
        "scientific_name": "Test species",
        "file_path": "dataset/candidates/Test_species/unclassified/candidate.jpg",
        "sha256": sha256_for(leaves),
    }

    assert sha256_for(leaves) == sha256_for(flowers)
    assert candidate_part_hint(row, resolver.resolve_all(row)) == ""

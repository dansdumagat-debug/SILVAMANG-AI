from __future__ import annotations

import csv
from pathlib import Path

import pytest

from scripts import collect_gbif_candidates as collector
from scripts.candidate_manifest_lock import (
    CandidateManifestBusyError,
    candidate_manifest_write_lock,
)


def _row(candidate_id: str) -> dict[str, str]:
    row = {field: "" for field in collector.MANIFEST_FIELDS}
    row.update(
        {
            "candidate_id": candidate_id,
            "file_path": f"dataset/candidates/unknown/unclassified/{candidate_id}.jpg",
            "scientific_name": "unknown",
            "source": "test",
            "source_record_id": candidate_id,
            "license": "CC0",
            "sha256": "a" * 64,
            "review_status": "pending",
        }
    )
    return row


def test_append_manifest_honors_shared_manifest_lock(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest = tmp_path / "dataset" / "metadata" / "candidate_image_manifest.csv"
    monkeypatch.setattr(collector, "MANIFEST_PATH", manifest)

    with candidate_manifest_write_lock(manifest):
        with pytest.raises(CandidateManifestBusyError):
            collector.append_manifest(_row("blocked"))

    assert not manifest.exists()
    collector.append_manifest(_row("accepted"))
    with manifest.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert [row["candidate_id"] for row in rows] == ["accepted"]


def test_append_manifest_keeps_one_header_across_calls(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest = tmp_path / "candidate_image_manifest.csv"
    monkeypatch.setattr(collector, "MANIFEST_PATH", manifest)

    collector.append_manifest(_row("one"))
    collector.append_manifest(_row("two"))

    lines = manifest.read_text(encoding="utf-8").splitlines()
    assert lines.count(",".join(collector.MANIFEST_FIELDS)) == 1
    with manifest.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert [row["candidate_id"] for row in rows] == ["one", "two"]


def test_append_manifest_atomically_upgrades_older_schema(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest = tmp_path / "candidate_image_manifest.csv"
    monkeypatch.setattr(collector, "MANIFEST_PATH", manifest)
    old_fields = tuple(
        field for field in collector.MANIFEST_FIELDS if field != "source_group_id"
    )
    old_row = {field: _row("old").get(field, "") for field in old_fields}
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=old_fields)
        writer.writeheader()
        writer.writerow(old_row)

    new_row = _row("new")
    new_row["source_group_id"] = "sequence-1"
    collector.append_manifest(new_row)

    with manifest.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        assert tuple(reader.fieldnames or ()) == collector.MANIFEST_FIELDS
    assert [row["candidate_id"] for row in rows] == ["old", "new"]
    assert rows[0]["source_group_id"] == ""
    assert rows[1]["source_group_id"] == "sequence-1"

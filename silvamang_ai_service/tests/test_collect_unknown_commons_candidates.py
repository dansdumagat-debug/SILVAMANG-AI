from __future__ import annotations

import csv
import io
from pathlib import Path

import pytest
from PIL import Image

from scripts import collect_unknown_commons_candidates as collector
from scripts.import_candidate_folders import create_import_plan


def _jpeg(color: tuple[int, int, int] = (60, 140, 90)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (420, 320), color).save(buffer, "JPEG", quality=90)
    return buffer.getvalue()


def _page(
    page_id: int,
    text: str,
    *,
    license_url: str = "https://creativecommons.org/licenses/by/4.0/",
    artist: str = "Example Photographer",
    credit: str = "Example Credit",
) -> dict:
    return {
        "pageid": page_id,
        "title": f"File:{text}_{page_id}.jpg",
        "imageinfo": [
            {
                "mime": "image/jpeg",
                "thumburl": f"https://upload.wikimedia.org/example/{page_id}.jpg",
                "url": f"https://upload.wikimedia.org/original/{page_id}.jpg",
                "extmetadata": {
                    "ObjectName": {"value": text},
                    "ImageDescription": {"value": f"A photograph of {text}"},
                    "Categories": {"value": text},
                    "Artist": {"value": artist},
                    "Credit": {"value": credit},
                    "LicenseUrl": {"value": license_url},
                    "LicenseShortName": {
                        "value": "CC BY 4.0"
                        if "creativecommons.org" in license_url
                        else license_url
                    },
                },
            }
        ],
    }


def _paths(root: Path) -> dict[str, Path]:
    return {
        "project_root": root,
        "incoming_root": root / "dataset" / "incoming" / "unknown",
        "candidate_root": root / "dataset" / "candidates",
        "queue_path": root / "dataset" / "metadata" / "unknown_commons_review_queue.csv",
        "manifest_path": root / "dataset" / "metadata" / "candidate_image_manifest.csv",
        "image_manifest_path": root / "dataset" / "metadata" / "image_manifest.csv",
        "contact_root": root / "dataset" / "review" / "unknown_contact_sheets",
        "raw_root": root / "dataset" / "raw",
    }


def _review_paths(paths: dict[str, Path]) -> dict[str, Path]:
    return {
        "project_root": paths["project_root"],
        "incoming_root": paths["incoming_root"],
        "rejected_root": paths["project_root"]
        / "dataset"
        / "review"
        / "rejected_unknown",
        "queue_path": paths["queue_path"],
        "manifest_path": paths["manifest_path"],
        "contact_root": paths["contact_root"],
    }


def _rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _mock_download(monkeypatch: pytest.MonkeyPatch, pages: list[dict]) -> None:
    monkeypatch.setattr(collector, "commons_pages", lambda query, maximum: iter(pages))
    payloads = {
        str(page["imageinfo"][0]["thumburl"]): _jpeg((50 + index * 20, 130, 90))
        for index, page in enumerate(pages)
    }
    monkeypatch.setattr(
        collector,
        "download_commons_image",
        lambda url: (payloads[url], ".jpg"),
    )


def test_filters_mangroves_nipa_nonphotos_and_nonfree_media() -> None:
    assert collector.is_acceptable_page(_page(1, "Cocos nucifera"), "coconut")[0]
    assert not collector.is_acceptable_page(
        _page(2, "Cocos nucifera beside a mangrove"), "coconut"
    )[0]
    assert not collector.is_acceptable_page(
        _page(3, "Nypa fruticans nipa palm and coconut"), "coconut"
    )[0]
    assert not collector.is_acceptable_page(
        _page(4, "Cocos nucifera botanical illustration"), "coconut"
    )[0]
    assert not collector.is_acceptable_page(
        _page(5, "Cocos nucifera", license_url="All rights reserved"), "coconut"
    )[0]
    assert not collector.is_acceptable_page(
        _page(6, "Cocos nucifera", artist="", credit=""), "coconut"
    )[0]
    contradictory = _page(7, "Cocos nucifera")
    contradictory["imageinfo"][0]["extmetadata"]["LicenseShortName"] = {
        "value": "All rights reserved"
    }
    assert not collector.is_acceptable_page(contradictory, "coconut")[0]


def test_nipa_category_is_explicitly_rejected() -> None:
    with pytest.raises(ValueError, match="supported mangrove"):
        collector.selected_categories(["nipa"])
    with pytest.raises(ValueError, match="supported mangrove"):
        collector.selected_categories(["Nypa fruticans"])


def test_default_audit_does_not_write_files(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(collector, "commons_pages", lambda query, maximum: iter([]))

    exit_code = collector.main(
        [
            "--project-root",
            str(tmp_path),
            "--category",
            "coconut",
            "--max-search-results",
            "1",
        ]
    )

    assert exit_code == 0
    assert not (tmp_path / "dataset").exists()


def test_download_writes_only_review_queue_and_contact_sheet(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [_page(101, "Cocos nucifera")]
    _mock_download(monkeypatch, pages)

    additions, sheets = collector.download_candidates(
        ["coconut"], 1, 10, **paths
    )

    assert len(additions) == 1
    queue_rows = _rows(paths["queue_path"])
    assert queue_rows[0]["queue_status"] == "pending_review"
    assert queue_rows[0]["review_status"] == "pending"
    assert queue_rows[0]["license"].startswith("https://creativecommons.org/")
    assert (tmp_path / queue_rows[0]["file_path"]).is_file()
    assert sheets == [paths["contact_root"] / "coconut.jpg"]
    assert sheets[0].is_file()
    assert not paths["manifest_path"].exists()
    assert not paths["candidate_root"].exists()

    # The target is cumulative: an accepted/promoted queue row continues to
    # count after its incoming copy is moved.
    second, _ = collector.download_candidates(["coconut"], 1, 10, **paths)
    assert second == []


def test_download_queue_failure_rolls_back_new_incoming_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(111, "Cocos nucifera")])
    monkeypatch.setattr(
        collector,
        "write_csv_atomic",
        lambda *args, **kwargs: (_ for _ in ()).throw(OSError("queue unavailable")),
    )

    with pytest.raises(OSError, match="queue unavailable"):
        collector.download_candidates(["coconut"], 1, 10, **paths)

    assert not list(paths["incoming_root"].rglob("*.jpg"))
    assert not paths["queue_path"].exists()


def test_midstream_api_failure_keeps_downloaded_file_tracked(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    page = _page(115, "Cocos nucifera")

    def interrupted_pages(query, maximum):
        yield page
        raise OSError("Commons interrupted")

    monkeypatch.setattr(collector, "commons_pages", interrupted_pages)
    monkeypatch.setattr(
        collector, "download_commons_image", lambda url: (_jpeg(), ".jpg")
    )

    with pytest.raises(OSError, match="Commons interrupted"):
        collector.download_candidates(["coconut"], 2, 10, **paths)

    rows = _rows(paths["queue_path"])
    assert len(rows) == 1
    assert (tmp_path / rows[0]["file_path"]).is_file()


def test_long_image_cooldown_stops_and_keeps_prior_checkpoint(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [_page(116, "Cocos nucifera"), _page(117, "Cocos nucifera")]
    monkeypatch.setattr(collector, "commons_pages", lambda query, maximum: iter(pages))

    def download(url: str) -> tuple[bytes, str]:
        if url == pages[1]["imageinfo"][0]["thumburl"]:
            raise collector.CommonsCooldownError("Wikimedia Commons image server", 600)
        return _jpeg(), ".jpg"

    monkeypatch.setattr(collector, "download_commons_image", download)

    with pytest.raises(collector.CommonsCooldownError, match=r"600s.*resume"):
        collector.download_candidates(["coconut"], 2, 10, **paths)

    rows = _rows(paths["queue_path"])
    assert [row["source_record_id"] for row in rows] == ["commons:116"]
    assert (tmp_path / rows[0]["file_path"]).is_file()


def test_download_deduplicates_against_raw_tree_and_secondary_manifest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    page = _page(121, "Cocos nucifera")
    payload = _jpeg()
    raw = paths["raw_root"] / "Cocos_nucifera" / "same.jpg"
    raw.parent.mkdir(parents=True)
    raw.write_bytes(payload)
    monkeypatch.setattr(collector, "commons_pages", lambda query, maximum: iter([page]))
    monkeypatch.setattr(
        collector, "download_commons_image", lambda url: (payload, ".jpg")
    )

    additions, _ = collector.download_candidates(["coconut"], 1, 10, **paths)
    assert additions == []

    raw.unlink()
    _write_csv(
        paths["image_manifest_path"],
        ["source_record_id", "source_image_url", "sha256"],
        [
            {
                "source_record_id": "commons:121",
                "source_image_url": page["imageinfo"][0]["thumburl"],
                "sha256": "f" * 64,
            }
        ],
    )
    additions, _ = collector.download_candidates(["coconut"], 1, 10, **paths)
    assert additions == []


def test_promote_uses_remaining_files_and_is_idempotent(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [_page(201, "Cocos nucifera"), _page(202, "Cocos nucifera")]
    _mock_download(monkeypatch, pages)
    collector.download_candidates(["coconut"], 2, 10, **paths)
    queue_before = _rows(paths["queue_path"])
    rejected = tmp_path / queue_before[1]["file_path"]
    rejected.unlink()

    promoted = collector.promote_reviewed(**paths)

    assert len(promoted) == 1
    manifest_rows = _rows(paths["manifest_path"])
    assert len(manifest_rows) == 1
    row = manifest_rows[0]
    assert row["scientific_name"] == "unknown"
    assert row["reviewed_plant_part"] == "unclassified"
    assert row["review_status"] == "approved"
    assert row["source_record_id"] == "commons:201"
    assert row["creator"] == "Example Photographer"
    assert row["license"] == "https://creativecommons.org/licenses/by/4.0/"
    candidate = tmp_path / row["file_path"]
    assert candidate.is_file()
    assert not (tmp_path / queue_before[0]["file_path"]).exists()
    statuses = {item["source_record_id"]: item["queue_status"] for item in _rows(paths["queue_path"])}
    assert statuses == {"commons:201": "promoted", "commons:202": "pending_review"}

    assert collector.promote_reviewed(
        **paths
    ) == []
    assert len(_rows(paths["manifest_path"])) == 1


def test_promote_honors_selected_categories(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [_page(211, "Cocos nucifera"), _page(212, "Musa acuminata")]
    monkeypatch.setattr(
        collector,
        "commons_pages",
        lambda query, maximum: iter([pages[1] if "Musa" in query else pages[0]]),
    )
    payloads = {
        page["imageinfo"][0]["thumburl"]: _jpeg((80 + index * 40, 120, 90))
        for index, page in enumerate(pages)
    }
    monkeypatch.setattr(
        collector, "download_commons_image", lambda url: (payloads[url], ".jpg")
    )
    collector.download_candidates(["coconut", "banana"], 1, 10, **paths)

    collector.promote_reviewed(
        categories=["coconut"],
        **paths,
    )

    rows = _rows(paths["queue_path"])
    statuses = {row["unknown_category"]: row["queue_status"] for row in rows}
    assert statuses == {"coconut": "promoted", "banana": "pending_review"}


def test_promotion_preserves_grouping_for_blur_and_dark_variants(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(301, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)

    promoted = collector.promote_reviewed(
        blur_variants=1,
        dark_variants=1,
        **paths,
    )

    assert len(promoted) == 3
    rows = _rows(paths["manifest_path"])
    assert len(rows) == 3
    assert {row["source_record_id"] for row in rows} == {"commons:301"}
    assert {row["source"] for row in rows} == {collector.SOURCE_NAME}
    assert {row["license"] for row in rows} == {
        "https://creativecommons.org/licenses/by/4.0/"
    }
    assert len({row["sha256"] for row in rows}) == 3
    assert any("Derived blur" in row["review_notes"] for row in rows)
    assert any("Derived dark" in row["review_notes"] for row in rows)
    assert not any("blur" in Path(row["file_path"]).stem and "dark" in Path(row["file_path"]).stem for row in rows)


def test_promotion_preserves_unique_provenance_and_shared_source_group(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [_page(311, "Cocos nucifera"), _page(312, "Cocos nucifera")]
    _mock_download(monkeypatch, pages)
    collector.download_candidates(["coconut"], 2, 10, **paths)

    queued = _rows(paths["queue_path"])
    for row in queued:
        row["source_group_id"] = "commons:sequence:coconut-example"
    _write_csv(paths["queue_path"], list(collector.QUEUE_FIELDS), queued)

    collector.promote_reviewed(**paths)

    manifest_rows = _rows(paths["manifest_path"])
    assert {row["source_record_id"] for row in manifest_rows} == {
        "commons:311",
        "commons:312",
    }
    assert len({row["source_record_url"] for row in manifest_rows}) == 2
    assert {row["source_group_id"] for row in manifest_rows} == {
        "commons:sequence:coconut-example"
    }

    promoted_queue = _rows(paths["queue_path"])
    assert {row["review_status"] for row in promoted_queue} == {"approved"}
    assert all(row["reviewed_at"] for row in promoted_queue)
    assert len({row["source_record_id"] for row in promoted_queue}) == 2


def test_variant_selection_round_robins_categories_without_chaining(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [
        _page(501, "Cocos nucifera"),
        _page(502, "Cocos nucifera"),
        _page(503, "Cocos nucifera"),
        _page(601, "Musa acuminata"),
        _page(701, "Cynodon dactylon grass"),
    ]
    _mock_download(monkeypatch, pages)
    collector.download_candidates(
        ["coconut", "banana", "grass"], 3, 10, **paths
    )

    promoted = collector.promote_reviewed(
        blur_variants=4,
        dark_variants=4,
        **paths,
    )

    assert len(promoted) == 13
    rows = _rows(paths["manifest_path"])
    base_rows = [row for row in rows if "Derived " not in row["review_notes"]]
    blur_rows = [row for row in rows if "Derived blur" in row["review_notes"]]
    dark_rows = [row for row in rows if "Derived dark" in row["review_notes"]]
    assert len(base_rows) == 5
    assert len(blur_rows) == len(dark_rows) == 4

    # Four selections across three categories must take one from every category
    # before returning to the category with additional source images.
    for variants in (blur_rows, dark_rows):
        category_counts = {
            category: sum(
                f"/unknown/unclassified/{category}/derived/" in row["file_path"]
                for row in variants
            )
            for category in ("coconut", "banana", "grass")
        }
        assert category_counts == {"coconut": 2, "banana": 1, "grass": 1}

    expected_sources = {"commons:501", "commons:502", "commons:601", "commons:701"}
    assert {row["source_record_id"] for row in blur_rows} == expected_sources
    assert {row["source_record_id"] for row in dark_rows} == expected_sources

    base_by_id = {row["candidate_id"]: row for row in base_rows}
    for derived in [*blur_rows, *dark_rows]:
        kind = "blur" if "Derived blur" in derived["review_notes"] else "dark"
        base_id = derived["candidate_id"].rsplit(f"_{kind}", 1)[0]
        base = base_by_id[base_id]
        assert derived["source_record_id"] == base["source_record_id"]
        assert derived["source_image_url"] == base["source_image_url"]
        assert "/derived/" not in base["file_path"]
        assert not (
            "_blur" in Path(derived["file_path"]).stem
            and "_dark" in Path(derived["file_path"]).stem
        )


def test_promotion_recovers_when_queue_update_failed_after_manifest_commit(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(351, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    original_writer = collector.write_csv_atomic

    def fail_queue(path, fieldnames, rows):
        if path == paths["queue_path"]:
            raise OSError("queue update failed")
        return original_writer(path, fieldnames, rows)

    monkeypatch.setattr(collector, "write_csv_atomic", fail_queue)
    with pytest.raises(OSError, match="queue update failed"):
        collector.promote_reviewed(
            **paths
        )

    queue_row = _rows(paths["queue_path"])[0]
    assert queue_row["queue_status"] == "pending_review"
    assert (tmp_path / queue_row["file_path"]).is_file()
    assert len(_rows(paths["manifest_path"])) == 1

    monkeypatch.setattr(collector, "write_csv_atomic", original_writer)
    assert collector.promote_reviewed(
        **paths
    ) == []
    recovered = _rows(paths["queue_path"])[0]
    assert recovered["queue_status"] == "promoted"
    assert not (tmp_path / recovered["file_path"]).exists()


def test_manifest_failure_rolls_back_candidate_copy(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(361, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    incoming = tmp_path / _rows(paths["queue_path"])[0]["file_path"]
    monkeypatch.setattr(
        collector,
        "_merge_manifest_rows_atomic",
        lambda *args, **kwargs: (_ for _ in ()).throw(OSError("manifest failed")),
    )

    with pytest.raises(OSError, match="manifest failed"):
        collector.promote_reviewed(
            **paths
        )

    assert incoming.is_file()
    assert not list(paths["candidate_root"].rglob("*.jpg"))


def test_copy_failure_after_first_candidate_rolls_back_created_outputs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [_page(371, "Cocos nucifera"), _page(372, "Cocos nucifera")]
    _mock_download(monkeypatch, pages)
    collector.download_candidates(["coconut"], 2, 10, **paths)
    original_copy = collector._copy_atomic
    calls = 0

    def fail_second(source, destination):
        nonlocal calls
        calls += 1
        if calls == 2:
            raise OSError("copy failed")
        original_copy(source, destination)

    monkeypatch.setattr(collector, "_copy_atomic", fail_second)
    with pytest.raises(OSError, match="copy failed"):
        collector.promote_reviewed(**paths)

    assert not list(paths["candidate_root"].rglob("*.jpg"))
    assert len(list(paths["incoming_root"].rglob("*.jpg"))) == 2


def test_hash_failure_after_first_candidate_rolls_back_created_outputs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    pages = [_page(381, "Cocos nucifera"), _page(382, "Cocos nucifera")]
    _mock_download(monkeypatch, pages)
    collector.download_candidates(["coconut"], 2, 10, **paths)
    queue_rows = _rows(paths["queue_path"])
    second_incoming = (tmp_path / queue_rows[1]["file_path"]).resolve()
    original_hash = collector.sha256_file

    def fail_second_incoming(path: Path) -> str:
        if Path(path).resolve() == second_incoming:
            raise OSError("hash read failed")
        return original_hash(path)

    monkeypatch.setattr(collector, "sha256_file", fail_second_incoming)
    with pytest.raises(OSError, match="hash read failed"):
        collector.promote_reviewed(**paths)

    assert not list(paths["candidate_root"].rglob("*.jpg"))
    assert len(list(paths["incoming_root"].rglob("*.jpg"))) == 2
    assert not paths["manifest_path"].exists()


def test_promoted_nested_unknown_category_is_importer_compatible(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(401, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    collector.promote_reviewed(
        **paths
    )

    plan = create_import_plan(
        paths["candidate_root"], paths["manifest_path"], tmp_path
    )

    assert len(plan.rows) == 1
    assert plan.rows[0]["scientific_name"] == "unknown"
    assert plan.rows[0]["reviewed_plant_part"] == "unclassified"
    assert plan.rows[0]["review_status"] == "approved"
    assert "/unknown/unclassified/coconut/" in plan.rows[0]["file_path"]


def test_cli_rejects_write_paths_outside_project(tmp_path: Path) -> None:
    outside = tmp_path.parent / "outside-unknown-queue"
    assert collector.main(
        [
            "--project-root",
            str(tmp_path),
            "--download",
            "--category",
            "coconut",
            "--incoming-root",
            str(outside),
        ]
    ) == 2


def test_image_validation_enforces_decoded_pixel_ceiling(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(collector, "MAX_DECODED_PIXELS", 100)
    with pytest.raises(ValueError, match="decoded image is too large"):
        collector.verify_image_payload(_jpeg())


def test_review_reclassifies_pending_file_and_preserves_provenance(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(801, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    before = _rows(paths["queue_path"])[0]
    old_path = tmp_path / before["file_path"]
    provenance_fields = (
        "candidate_id",
        "source",
        "source_record_id",
        "source_record_url",
        "source_image_url",
        "creator",
        "rights_holder",
        "license",
        "sha256",
        "search_query",
    )

    result = collector.review_queue_candidate(
        before["candidate_id"],
        action="reclassify",
        target_category="banana",
        reason="The photograph is a banana plant.",
        **_review_paths(paths),
    )

    after = _rows(paths["queue_path"])[0]
    new_path = tmp_path / after["file_path"]
    assert result["unknown_category"] == after["unknown_category"] == "banana"
    assert after["queue_status"] == "pending_review"
    assert not old_path.exists()
    assert new_path.is_file()
    assert new_path.parent == paths["incoming_root"] / "banana"
    assert after["reviewed_at"]
    assert "reclassified unknown category from coconut to banana" in after["review_notes"]
    assert all(after[field] == before[field] for field in provenance_fields)
    assert (paths["contact_root"] / "banana.jpg").is_file()
    assert not (paths["contact_root"] / "coconut.jpg").exists()

    # Repeating the same category correction is a no-op.
    reviewed_at = after["reviewed_at"]
    again = collector.review_queue_candidate(
        before["candidate_id"],
        action="reclassify",
        target_category="banana",
        **_review_paths(paths),
    )
    assert again["reviewed_at"] == reviewed_at
    assert new_path.is_file()


def test_review_rejects_pending_file_idempotently_and_never_promotes_it(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(811, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    before = _rows(paths["queue_path"])[0]
    old_path = tmp_path / before["file_path"]

    first = collector.review_queue_candidate(
        before["candidate_id"],
        action="reject",
        reason="A supported mangrove is visible.",
        **_review_paths(paths),
    )
    rejected_path = tmp_path / first["file_path"]
    assert first["queue_status"] == first["review_status"] == "rejected"
    assert not old_path.exists()
    assert rejected_path.is_file()
    assert rejected_path.parent == _review_paths(paths)["rejected_root"] / "coconut"
    assert collector._category_count(_rows(paths["queue_path"]), "coconut", tmp_path) == 0

    second = collector.review_queue_candidate(
        before["candidate_id"], action="reject", **_review_paths(paths)
    )
    assert second == _rows(paths["queue_path"])[0]
    assert collector.promote_reviewed(**paths) == []
    assert _rows(paths["manifest_path"]) == []
    with pytest.raises(ValueError, match="cannot be reclassified"):
        collector.review_queue_candidate(
            before["candidate_id"],
            action="reclassify",
            target_category="banana",
            **_review_paths(paths),
        )


def test_review_refuses_promoted_or_manifest_committed_candidates(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(821, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    candidate_id = _rows(paths["queue_path"])[0]["candidate_id"]
    collector.promote_reviewed(**paths)
    promoted = tmp_path / _rows(paths["manifest_path"])[0]["file_path"]

    with pytest.raises(ValueError, match="already promoted"):
        collector.review_queue_candidate(
            candidate_id, action="reject", **_review_paths(paths)
        )
    assert promoted.is_file()


def test_review_rejects_unsafe_queue_and_output_paths(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(831, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    row = _rows(paths["queue_path"])[0]
    original = tmp_path / row["file_path"]
    outside_incoming = tmp_path / "outside.jpg"
    outside_incoming.write_bytes(original.read_bytes())
    row["file_path"] = "outside.jpg"
    _write_csv(paths["queue_path"], list(collector.QUEUE_FIELDS), [row])

    with pytest.raises(ValueError, match="outside its incoming category"):
        collector.review_queue_candidate(
            row["candidate_id"], action="reject", **_review_paths(paths)
        )
    assert outside_incoming.is_file()
    assert original.is_file()

    review_paths = _review_paths(paths)
    review_paths["rejected_root"] = tmp_path.parent / "outside-rejected"
    with pytest.raises(ValueError, match="inside the project root"):
        collector.review_queue_candidate(
            row["candidate_id"], action="reject", **review_paths
        )


def test_review_queue_write_failure_rolls_back_file_move(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    paths = _paths(tmp_path)
    _mock_download(monkeypatch, [_page(841, "Cocos nucifera")])
    collector.download_candidates(["coconut"], 1, 10, **paths)
    before = _rows(paths["queue_path"])[0]
    source = tmp_path / before["file_path"]
    destination = paths["incoming_root"] / "banana" / source.name
    monkeypatch.setattr(
        collector,
        "write_csv_atomic",
        lambda *args, **kwargs: (_ for _ in ()).throw(OSError("queue write failed")),
    )

    with pytest.raises(OSError, match="queue write failed"):
        collector.review_queue_candidate(
            before["candidate_id"],
            action="reclassify",
            target_category="banana",
            **_review_paths(paths),
        )

    assert source.is_file()
    assert not destination.exists()
    after = _rows(paths["queue_path"])[0]
    assert after["unknown_category"] == "coconut"
    assert after["file_path"] == before["file_path"]


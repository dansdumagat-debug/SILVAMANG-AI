from __future__ import annotations

import argparse
import csv
import hashlib
import io
import os
import re
import shutil
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import wraps
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Any, Iterable, Mapping, Sequence

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


AI_SERVICE_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = AI_SERVICE_ROOT.parent
SCRIPTS_ROOT = Path(__file__).resolve().parent
if str(AI_SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_SERVICE_ROOT))
if str(SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_ROOT))

try:  # pragma: no cover - import shape differs for CLI and tests
    from .candidate_manifest_lock import (
        CandidateManifestBusyError,
        candidate_manifest_write_lock,
    )
    from .collect_commons_part_candidates import (
        SUPPORTED_MIME_TYPES,
        COMMONS_THUMBNAIL_WIDTH,
        CommonsCooldownError,
        candidate_text,
        commons_license,
        download_commons_image,
        metadata_value,
        plain_text,
        request_json,
        source_page_url,
    )
    from .collect_gbif_candidates import license_is_allowed
except ImportError:  # pragma: no cover
    from candidate_manifest_lock import (
        CandidateManifestBusyError,
        candidate_manifest_write_lock,
    )
    from collect_commons_part_candidates import (
        SUPPORTED_MIME_TYPES,
        COMMONS_THUMBNAIL_WIDTH,
        CommonsCooldownError,
        candidate_text,
        commons_license,
        download_commons_image,
        metadata_value,
        plain_text,
        request_json,
        source_page_url,
    )
    from collect_gbif_candidates import license_is_allowed


DEFAULT_INCOMING_ROOT = PROJECT_ROOT / "dataset" / "incoming" / "unknown"
DEFAULT_CANDIDATE_ROOT = PROJECT_ROOT / "dataset" / "candidates"
DEFAULT_QUEUE_PATH = (
    PROJECT_ROOT / "dataset" / "metadata" / "unknown_commons_review_queue.csv"
)
DEFAULT_MANIFEST_PATH = (
    PROJECT_ROOT / "dataset" / "metadata" / "candidate_image_manifest.csv"
)
DEFAULT_IMAGE_MANIFEST_PATH = PROJECT_ROOT / "dataset" / "metadata" / "image_manifest.csv"
DEFAULT_CONTACT_ROOT = PROJECT_ROOT / "dataset" / "review" / "unknown_contact_sheets"
DEFAULT_REJECTED_ROOT = PROJECT_ROOT / "dataset" / "review" / "rejected_unknown"
DEFAULT_RAW_ROOT = PROJECT_ROOT / "dataset" / "raw"

MANIFEST_FIELDS = (
    "candidate_id",
    "file_path",
    "scientific_name",
    "reviewed_plant_part",
    "source",
    "source_record_id",
    "source_group_id",
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
QUEUE_FIELDS = MANIFEST_FIELDS + (
    "unknown_category",
    "search_query",
    "queue_status",
    "promoted_file_path",
    "promoted_at",
    "reviewed_at",
)

SOURCE_NAME = "Wikimedia Commons unknown-class search"
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MIN_IMAGE_SIDE = 256
MAX_DECODED_PIXELS = 40_000_000
MAX_CONTACT_IMAGES = 60


@dataclass(frozen=True)
class CategorySpec:
    queries: tuple[str, ...]
    required_patterns: tuple[str, ...]


# Plant searches use exact non-mangrove taxa. Papaya is the safe replacement for
# the requested nipa category: Nypa fruticans is a supported mangrove class and
# must never be used as an unknown negative. Scene searches remain broad but are
# screened again by metadata and then by a human-facing contact sheet.
CATEGORY_SPECS: Mapping[str, CategorySpec] = {
    "coconut": CategorySpec(
        (
            '"Cocos nucifera" palm tree photograph',
            '"Cocos nucifera" fruit photograph',
        ),
        (r"\bcocos nucifera\b", r"\bcoconut\b"),
    ),
    "banana": CategorySpec(('"Musa acuminata" photograph',), (r"\bmusa acuminata\b", r"\bbanana plant\b")),
    "grass": CategorySpec(('"Cynodon dactylon" photograph',), (r"\bcynodon dactylon\b", r"\bgrass\b")),
    "shrubs": CategorySpec(('"Hibiscus rosa-sinensis" photograph',), (r"\bhibiscus rosa[ -]sinensis\b", r"\bhibiscus\b")),
    "ordinary_trees": CategorySpec(('"Mangifera indica" tree photograph',), (r"\bmangifera indica\b", r"\bmango tree\b")),
    "papaya": CategorySpec(('"Carica papaya" photograph',), (r"\bcarica papaya\b", r"\bpapaya\b")),
    "sand": CategorySpec(('"sandy beach" photograph',), (r"\bsand(?:y)?\b", r"\bbeach\b")),
    # Prefer ordinary terrestrial scenes. Generic "rock outcrop" searches also
    # return Mars rover imagery, while "open water" is the name of a public-art
    # photo series whose main subject is electricity pylons.
    "rocks": CategorySpec(
        ('"granite rocks" landscape photograph', '"rocky landscape" photograph'),
        (r"\bgranite\b", r"\brocks?\b", r"\brocky\b"),
    ),
    "water": CategorySpec(
        ("lake water landscape photograph", "river water landscape photograph"),
        (r"\blakes?\b", r"\brivers?\b", r"\bwater(?: surface)?\b"),
    ),
    "buildings": CategorySpec(('"building exterior" photograph',), (r"\bbuilding\b", r"\barchitecture\b")),
    "people": CategorySpec(
        ('"outdoor portrait" person photograph',),
        (r"\bpeople\b", r"\bperson\b", r"\bportrait\b"),
    ),
    "boats": CategorySpec(('"boat on water" photograph',), (r"\bboats?\b",)),
    "unrelated_objects": CategorySpec(('"bicycle" photograph',), (r"\bbicycles?\b",)),
}

MANGROVE_BLOCK_PATTERNS = tuple(
    re.compile(pattern)
    for pattern in (
        r"\bmangroves?\b",
        r"\bnypa\b",
        r"\bnipa\b",
        r"\brhizophora\b",
        r"\bavicennia\b",
        r"\bbruguiera\b",
        r"\bceriops\b",
        r"\bexcoecaria\b",
        r"\bsonneratia\b",
        r"\bxylocarpus\b",
        r"\bacanthus\b",
        r"\baegiceras\b",
        r"\bcamptostemon\b",
        r"\bheritiera\b",
        r"\blumnitzera\b",
        r"\bosbornia\b",
        r"\bpemphis\b",
        r"\bscyphiphora\b",
    )
)
NONPHOTO_BLOCK_PATTERNS = tuple(
    re.compile(pattern)
    for pattern in (
        r"\b(?:botanical )?illustration\b",
        r"\bdrawing\b",
        r"\bdiagram\b",
        r"\bdistribution map\b",
        r"\brange map\b",
        r"\blogo\b",
        r"\bicon\b",
        r"\bherbarium\b",
        r"\bpressed specimen\b",
        r"\bpainting\b",
        r"\bengraving\b",
        r"\bposter\b",
        r"\bcoat of arms\b",
        r"\bbook page\b",
    )
)
RESTRICTED_RIGHTS_PATTERNS = tuple(
    re.compile(pattern)
    for pattern in (
        r"\ball rights reserved\b",
        r"\bnon[ -]?commercial\b",
        r"\bno derivatives?\b",
        r"\bcc[ -]?by[ -]?nc\b",
        r"\bcc[ -]?by[ -]?nd\b",
        r"\bfair use\b",
    )
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def relative_path(path: Path, project_root: Path) -> str:
    return path.resolve().relative_to(project_root.resolve()).as_posix()


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def _write_csv_unlocked(
    path: Path, fieldnames: Sequence[str], rows: Sequence[Mapping[str, str]]
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(
        "w",
        encoding="utf-8",
        newline="",
        dir=path.parent,
        prefix=f".{path.stem}_",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        writer = csv.DictWriter(temporary, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
        temporary_path = Path(temporary.name)
    try:
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def write_csv_atomic(
    path: Path, fieldnames: Sequence[str], rows: Sequence[Mapping[str, str]]
) -> None:
    with candidate_manifest_write_lock(path):
        _write_csv_unlocked(path, fieldnames, rows)


def serialized_queue_operation(function):
    """Serialize download and promotion around the same review queue.

    The per-file CSV locks protect atomic replacements. This wider lock also
    prevents two processes from acting on stale queue snapshots or deleting a
    deterministic image path committed by the other process.
    """

    @wraps(function)
    def wrapped(*args, **kwargs):
        queue_path = Path(kwargs.get("queue_path", DEFAULT_QUEUE_PATH)).resolve()
        workflow_target = queue_path.with_name(f"{queue_path.name}.workflow")
        with candidate_manifest_write_lock(workflow_target):
            return function(*args, **kwargs)

    return wrapped


def commons_pages(query: str, max_results: int) -> Iterable[dict[str, Any]]:
    checked = 0
    offset: int | None = None
    while checked < max_results:
        limit = min(50, max_results - checked)
        params: dict[str, Any] = {
            "action": "query",
            "format": "json",
            "formatversion": "2",
            "maxlag": 5,
            "generator": "search",
            "gsrsearch": query,
            "gsrnamespace": 6,
            "gsrlimit": limit,
            "prop": "imageinfo",
            "iiprop": "url|extmetadata|mime|size",
            "iiurlwidth": COMMONS_THUMBNAIL_WIDTH,
        }
        if offset is not None:
            params["gsroffset"] = offset
        payload = request_json(params)
        pages = payload.get("query", {}).get("pages") or []
        checked += len(pages)
        yield from pages
        next_offset = payload.get("continue", {}).get("gsroffset")
        if next_offset is None or not pages:
            break
        offset = int(next_offset)
        time.sleep(1.1)


def is_acceptable_page(
    page: Mapping[str, Any], category: str
) -> tuple[bool, str, dict[str, Any] | None]:
    spec = CATEGORY_SPECS[category]
    image_infos = page.get("imageinfo") or []
    if not image_infos:
        return False, "missing image metadata", None
    image_info = image_infos[0]
    if str(image_info.get("mime") or "").casefold() not in SUPPORTED_MIME_TYPES:
        return False, "unsupported MIME type", image_info
    metadata = image_info.get("extmetadata") or {}
    rights_text = " ".join(
        plain_text(metadata_value(metadata, key)).casefold()
        for key in (
            "LicenseUrl",
            "LicenseShortName",
            "UsageTerms",
            "Restrictions",
            "Copyright",
        )
    )
    if any(pattern.search(rights_text) for pattern in RESTRICTED_RIGHTS_PATTERNS):
        return False, "contradictory or restricted rights metadata", image_info
    if not commons_license(metadata):
        return False, "license is not reusable", image_info
    attribution = " ".join(
        plain_text(metadata_value(metadata, key))
        for key in ("Artist", "Credit", "Attribution", "RightsHolder")
    ).strip()
    if not attribution:
        return False, "missing creator or rights-holder metadata", image_info
    text = candidate_text(dict(page), image_info)
    if any(pattern.search(text) for pattern in MANGROVE_BLOCK_PATTERNS):
        return False, "mangrove term present", image_info
    if any(pattern.search(text) for pattern in NONPHOTO_BLOCK_PATTERNS):
        return False, "non-photo metadata", image_info
    if not any(re.search(pattern, text) for pattern in spec.required_patterns):
        return False, "category term missing", image_info
    image_url = str(image_info.get("thumburl") or image_info.get("url") or "").strip()
    if not image_url.startswith(("https://", "http://")):
        return False, "missing HTTP image URL", image_info
    return True, "", image_info


def verify_image_payload(payload: bytes, minimum_side: int = MIN_IMAGE_SIDE) -> tuple[int, int]:
    try:
        with Image.open(io.BytesIO(payload)) as image:
            width, height = image.size
            if width * height > MAX_DECODED_PIXELS:
                raise ValueError(
                    f"decoded image is too large ({width}x{height}); "
                    f"limit is {MAX_DECODED_PIXELS} pixels"
                )
            image.verify()
        with Image.open(io.BytesIO(payload)) as image:
            width, height = image.size
    except (OSError, ValueError, Image.DecompressionBombError) as exc:
        raise ValueError(f"image cannot be decoded: {exc}") from exc
    if min(width, height) < minimum_side:
        raise ValueError(
            f"image is too small ({width}x{height}); minimum side is {minimum_side}px"
        )
    return width, height


def _existing_identifiers(rows: Iterable[Mapping[str, str]]) -> tuple[set[str], set[str], set[str]]:
    records: set[str] = set()
    urls: set[str] = set()
    hashes: set[str] = set()
    for row in rows:
        record = str(row.get("source_record_id") or "").strip()
        url = str(row.get("source_image_url") or "").strip()
        digest = str(row.get("sha256") or "").strip().casefold()
        if record:
            records.add(record)
        if url:
            urls.add(url)
        if re.fullmatch(r"[0-9a-f]{64}", digest):
            hashes.add(digest)
    return records, urls, hashes


def scan_tree_hashes(root: Path) -> dict[str, list[Path]]:
    by_hash: dict[str, list[Path]] = {}
    if not root.is_dir():
        return by_hash
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix().casefold()):
        if (
            not path.is_file()
            or path.is_symlink()
            or path.suffix.casefold() not in SUPPORTED_EXTENSIONS
        ):
            continue
        resolved = path.resolve()
        if not _is_within(resolved, root):
            continue
        try:
            digest = sha256_file(resolved)
        except OSError:
            continue
        by_hash.setdefault(digest, []).append(resolved)
    return by_hash


def _category_count(rows: Iterable[Mapping[str, str]], category: str, project_root: Path) -> int:
    count = 0
    for row in rows:
        if str(row.get("unknown_category") or "") != category:
            continue
        status = str(row.get("queue_status") or "pending_review")
        if status not in {"pending_review", "promoted"}:
            continue
        selected_path = (
            row.get("promoted_file_path")
            if status == "promoted"
            else row.get("file_path")
        )
        value = str(selected_path or "").strip()
        if not value:
            continue
        path = (project_root / value).resolve()
        if path.is_file():
            count += 1
    return count


def _candidate_row(
    page: Mapping[str, Any],
    image_info: Mapping[str, Any],
    category: str,
    query: str,
    output_path: Path,
    digest: str,
    project_root: Path,
) -> dict[str, str]:
    metadata = image_info.get("extmetadata") or {}
    page_id = str(page.get("pageid") or "")
    title = str(page.get("title") or "")
    image_url = str(image_info.get("thumburl") or image_info.get("url") or "").strip()
    artist = plain_text(metadata_value(metadata, "Artist"))
    credit = plain_text(metadata_value(metadata, "Credit"))
    attribution = plain_text(metadata_value(metadata, "Attribution"))
    explicit_rights_holder = plain_text(metadata_value(metadata, "RightsHolder"))
    return {
        "candidate_id": f"unknown_commons_{category}_{page_id}_{digest[:10]}",
        "file_path": relative_path(output_path, project_root),
        "scientific_name": "unknown",
        "reviewed_plant_part": "unclassified",
        "source": SOURCE_NAME,
        "source_record_id": f"commons:{page_id}",
        "source_group_id": "",
        "source_record_url": source_page_url(title),
        "source_image_url": image_url,
        "creator": artist or attribution,
        "rights_holder": explicit_rights_holder or credit or attribution or artist,
        "license": str(commons_license(metadata) or ""),
        "country": "",
        "state_province": "",
        "locality": "",
        "downloaded_at": utc_now(),
        "sha256": digest,
        "review_status": "pending",
        "review_notes": (
            f"Unknown-class search category: {category}. Delete this incoming file if a "
            "supported mangrove is visible or the category is incorrect before promotion."
        ),
        "unknown_category": category,
        "search_query": query,
        "queue_status": "pending_review",
        "promoted_file_path": "",
        "promoted_at": "",
        "reviewed_at": "",
    }


def audit_categories(categories: Sequence[str], max_search_results: int) -> dict[str, int]:
    counts: dict[str, int] = {}
    for category in categories:
        qualified_ids: set[str] = set()
        for query in CATEGORY_SPECS[category].queries:
            for page in commons_pages(query, max_search_results):
                acceptable, _, _ = is_acceptable_page(page, category)
                if acceptable:
                    qualified_ids.add(str(page.get("pageid") or ""))
        counts[category] = len(qualified_ids)
        print(f"{category}: {counts[category]} reusable metadata matches")
    return counts


def _safe_extension(extension: str) -> str:
    normalized = extension.casefold()
    if normalized == ".jpeg":
        return ".jpg"
    if normalized not in SUPPORTED_EXTENSIONS:
        raise ValueError(f"unsupported downloaded extension: {extension}")
    return normalized


def _write_file_atomic(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(
        "wb", dir=path.parent, prefix=f".{path.stem}_", suffix=".part", delete=False
    ) as temporary:
        temporary.write(payload)
        temporary_path = Path(temporary.name)
    try:
        os.replace(temporary_path, path)
    finally:
        temporary_path.unlink(missing_ok=True)


def build_contact_sheets(
    queue_rows: Sequence[Mapping[str, str]],
    contact_root: Path,
    project_root: Path,
) -> list[Path]:
    outputs: list[Path] = []
    font = ImageFont.load_default()
    for category in CATEGORY_SPECS:
        if contact_root.is_dir():
            for old_sheet in contact_root.glob(f"{category}*.jpg"):
                if old_sheet.name == f"{category}.jpg" or re.fullmatch(
                    rf"{re.escape(category)}_[0-9]+\.jpg", old_sheet.name
                ):
                    old_sheet.unlink(missing_ok=True)
        rows = [
            row
            for row in queue_rows
            if row.get("unknown_category") == category
            and row.get("queue_status") == "pending_review"
            and (project_root / str(row.get("file_path") or "")).is_file()
        ]
        if not rows:
            continue
        for page_index, start in enumerate(range(0, len(rows), MAX_CONTACT_IMAGES), start=1):
            page_rows = rows[start : start + MAX_CONTACT_IMAGES]
            columns, cell_width, image_height, label_height, gutter = 4, 260, 190, 48, 10
            row_count = (len(page_rows) + columns - 1) // columns
            sheet = Image.new(
                "RGB",
                (
                    gutter + columns * (cell_width + gutter),
                    gutter + row_count * (image_height + label_height + gutter),
                ),
                "#edf4ef",
            )
            draw = ImageDraw.Draw(sheet)
            for index, row in enumerate(page_rows):
                column, row_number = index % columns, index // columns
                left = gutter + column * (cell_width + gutter)
                top = gutter + row_number * (image_height + label_height + gutter)
                image_path = project_root / str(row.get("file_path") or "")
                try:
                    with Image.open(image_path) as source:
                        preview = ImageOps.contain(source.convert("RGB"), (cell_width, image_height))
                except (OSError, ValueError):
                    preview = Image.new("RGB", (cell_width, image_height), "#64736a")
                sheet.paste(
                    preview,
                    (
                        left + (cell_width - preview.width) // 2,
                        top + (image_height - preview.height) // 2,
                    ),
                )
                draw.multiline_text(
                    (left + 3, top + image_height + 3),
                    f"{row.get('candidate_id', '')[:38]}\n{category}",
                    fill="#10281c",
                    font=font,
                    spacing=3,
                )
            contact_root.mkdir(parents=True, exist_ok=True)
            suffix = "" if page_index == 1 else f"_{page_index:02d}"
            output = contact_root / f"{category}{suffix}.jpg"
            sheet.save(output, "JPEG", quality=88, optimize=True)
            outputs.append(output)
    return outputs


@serialized_queue_operation
def download_candidates(
    categories: Sequence[str],
    target_per_category: int,
    max_search_results: int,
    *,
    incoming_root: Path = DEFAULT_INCOMING_ROOT,
    candidate_root: Path = DEFAULT_CANDIDATE_ROOT,
    queue_path: Path = DEFAULT_QUEUE_PATH,
    manifest_path: Path = DEFAULT_MANIFEST_PATH,
    image_manifest_path: Path = DEFAULT_IMAGE_MANIFEST_PATH,
    contact_root: Path = DEFAULT_CONTACT_ROOT,
    raw_root: Path = DEFAULT_RAW_ROOT,
    project_root: Path = PROJECT_ROOT,
) -> tuple[list[dict[str, str]], list[Path]]:
    queue_rows = read_csv_rows(queue_path)
    manifest_rows = read_csv_rows(manifest_path)
    image_manifest_rows = read_csv_rows(image_manifest_path)
    record_ids, urls, hashes = _existing_identifiers(
        [*queue_rows, *manifest_rows, *image_manifest_rows]
    )
    hashes.update(scan_tree_hashes(candidate_root))
    hashes.update(scan_tree_hashes(incoming_root))
    hashes.update(scan_tree_hashes(raw_root))
    additions: list[dict[str, str]] = []

    for category in categories:
        existing = _category_count(queue_rows, category, project_root)
        needed = max(0, target_per_category - existing)
        print(f"{category}: target={target_per_category}, queued={existing}, needed={needed}")
        if not needed:
            continue
        seen_pages: set[str] = set()
        for query in CATEGORY_SPECS[category].queries:
            for page in commons_pages(query, max_search_results):
                if len(additions) and _category_count([*queue_rows, *additions], category, project_root) >= target_per_category:
                    break
                acceptable, _, image_info = is_acceptable_page(page, category)
                if not acceptable or image_info is None:
                    continue
                page_id = str(page.get("pageid") or "")
                source_record_id = f"commons:{page_id}"
                image_url = str(image_info.get("thumburl") or image_info.get("url") or "").strip()
                if not page_id or page_id in seen_pages or source_record_id in record_ids or image_url in urls:
                    continue
                seen_pages.add(page_id)
                try:
                    payload, extension = download_commons_image(image_url)
                    verify_image_payload(payload)
                    extension = _safe_extension(extension)
                except CommonsCooldownError:
                    raise
                except (OSError, ValueError) as exc:
                    print(f"  skip {image_url}: {exc}", file=sys.stderr)
                    continue
                digest = sha256_bytes(payload)
                if digest in hashes:
                    continue
                output_path = (
                    incoming_root / category / f"unknown_commons_{category}_{page_id}_{digest[:10]}{extension}"
                )
                if not _is_within(output_path, incoming_root):
                    raise ValueError(f"unsafe incoming path: {output_path}")
                _write_file_atomic(output_path, payload)
                row: dict[str, str] | None = None
                try:
                    row = _candidate_row(
                        page, image_info, category, query, output_path, digest, project_root
                    )
                    additions.append(row)
                    # Checkpoint each successfully downloaded image. If a later
                    # API page fails or the process is interrupted, every image
                    # already on disk still has a durable queue row.
                    write_csv_atomic(
                        queue_path, QUEUE_FIELDS, [*queue_rows, *additions]
                    )
                except BaseException:
                    candidate_id = str((row or {}).get("candidate_id") or "")
                    persisted = bool(candidate_id) and any(
                        item.get("candidate_id") == candidate_id
                        for item in read_csv_rows(queue_path)
                    )
                    if (
                        not persisted
                        and additions
                        and additions[-1].get("candidate_id") == candidate_id
                    ):
                        additions.pop()
                    if not persisted:
                        output_path.unlink(missing_ok=True)
                    raise
                hashes.add(digest)
                record_ids.add(source_record_id)
                urls.add(image_url)
                print(f"  queued {row['candidate_id']}")
            if _category_count([*queue_rows, *additions], category, project_root) >= target_per_category:
                break

    merged = [*queue_rows, *additions]
    if not additions and not queue_path.exists():
        write_csv_atomic(queue_path, QUEUE_FIELDS, merged)
    sheets = build_contact_sheets(merged, contact_root, project_root)
    return additions, sheets


def _copy_atomic(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(
        "wb", dir=destination.parent, prefix=f".{destination.stem}_", suffix=".part", delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
        with source.open("rb") as handle:
            shutil.copyfileobj(handle, temporary)
    try:
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def _review_note(existing: str, message: str, reason: str = "") -> str:
    clean_reason = " ".join(reason.split())[:500]
    entry = f"{message}{f' Reason: {clean_reason}' if clean_reason else ''}"
    existing = existing.strip()
    return f"{existing} {entry}" if existing else entry


def _validate_review_paths(
    *,
    project_root: Path,
    incoming_root: Path,
    rejected_root: Path,
    contact_root: Path,
    queue_path: Path,
    manifest_path: Path,
) -> None:
    root = project_root.resolve()
    paths = {
        "incoming root": incoming_root.resolve(),
        "rejected root": rejected_root.resolve(),
        "contact-sheet root": contact_root.resolve(),
        "queue path": queue_path.resolve(),
        "candidate manifest": manifest_path.resolve(),
    }
    for label, path in paths.items():
        if not _is_within(path, root):
            raise ValueError(f"{label} must stay inside the project root: {path}")
    tree_labels = ("incoming root", "rejected root", "contact-sheet root")
    for index, left_label in enumerate(tree_labels):
        for right_label in tree_labels[index + 1 :]:
            left, right = paths[left_label], paths[right_label]
            if _is_within(left, right) or _is_within(right, left):
                raise ValueError(f"{left_label} and {right_label} must not overlap")
    for file_label in ("queue path", "candidate manifest"):
        for tree_label in tree_labels:
            if _is_within(paths[file_label], paths[tree_label]):
                raise ValueError(f"{file_label} must not be inside {tree_label}")


@serialized_queue_operation
def review_queue_candidate(
    candidate_id: str,
    *,
    action: str,
    target_category: str | None = None,
    reason: str = "",
    incoming_root: Path = DEFAULT_INCOMING_ROOT,
    rejected_root: Path = DEFAULT_REJECTED_ROOT,
    queue_path: Path = DEFAULT_QUEUE_PATH,
    manifest_path: Path = DEFAULT_MANIFEST_PATH,
    contact_root: Path = DEFAULT_CONTACT_ROOT,
    project_root: Path = PROJECT_ROOT,
) -> dict[str, str]:
    """Reject or reclassify one unpromoted review-queue image.

    The image rename and queue replacement act as one recoverable operation:
    when queue persistence fails, the rename is rolled back before the error is
    returned. Candidate IDs and all source/license fields remain unchanged.
    """

    project_root = project_root.resolve()
    incoming_root = incoming_root.resolve()
    rejected_root = rejected_root.resolve()
    queue_path = queue_path.resolve()
    manifest_path = manifest_path.resolve()
    contact_root = contact_root.resolve()
    _validate_review_paths(
        project_root=project_root,
        incoming_root=incoming_root,
        rejected_root=rejected_root,
        contact_root=contact_root,
        queue_path=queue_path,
        manifest_path=manifest_path,
    )
    candidate_id = candidate_id.strip()
    if not candidate_id:
        raise ValueError("candidate_id is required")
    if action not in {"reject", "reclassify"}:
        raise ValueError("review action must be 'reject' or 'reclassify'")

    queue_rows = read_csv_rows(queue_path)
    matches = [index for index, row in enumerate(queue_rows) if row.get("candidate_id") == candidate_id]
    if not matches:
        raise ValueError(f"queue candidate not found: {candidate_id}")
    if len(matches) != 1:
        raise ValueError(f"duplicate candidate_id in queue: {candidate_id}")
    row_index = matches[0]
    original = queue_rows[row_index]

    # A stale pending queue row may already have a durable approved manifest
    # row (for example after a queue write interruption). Treat it as promoted.
    if any(row.get("candidate_id") == candidate_id for row in read_csv_rows(manifest_path)):
        raise ValueError(f"candidate is already promoted and cannot be reviewed: {candidate_id}")
    status = str(original.get("queue_status") or "pending_review")
    if status == "promoted" or str(original.get("promoted_file_path") or "").strip():
        raise ValueError(f"candidate is already promoted and cannot be reviewed: {candidate_id}")

    digest = str(original.get("sha256") or "").strip().casefold()
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError(f"queue candidate has an invalid sha256: {candidate_id}")

    if status == "rejected":
        if action != "reject":
            raise ValueError(f"rejected candidate cannot be reclassified: {candidate_id}")
        rejected_path = (project_root / str(original.get("file_path") or "")).resolve()
        if (
            not rejected_path.is_file()
            or rejected_path.is_symlink()
            or not _is_within(rejected_path, rejected_root)
            or sha256_file(rejected_path) != digest
        ):
            raise ValueError(f"rejected candidate file is missing or changed: {candidate_id}")
        return dict(original)
    if status != "pending_review":
        raise ValueError(f"candidate is not pending review ({status}): {candidate_id}")

    category = str(original.get("unknown_category") or "").strip()
    if category not in CATEGORY_SPECS:
        raise ValueError(f"queue candidate has an invalid unknown category: {category!r}")
    source = (project_root / str(original.get("file_path") or "")).resolve()
    expected_parent = (incoming_root / category).resolve()
    if (
        not source.is_file()
        or source.is_symlink()
        or not _is_within(source, incoming_root)
        or source.parent != expected_parent
    ):
        raise ValueError(f"queue candidate file is outside its incoming category: {candidate_id}")
    if sha256_file(source) != digest:
        raise ValueError(f"queue candidate file hash changed: {candidate_id}")

    updated = dict(original)
    reviewed_at = utc_now()
    if action == "reclassify":
        if not target_category:
            raise ValueError("target_category is required for reclassification")
        normalized_target = selected_categories([target_category])[0]
        if normalized_target == category:
            return updated
        destination = (incoming_root / normalized_target / source.name).resolve()
        if not _is_within(destination, incoming_root / normalized_target):
            raise ValueError(f"unsafe reclassification destination: {destination}")
        updated["unknown_category"] = normalized_target
        updated["file_path"] = relative_path(destination, project_root)
        updated["reviewed_at"] = reviewed_at
        updated["review_notes"] = _review_note(
            str(updated.get("review_notes") or ""),
            f"Reviewer reclassified unknown category from {category} to {normalized_target}.",
            reason,
        )
    else:
        destination = (rejected_root / category / source.name).resolve()
        if not _is_within(destination, rejected_root / category):
            raise ValueError(f"unsafe rejection destination: {destination}")
        updated["queue_status"] = "rejected"
        updated["review_status"] = "rejected"
        updated["file_path"] = relative_path(destination, project_root)
        updated["reviewed_at"] = reviewed_at
        updated["review_notes"] = _review_note(
            str(updated.get("review_notes") or ""),
            "Rejected during explicit unknown-class review.",
            reason,
        )

    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise ValueError(f"review destination already exists: {destination}")
    os.replace(source, destination)
    queue_rows[row_index] = updated
    try:
        write_csv_atomic(queue_path, QUEUE_FIELDS, queue_rows)
    except BaseException as exc:
        try:
            os.replace(destination, source)
        except BaseException as rollback_exc:
            raise RuntimeError(
                f"queue update failed and file rollback also failed for {candidate_id}: "
                f"{rollback_exc}"
            ) from exc
        raise

    try:
        build_contact_sheets(queue_rows, contact_root, project_root)
    except (OSError, ValueError) as exc:
        print(f"warning: review saved but contact-sheet refresh failed: {exc}", file=sys.stderr)
    return updated


def _derived_row(
    base_row: Mapping[str, str],
    output: Path,
    digest: str,
    kind: str,
    number: int,
    project_root: Path,
) -> dict[str, str]:
    row = {field: str(base_row.get(field) or "") for field in MANIFEST_FIELDS}
    row.update(
        {
            "candidate_id": f"{base_row.get('candidate_id')}_{kind}{number}",
            "file_path": relative_path(output, project_root),
            "sha256": digest,
            "review_status": "approved",
            "review_notes": (
                f"Derived {kind} poor-capture negative from reviewed unknown image "
                f"{base_row.get('candidate_id')}; source grouping and license preserved."
            ),
            "downloaded_at": utc_now(),
        }
    )
    return row


def _create_variant(source: Path, destination: Path, kind: str) -> str:
    with Image.open(source) as image:
        converted = image.convert("RGB")
        if kind == "blur":
            converted = converted.filter(ImageFilter.GaussianBlur(radius=12))
        elif kind == "dark":
            converted = ImageEnhance.Brightness(converted).enhance(0.14)
        else:  # pragma: no cover - caller only supplies fixed choices
            raise ValueError(f"unsupported variant kind: {kind}")
        buffer = io.BytesIO()
        converted.save(buffer, "JPEG", quality=86, optimize=True)
    payload = buffer.getvalue()
    verify_image_payload(payload)
    _write_file_atomic(destination, payload)
    return sha256_bytes(payload)


def _balanced_variant_bases(
    base_rows: Sequence[Mapping[str, str]],
    category_by_candidate_id: Mapping[str, str],
    count: int,
) -> list[Mapping[str, str]]:
    """Choose distinct source images evenly across unknown categories.

    Category order follows ``CATEGORY_SPECS`` and rows within each category are
    ordered by their stable candidate identifier.  This makes repeated runs
    choose the same bases even when the review queue was written in a different
    order.  A source image can be selected at most once for a variant kind.
    """
    if count <= 0:
        return []

    buckets: dict[str, list[Mapping[str, str]]] = {}
    for row in base_rows:
        candidate_id = str(row.get("candidate_id") or "")
        category = str(category_by_candidate_id.get(candidate_id) or "unclassified")
        buckets.setdefault(category, []).append(row)
    for rows in buckets.values():
        rows.sort(
            key=lambda row: (
                str(row.get("candidate_id") or ""),
                str(row.get("file_path") or ""),
            )
        )

    known_categories = [category for category in CATEGORY_SPECS if category in buckets]
    extra_categories = sorted(set(buckets) - set(known_categories))
    category_order = [*known_categories, *extra_categories]
    positions = {category: 0 for category in category_order}
    selected: list[Mapping[str, str]] = []

    while len(selected) < count:
        made_progress = False
        for category in category_order:
            position = positions[category]
            rows = buckets[category]
            if position >= len(rows):
                continue
            selected.append(rows[position])
            positions[category] = position + 1
            made_progress = True
            if len(selected) == count:
                break
        if not made_progress:
            break
    return selected


def _merge_manifest_rows_atomic(
    manifest_path: Path, additions: Sequence[Mapping[str, str]]
) -> set[str]:
    inserted_ids: set[str] = set()
    with candidate_manifest_write_lock(manifest_path):
        existing = read_csv_rows(manifest_path)
        existing_hashes = {str(row.get("sha256") or "").casefold() for row in existing}
        existing_ids = {str(row.get("candidate_id") or "") for row in existing}
        merged = list(existing)
        for row in additions:
            if row.get("sha256", "").casefold() in existing_hashes or row.get("candidate_id") in existing_ids:
                continue
            clean = {field: str(row.get(field) or "") for field in MANIFEST_FIELDS}
            merged.append(clean)
            existing_hashes.add(clean["sha256"].casefold())
            existing_ids.add(clean["candidate_id"])
            inserted_ids.add(clean["candidate_id"])
        _write_csv_unlocked(manifest_path, MANIFEST_FIELDS, merged)
    return inserted_ids


@serialized_queue_operation
def promote_reviewed(
    *,
    categories: Sequence[str] | None = None,
    blur_variants: int = 0,
    dark_variants: int = 0,
    incoming_root: Path = DEFAULT_INCOMING_ROOT,
    candidate_root: Path = DEFAULT_CANDIDATE_ROOT,
    queue_path: Path = DEFAULT_QUEUE_PATH,
    manifest_path: Path = DEFAULT_MANIFEST_PATH,
    image_manifest_path: Path = DEFAULT_IMAGE_MANIFEST_PATH,
    raw_root: Path = DEFAULT_RAW_ROOT,
    contact_root: Path = DEFAULT_CONTACT_ROOT,
    project_root: Path = PROJECT_ROOT,
) -> list[dict[str, str]]:
    queue_rows = read_csv_rows(queue_path)
    manifest_rows = read_csv_rows(manifest_path)
    image_manifest_rows = read_csv_rows(image_manifest_path)
    manifest_hashes = {
        str(row.get("sha256") or "").casefold()
        for row in [*manifest_rows, *image_manifest_rows]
    }
    tree_hashes = scan_tree_hashes(candidate_root)
    raw_hashes = scan_tree_hashes(raw_root)
    for digest, paths in raw_hashes.items():
        tree_hashes.setdefault(digest, []).extend(paths)
    additions: list[dict[str, str]] = []
    promoted_pairs: list[tuple[dict[str, str], Path, Path]] = []
    recovered_pairs: list[tuple[dict[str, str], Path, Path]] = []
    created_paths: dict[str, Path] = {}
    selected = set(categories or CATEGORY_SPECS)
    manifest_by_id = {
        str(row.get("candidate_id") or ""): row
        for row in manifest_rows
        if str(row.get("candidate_id") or "")
    }

    try:
        for queue_row in queue_rows:
            if str(queue_row.get("queue_status") or "pending_review") != "pending_review":
                continue
            category = str(queue_row.get("unknown_category") or "")
            if category not in selected:
                continue
            incoming_value = str(queue_row.get("file_path") or "").strip()
            incoming = (project_root / incoming_value).resolve()
            if (
                not incoming.is_file()
                or incoming.is_symlink()
                or not _is_within(incoming, incoming_root)
            ):
                continue
            digest = sha256_file(incoming)
            if digest != str(queue_row.get("sha256") or "").casefold():
                print(f"skip changed queue file: {incoming}", file=sys.stderr)
                continue
            if category not in CATEGORY_SPECS:
                continue
            if (
                str(queue_row.get("source") or "") != SOURCE_NAME
                or not str(queue_row.get("source_record_id") or "").startswith("commons:")
                or not str(queue_row.get("source_record_url") or "").startswith("https://")
                or not str(queue_row.get("source_image_url") or "").startswith(("https://", "http://"))
                or not license_is_allowed(str(queue_row.get("license") or ""))
                or not (
                    str(queue_row.get("creator") or "").strip()
                    or str(queue_row.get("rights_holder") or "").strip()
                )
            ):
                print(f"skip queue row with incomplete provenance: {incoming}", file=sys.stderr)
                continue
            destination = candidate_root / "unknown" / "unclassified" / category / incoming.name
            destination = destination.resolve()
            if not _is_within(destination, candidate_root / "unknown" / "unclassified"):
                raise ValueError(f"unsafe candidate path: {destination}")

            existing_manifest_row = manifest_by_id.get(str(queue_row.get("candidate_id") or ""))
            if existing_manifest_row is not None:
                existing_path = (
                    project_root / str(existing_manifest_row.get("file_path") or "")
                ).resolve()
                if (
                    existing_manifest_row.get("scientific_name") == "unknown"
                    and str(existing_manifest_row.get("sha256") or "").casefold() == digest
                    and existing_path.is_file()
                    and sha256_file(existing_path) == digest
                ):
                    recovered_pairs.append((queue_row, incoming, existing_path))
                    continue
                print(
                    f"skip conflicting candidate_id already in manifest: "
                    f"{queue_row.get('candidate_id')}",
                    file=sys.stderr,
                )
                continue

            existing_paths = tree_hashes.get(digest, [])
            if digest in manifest_hashes or (
                existing_paths and destination not in [path.resolve() for path in existing_paths]
            ):
                print(f"skip duplicate queue file: {incoming}", file=sys.stderr)
                continue
            if destination.is_file():
                if sha256_file(destination) != digest:
                    for created_path in created_paths.values():
                        created_path.unlink(missing_ok=True)
                    raise ValueError(f"candidate destination collision: {destination}")
            else:
                try:
                    _copy_atomic(incoming, destination)
                except BaseException:
                    destination.unlink(missing_ok=True)
                    for created_path in created_paths.values():
                        created_path.unlink(missing_ok=True)
                    raise
                created_paths[str(queue_row.get("candidate_id") or "")] = destination
            approved = {field: str(queue_row.get(field) or "") for field in MANIFEST_FIELDS}
            approved.update(
                {
                    "file_path": relative_path(destination, project_root),
                    "scientific_name": "unknown",
                    "reviewed_plant_part": "unclassified",
                    "review_status": "approved",
                    "review_notes": (
                        f"Approved by explicit review-queue promotion. Unknown category: {category}."
                    ),
                }
            )
            additions.append(approved)
            promoted_pairs.append((queue_row, incoming, destination))
            tree_hashes.setdefault(digest, []).append(destination)

        # Variants are derived only from negatives accepted in this promotion. Keeping
        # all source identifiers unchanged forces the split builder to group them.
        base_additions = list(additions)
        category_by_candidate_id = {
            str(row.get("candidate_id") or ""): str(row.get("unknown_category") or "")
            for row, _, _ in promoted_pairs
        }
        for kind, count in (("blur", blur_variants), ("dark", dark_variants)):
            variant_bases = _balanced_variant_bases(
                base_additions, category_by_candidate_id, count
            )
            for index, base in enumerate(variant_bases, start=1):
                base_path = project_root / base["file_path"]
                category = category_by_candidate_id.get(
                    str(base.get("candidate_id") or ""), "unclassified"
                )
                output = (
                    candidate_root
                    / "unknown"
                    / "unclassified"
                    / category
                    / "derived"
                    / f"{Path(base['file_path']).stem}_{kind}{index}.jpg"
                )
                if output.is_file():
                    digest = sha256_file(output)
                else:
                    try:
                        digest = _create_variant(base_path, output, kind)
                    except BaseException:
                        output.unlink(missing_ok=True)
                        for created_path in created_paths.values():
                            created_path.unlink(missing_ok=True)
                        raise
                    created_paths[f"{base.get('candidate_id')}_{kind}{index}"] = output
                if digest in manifest_hashes or any(row["sha256"] == digest for row in additions):
                    created = created_paths.pop(
                        f"{base.get('candidate_id')}_{kind}{index}", None
                    )
                    if created is not None:
                        created.unlink(missing_ok=True)
                    continue
                additions.append(_derived_row(base, output, digest, kind, index, project_root))

        try:
            inserted_ids = _merge_manifest_rows_atomic(manifest_path, additions)
        except Exception:
            for path in created_paths.values():
                path.unlink(missing_ok=True)
            raise

    except BaseException:
        # Until the manifest replacement succeeds, every destination created
        # by this run is provisional. This outer guard also covers unexpected
        # read/hash failures after an earlier queue row was copied.
        for path in created_paths.values():
            path.unlink(missing_ok=True)
        raise

    # A concurrent writer may already have inserted a duplicate. Remove only
    # files created by this run whose row was not actually committed.
    for candidate_id, path in list(created_paths.items()):
        if candidate_id not in inserted_ids:
            path.unlink(missing_ok=True)
            created_paths.pop(candidate_id, None)

    promoted_at = utc_now()
    durable_pairs = [
        pair
        for pair in promoted_pairs
        if str(pair[0].get("candidate_id") or "") in inserted_ids
    ]
    durable_pairs.extend(recovered_pairs)
    for row, incoming, destination in durable_pairs:
        row["queue_status"] = "promoted"
        row["review_status"] = "approved"
        row["reviewed_at"] = promoted_at
        row["promoted_file_path"] = relative_path(destination, project_root)
        row["promoted_at"] = promoted_at
    write_csv_atomic(queue_path, QUEUE_FIELDS, queue_rows)
    # Keep the incoming copy until both the approved manifest and queue state are
    # durable. If queue persistence fails, the next run can reconcile from the
    # already-approved manifest row.
    for _, incoming, _ in durable_pairs:
        incoming.unlink(missing_ok=True)
    build_contact_sheets(queue_rows, contact_root, project_root)
    return [
        row
        for row in additions
        if str(row.get("candidate_id") or "") in inserted_ids
    ]


def selected_categories(values: Sequence[str] | None) -> list[str]:
    if not values:
        return list(CATEGORY_SPECS)
    categories: list[str] = []
    for value in values:
        normalized = "_".join(re.findall(r"[a-z0-9]+", value.casefold()))
        if normalized in {"nipa", "nypa", "nypa_fruticans"}:
            raise ValueError(
                "nipa/Nypa fruticans cannot be an unknown negative because it is a supported mangrove class"
            )
        if normalized not in CATEGORY_SPECS:
            raise ValueError(
                f"unknown category {value!r}; choose from {', '.join(CATEGORY_SPECS)}"
            )
        if normalized not in categories:
            categories.append(normalized)
    return categories


def _project_path(value: Path | None, project_root: Path, default: Path) -> Path:
    if value is None:
        return default.resolve()
    return (value if value.is_absolute() else project_root / value).resolve()


def validate_project_paths(project_root: Path, paths: Mapping[str, Path]) -> None:
    root = project_root.resolve()
    for label, path in paths.items():
        resolved = path.resolve()
        if not _is_within(resolved, root):
            raise ValueError(f"{label} must stay inside the project root: {resolved}")

    file_labels = ("queue path", "candidate manifest", "image manifest")
    file_paths = [paths[label].resolve() for label in file_labels]
    if len(set(file_paths)) != len(file_paths):
        raise ValueError("queue, candidate manifest, and image manifest must be distinct files")

    tree_labels = (
        "incoming root",
        "candidate root",
        "raw root",
        "contact-sheet root",
        "rejected root",
    )
    tree_paths = {label: paths[label].resolve() for label in tree_labels}
    for left_label, left in tree_paths.items():
        for right_label, right in tree_paths.items():
            if left_label >= right_label:
                continue
            if _is_within(left, right) or _is_within(right, left):
                raise ValueError(f"{left_label} and {right_label} must not overlap")
    for file_label, file_path in zip(file_labels, file_paths):
        for tree_label, tree_path in tree_paths.items():
            if _is_within(file_path, tree_path):
                raise ValueError(f"{file_label} must not be inside {tree_label}")


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Audit or collect licensed Wikimedia Commons negatives into a review queue; "
            "promotion is a separate explicit action."
        )
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--download", action="store_true", help="Download into the incoming review queue.")
    mode.add_argument("--promote", action="store_true", help="Promote only review files that still exist.")
    mode.add_argument("--reject", metavar="CANDIDATE_ID", help="Reject one pending queue candidate.")
    mode.add_argument(
        "--reclassify",
        metavar="CANDIDATE_ID",
        help="Move one pending candidate to --to-category.",
    )
    parser.add_argument("--category", action="append", help="Repeat to select categories; defaults to all.")
    parser.add_argument("--to-category", help="Allowed destination category for --reclassify.")
    parser.add_argument("--review-reason", default="", help="Optional short review note.")
    parser.add_argument("--target-per-category", type=int, default=10)
    parser.add_argument("--max-search-results", type=int, default=200)
    parser.add_argument("--blur-variants", type=int, default=0)
    parser.add_argument("--dark-variants", type=int, default=0)
    parser.add_argument("--project-root", type=Path, default=PROJECT_ROOT)
    parser.add_argument("--incoming-root", type=Path)
    parser.add_argument("--candidate-root", type=Path)
    parser.add_argument("--queue", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--image-manifest", type=Path)
    parser.add_argument("--raw-root", type=Path)
    parser.add_argument("--contact-root", type=Path)
    parser.add_argument("--rejected-root", type=Path)
    args = parser.parse_args(argv)
    if not 1 <= args.target_per_category <= 100:
        parser.error("--target-per-category must be between 1 and 100")
    if not 1 <= args.max_search_results <= 500:
        parser.error("--max-search-results must be between 1 and 500")
    if not 0 <= args.blur_variants <= 100 or not 0 <= args.dark_variants <= 100:
        parser.error("variant counts must be between 0 and 100")
    if not args.promote and (args.blur_variants or args.dark_variants):
        parser.error("blur/dark variants are only available with --promote")
    if args.reclassify and not args.to_category:
        parser.error("--reclassify requires --to-category")
    if args.to_category and not args.reclassify:
        parser.error("--to-category is only valid with --reclassify")
    if args.review_reason and not (args.reject or args.reclassify):
        parser.error("--review-reason is only valid with --reject or --reclassify")
    try:
        args.categories = selected_categories(args.category)
    except ValueError as exc:
        parser.error(str(exc))
    return args


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    project_root = args.project_root.resolve()
    incoming_root = _project_path(
        args.incoming_root, project_root, project_root / "dataset" / "incoming" / "unknown"
    )
    candidate_root = _project_path(
        args.candidate_root, project_root, project_root / "dataset" / "candidates"
    )
    queue_path = _project_path(
        args.queue,
        project_root,
        project_root / "dataset" / "metadata" / "unknown_commons_review_queue.csv",
    )
    manifest_path = _project_path(
        args.manifest,
        project_root,
        project_root / "dataset" / "metadata" / "candidate_image_manifest.csv",
    )
    image_manifest_path = _project_path(
        args.image_manifest,
        project_root,
        project_root / "dataset" / "metadata" / "image_manifest.csv",
    )
    raw_root = _project_path(
        args.raw_root, project_root, project_root / "dataset" / "raw"
    )
    contact_root = _project_path(
        args.contact_root,
        project_root,
        project_root / "dataset" / "review" / "unknown_contact_sheets",
    )
    rejected_root = _project_path(
        args.rejected_root,
        project_root,
        project_root / "dataset" / "review" / "rejected_unknown",
    )
    try:
        validate_project_paths(
            project_root,
            {
                "incoming root": incoming_root,
                "candidate root": candidate_root,
                "queue path": queue_path,
                "candidate manifest": manifest_path,
                "image manifest": image_manifest_path,
                "raw root": raw_root,
                "contact-sheet root": contact_root,
                "rejected root": rejected_root,
            },
        )
        if args.reject or args.reclassify:
            reviewed = review_queue_candidate(
                args.reject or args.reclassify,
                action="reject" if args.reject else "reclassify",
                target_category=args.to_category,
                reason=args.review_reason,
                incoming_root=incoming_root,
                rejected_root=rejected_root,
                queue_path=queue_path,
                manifest_path=manifest_path,
                contact_root=contact_root,
                project_root=project_root,
            )
            print(
                f"Review saved for {reviewed['candidate_id']}: "
                f"{reviewed['queue_status']} / {reviewed['unknown_category']}"
            )
        elif args.promote:
            additions = promote_reviewed(
                categories=args.categories,
                blur_variants=args.blur_variants,
                dark_variants=args.dark_variants,
                incoming_root=incoming_root,
                candidate_root=candidate_root,
                queue_path=queue_path,
                manifest_path=manifest_path,
                image_manifest_path=image_manifest_path,
                raw_root=raw_root,
                contact_root=contact_root,
                project_root=project_root,
            )
            print(f"Promoted {len(additions)} approved files/variants.")
        elif args.download:
            additions, sheets = download_candidates(
                args.categories,
                args.target_per_category,
                args.max_search_results,
                incoming_root=incoming_root,
                candidate_root=candidate_root,
                queue_path=queue_path,
                manifest_path=manifest_path,
                image_manifest_path=image_manifest_path,
                contact_root=contact_root,
                raw_root=raw_root,
                project_root=project_root,
            )
            print(f"Queued {len(additions)} new files; wrote {len(sheets)} contact sheets.")
        else:
            audit_categories(args.categories, args.max_search_results)
        return 0
    except (CandidateManifestBusyError, OSError, ValueError, csv.Error) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

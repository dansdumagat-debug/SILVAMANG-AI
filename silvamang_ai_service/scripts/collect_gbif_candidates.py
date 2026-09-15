from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATASET_ROOT = PROJECT_ROOT / "dataset"
CANDIDATE_ROOT = DATASET_ROOT / "candidates"
MANIFEST_PATH = DATASET_ROOT / "metadata" / "candidate_image_manifest.csv"
GBIF_API = "https://api.gbif.org/v1"
USER_AGENT = "SILVAMANG-AI-dataset-collector/1.0 (academic research)"
PAGE_SIZE = 300
MAX_IMAGE_BYTES = 20 * 1024 * 1024
MIN_IMAGE_BYTES = 20 * 1024
REQUEST_DELAY_SECONDS = 0.25
IMAGE_REQUEST_TIMEOUT_SECONDS = 12
MAX_IMAGE_DOWNLOAD_SECONDS = 20
API_RETRY_DELAYS_SECONDS = (2, 5, 10)
DOWNLOAD_BATCH_SIZE = 24
DEFAULT_DOWNLOAD_WORKERS = 8
FIELD_IMAGE_BASIS = {
    "HUMAN_OBSERVATION",
    "MACHINE_OBSERVATION",
    "OBSERVATION",
    "LIVING_SPECIMEN",
}

NEW_SPECIES = (
    "Acanthus ebracteatus",
    "Acanthus ilicifolius",
    "Acanthus volubilis",
    "Avicennia alba",
    "Avicennia officinalis",
    "Nypa fruticans",
    "Lumnitzera racemosa",
    "Lumnitzera littorea",
    "Pemphis acidula",
    "Sonneratia ovata",
    "Camptostemon philippinensis",
    "Heritiera littoralis",
    "Xylocarpus rumphii",
    "Osbornia octodonta",
    "Aegiceras corniculatum",
    "Aegiceras floridum",
    "Bruguiera cylindrica",
    "Bruguiera sexangula",
    "Ceriops zippeliana",
    "Scyphiphora hydrophylacea",
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


def request_json(path: str, params: dict[str, Any]) -> dict[str, Any]:
    url = f"{GBIF_API}/{path}?{urlencode(params, doseq=True)}"
    request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    for attempt in range(len(API_RETRY_DELAYS_SECONDS) + 1):
        try:
            with urlopen(request, timeout=45) as response:
                return json.load(response)
        except (URLError, TimeoutError, OSError):
            if attempt >= len(API_RETRY_DELAYS_SECONDS):
                raise
            time.sleep(API_RETRY_DELAYS_SECONDS[attempt])
    raise RuntimeError("unreachable")


def match_species(scientific_name: str) -> tuple[int, str]:
    payload = request_json("species/match", {"name": scientific_name, "strict": "true"})
    usage_key = payload.get("usageKey")
    match_type = str(payload.get("matchType", "NONE")).upper()

    if not usage_key or match_type not in {"EXACT", "HIGHERRANK"}:
        raise ValueError(f"GBIF did not return a reliable match for {scientific_name!r}.")

    matched_name = str(payload.get("scientificName") or payload.get("canonicalName") or scientific_name)
    return int(usage_key), matched_name


def occurrence_page(taxon_key: int, offset: int, limit: int) -> dict[str, Any]:
    return request_json(
        "occurrence/search",
        {
            "taxon_key": taxon_key,
            "media_type": "StillImage",
            "occurrence_status": "PRESENT",
            "limit": limit,
            "offset": offset,
        },
    )


def license_is_allowed(value: Any) -> bool:
    license_value = str(value or "").strip().lower().replace("http://", "https://")
    allowed_fragments = (
        "creativecommons.org/publicdomain/zero/",
        "creativecommons.org/publicdomain/mark/",
        "creativecommons.org/licenses/by/",
        "creativecommons.org/licenses/by-sa/",
        "cc0",
        "public domain",
        "cc by ",
        "cc-by-",
        "cc_by_",
    )
    blocked_fragments = ("by-nc", "by-nd", "by_nc", "by_nd", "noncommercial", "no derivatives")

    return any(item in license_value for item in allowed_fragments) and not any(
        item in license_value for item in blocked_fragments
    )


def image_media(record: dict[str, Any]) -> Iterable[tuple[int, dict[str, Any], str]]:
    for index, media in enumerate(record.get("media") or []):
        if not isinstance(media, dict):
            continue
        media_type = str(media.get("type") or "").lower()
        image_url = str(media.get("identifier") or "").strip()
        license_value = media.get("license") or record.get("license")
        if "image" not in media_type and "stillimage" not in media_type:
            continue
        if not image_url.startswith(("https://", "http://")):
            continue
        if not license_is_allowed(license_value):
            continue
        yield index, media, str(license_value)


def is_field_observation(record: dict[str, Any]) -> bool:
    return str(record.get("basisOfRecord") or "").strip().upper() in FIELD_IMAGE_BASIS


def safe_species_folder(scientific_name: str) -> str:
    return "_".join(scientific_name.strip().split())


def existing_manifest() -> tuple[
    set[str],
    set[str],
    dict[str, int],
    dict[tuple[str, str], int],
]:
    urls: set[str] = set()
    hashes: set[str] = set()
    species_counts: dict[str, int] = {}
    source_record_counts: dict[tuple[str, str], int] = {}

    if not MANIFEST_PATH.exists():
        return urls, hashes, species_counts, source_record_counts

    with MANIFEST_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            image_url = str(row.get("source_image_url") or "").strip()
            image_hash = str(row.get("sha256") or "").strip()
            scientific_name = str(row.get("scientific_name") or "").strip()
            source_record_id = str(row.get("source_record_id") or "").strip()
            review_status = str(row.get("review_status") or "pending").strip().lower()
            if image_url:
                urls.add(image_url)
            if image_hash:
                hashes.add(image_hash)
            if scientific_name and review_status in {"pending", "approved"}:
                species_counts[scientific_name] = species_counts.get(scientific_name, 0) + 1
            if scientific_name and source_record_id:
                key = (scientific_name, source_record_id)
                source_record_counts[key] = source_record_counts.get(key, 0) + 1

    return urls, hashes, species_counts, source_record_counts


def append_manifest(row: dict[str, Any]) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    write_header = not MANIFEST_PATH.exists() or MANIFEST_PATH.stat().st_size == 0
    with MANIFEST_PATH.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_FIELDS, extrasaction="ignore")
        if write_header:
            writer.writeheader()
        writer.writerow(row)


def extension_for(content_type: str, image_url: str, payload: bytes) -> str | None:
    normalized_type = content_type.split(";", 1)[0].strip().lower()
    known_types = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
    }
    if normalized_type in known_types:
        return known_types[normalized_type]

    suffix = Path(urlparse(image_url).path).suffix.lower()
    if suffix in {".jpg", ".jpeg", ".png", ".webp"}:
        return ".jpg" if suffix == ".jpeg" else suffix

    if payload.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if payload.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if payload.startswith(b"RIFF") and payload[8:12] == b"WEBP":
        return ".webp"
    return None


def preferred_download_url(image_url: str) -> str:
    """Use iNaturalist's web-sized derivative instead of a very large original."""
    parsed = urlparse(image_url)
    host = parsed.netloc.lower()
    if host in {
        "inaturalist-open-data.s3.amazonaws.com",
        "static.inaturalist.org",
    }:
        return image_url.replace("/original.", "/large.")
    return image_url


def download_image(image_url: str) -> tuple[bytes, str]:
    if any(extension in image_url.lower() for extension in (".tif", ".tiff")):
        raise ValueError("TIFF source is skipped; use a web-sized JPEG/PNG/WebP candidate")

    download_url = preferred_download_url(image_url)
    request = Request(download_url, headers={"User-Agent": USER_AGENT, "Accept": "image/*"})
    started_at = time.monotonic()
    with urlopen(request, timeout=IMAGE_REQUEST_TIMEOUT_SECONDS) as response:
        declared_size = int(response.headers.get("Content-Length") or 0)
        if declared_size > MAX_IMAGE_BYTES:
            raise ValueError(f"image is larger than {MAX_IMAGE_BYTES} bytes")

        chunks: list[bytes] = []
        received = 0
        while True:
            if time.monotonic() - started_at > MAX_IMAGE_DOWNLOAD_SECONDS:
                raise TimeoutError(
                    f"image download exceeded {MAX_IMAGE_DOWNLOAD_SECONDS} seconds"
                )
            chunk = response.read(64 * 1024)
            if not chunk:
                break
            received += len(chunk)
            if received > MAX_IMAGE_BYTES:
                raise ValueError(f"image exceeded {MAX_IMAGE_BYTES} bytes")
            chunks.append(chunk)

        payload = b"".join(chunks)
        if len(payload) < MIN_IMAGE_BYTES:
            raise ValueError(f"image is smaller than {MIN_IMAGE_BYTES} bytes")

        extension = extension_for(str(response.headers.get("Content-Type") or ""), download_url, payload)
        if extension is None:
            raise ValueError("unsupported or invalid image type")
        return payload, extension


def download_result(image_url: str) -> tuple[bytes | None, str | None, Exception | None]:
    try:
        payload, extension = download_image(image_url)
        return payload, extension, None
    except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
        return None, None, error


def relative_path(path: Path) -> str:
    return path.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix()


def audit_species(scientific_name: str) -> None:
    taxon_key, matched_name = match_species(scientific_name)
    payload = occurrence_page(taxon_key, offset=0, limit=0)
    count = int(payload.get("count") or 0)
    print(f"{scientific_name}: {count} image-bearing GBIF occurrences (match: {matched_name}, key: {taxon_key})")


def collect_species(
    scientific_name: str,
    target: int,
    max_records: int,
    max_images_per_record: int,
    workers: int,
) -> None:
    taxon_key, matched_name = match_species(scientific_name)
    seen_urls, seen_hashes, species_counts, source_record_counts = existing_manifest()
    already_downloaded = species_counts.get(scientific_name, 0)
    needed = max(0, target - already_downloaded)
    print(
        f"{scientific_name}: target={target}, existing={already_downloaded}, "
        f"needed={needed}, GBIF match={matched_name} ({taxon_key})",
        flush=True,
    )
    if needed == 0:
        return

    destination = CANDIDATE_ROOT / safe_species_folder(scientific_name) / "unclassified"
    destination.mkdir(parents=True, exist_ok=True)
    offset = 0
    downloaded = 0
    rejected = 0
    failures = 0

    while downloaded < needed and offset < max_records:
        page_limit = min(PAGE_SIZE, max_records - offset)
        page = occurrence_page(taxon_key, offset=offset, limit=page_limit)
        records = page.get("results") or []
        if not records:
            break

        queued_urls: set[str] = set()
        tasks: list[tuple[dict[str, Any], str, tuple[str, str], int, dict[str, Any], str]] = []
        for record in records:
            if not is_field_observation(record):
                rejected += 1
                continue
            record_id = str(record.get("key") or "")
            record_key = (scientific_name, record_id)
            queued_for_record = source_record_counts.get(record_key, 0)
            for media_index, media, license_value in image_media(record):
                if queued_for_record >= max_images_per_record:
                    rejected += 1
                    continue
                image_url = str(media["identifier"]).strip()
                if image_url in seen_urls or image_url in queued_urls:
                    rejected += 1
                    continue
                queued_urls.add(image_url)
                queued_for_record += 1
                tasks.append((record, record_id, record_key, media_index, media, license_value))

        task_index = 0
        while downloaded < needed and task_index < len(tasks):
            remaining = needed - downloaded
            batch_size = min(DOWNLOAD_BATCH_SIZE, remaining, len(tasks) - task_index)
            batch = tasks[task_index : task_index + batch_size]
            task_index += batch_size
            image_urls = [str(task[4]["identifier"]).strip() for task in batch]
            with ThreadPoolExecutor(max_workers=min(workers, batch_size)) as executor:
                results = list(executor.map(download_result, image_urls))

            for task, image_url, result in zip(batch, image_urls, results):
                record, record_id, record_key, media_index, media, license_value = task
                payload, extension, error = result
                if error is not None or payload is None or extension is None:
                    failures += 1
                    print(f"  skip {image_url}: {error}", file=sys.stderr, flush=True)
                    continue
                digest = hashlib.sha256(payload).hexdigest()
                seen_urls.add(image_url)
                if digest in seen_hashes:
                    rejected += 1
                    continue

                candidate_id = f"gbif_{record_id}_{media_index}_{digest[:10]}"
                output_path = destination / f"{candidate_id}{extension}"
                output_path.write_bytes(payload)
                seen_hashes.add(digest)
                source_record_counts[record_key] = source_record_counts.get(record_key, 0) + 1

                append_manifest(
                    {
                        "candidate_id": candidate_id,
                        "file_path": relative_path(output_path),
                        "scientific_name": scientific_name,
                        "reviewed_plant_part": "",
                        "source": "GBIF occurrence media",
                        "source_record_id": record_id,
                        "source_record_url": record.get("references")
                        or f"https://www.gbif.org/occurrence/{record_id}",
                        "source_image_url": image_url,
                        "creator": media.get("creator") or record.get("recordedBy") or "",
                        "rights_holder": media.get("rightsHolder") or record.get("rightsHolder") or "",
                        "license": license_value,
                        "country": record.get("country") or record.get("countryCode") or "",
                        "state_province": record.get("stateProvince") or "",
                        "locality": record.get("locality") or "",
                        "downloaded_at": datetime.now(timezone.utc).isoformat(),
                        "sha256": digest,
                        "review_status": "pending",
                        "review_notes": "Confirm species and assign leaves, bark, roots, or flowers before training.",
                    }
                )
                downloaded += 1
                print(
                    f"  downloaded {already_downloaded + downloaded}/{target}: {output_path.name}",
                    flush=True,
                )
                time.sleep(REQUEST_DELAY_SECONDS)
                if downloaded >= needed:
                    break

        offset += len(records)
        if page.get("endOfRecords"):
            break
        time.sleep(REQUEST_DELAY_SECONDS)

    print(
        f"{scientific_name}: added={downloaded}, total={already_downloaded + downloaded}, "
        f"duplicates/rejected={rejected}, download_failures={failures}, records_checked={offset}",
        flush=True,
    )
    if already_downloaded + downloaded < target:
        print("  WARNING: target was not reached; do not fill the gap with duplicates or unverified images.")


def selected_species(args: argparse.Namespace) -> list[str]:
    requested = list(NEW_SPECIES) if args.all_new else list(args.species or [])
    unique: list[str] = []
    for name in requested:
        normalized = " ".join(name.replace("_", " ").split())
        if normalized and normalized not in unique:
            unique.append(normalized)
    if not unique:
        raise ValueError("Choose --all-new or provide at least one --species value.")
    return unique


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit or download licensed GBIF species-image candidates for manual review."
    )
    parser.add_argument("--mode", choices=("audit", "download"), default="audit")
    parser.add_argument("--all-new", action="store_true", help="Process the 20 new guide species.")
    parser.add_argument("--species", action="append", help="Scientific name; repeat for multiple species.")
    parser.add_argument(
        "--target",
        type=int,
        default=200,
        help="Species-level candidate target. Images remain unclassified by plant part.",
    )
    parser.add_argument(
        "--max-records",
        type=int,
        default=3000,
        help="Maximum GBIF occurrence records checked per species.",
    )
    parser.add_argument(
        "--max-images-per-record",
        type=int,
        default=2,
        help="Maximum candidates retained from one GBIF occurrence record.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=DEFAULT_DOWNLOAD_WORKERS,
        help="Concurrent image downloads (default: 8).",
    )
    args = parser.parse_args()
    if not 1 <= args.target <= 5000:
        parser.error("--target must be between 1 and 5000")
    if not 1 <= args.max_records <= 100000:
        parser.error("--max-records must be between 1 and 100000")
    if not 1 <= args.max_images_per_record <= 20:
        parser.error("--max-images-per-record must be between 1 and 20")
    if not 1 <= args.workers <= 16:
        parser.error("--workers must be between 1 and 16")
    return args


def main() -> int:
    args = parse_args()
    try:
        species_names = selected_species(args)
        for scientific_name in species_names:
            if args.mode == "audit":
                audit_species(scientific_name)
            else:
                collect_species(
                    scientific_name,
                    args.target,
                    args.max_records,
                    args.max_images_per_record,
                    args.workers,
                )
    except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

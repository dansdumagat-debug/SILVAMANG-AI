from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

from collect_gbif_candidates import (
    CANDIDATE_ROOT,
    MANIFEST_PATH,
    NEW_SPECIES,
    append_manifest,
    download_image,
    existing_manifest,
    license_is_allowed,
    relative_path,
    safe_species_folder,
)


COMMONS_API = "https://commons.wikimedia.org/w/api.php"
COMMONS_USER_AGENT = (
    "SILVAMANG-AI-part-candidate-collector/1.0 "
    "(academic research; https://github.com/dansdumagat-debug/SILVAMANG-AI)"
)
SUPPORTED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
REQUEST_DELAY_SECONDS = 1.1
MAX_REQUEST_ATTEMPTS = 6
IMAGE_DOWNLOAD_DELAY_SECONDS = 2.5
MAX_IMAGE_DOWNLOAD_ATTEMPTS = 6
PART_SEARCH_TERMS = {
    "leaves": ("leaves", "leaf", "foliage", "leaf detail"),
    "flowers": ("flowers", "flower", "inflorescence", "blossom"),
    "roots": (
        "roots",
        "root",
        "pneumatophore",
        "aerial roots",
        "prop roots",
        "stilt roots",
        "buttress roots",
        "knee roots",
        "breathing roots",
        "root system",
    ),
    "bark": ("bark", "tree bark", "trunk", "stem", "lenticels"),
}
PART_MATCH_PATTERNS = {
    "leaves": (r"\bleaf\b", r"\bleaves\b", r"\bfoliage\b"),
    "flowers": (r"\bflowers?\b", r"\binflorescen\w*\b", r"\bblossoms?\b"),
    "roots": (
        r"\broots?\b",
        r"\bpneumatophores?\b",
        r"\b(?:aerial|prop|stilt|buttress|knee|breathing) roots?\b",
    ),
    "bark": (
        r"\bbark\b",
        r"\btrunks?\b",
        r"\bstems?\b",
        r"\blenticels?\b",
    ),
}


_last_request_at = 0.0


def wait_for_request_slot() -> None:
    global _last_request_at

    elapsed = time.monotonic() - _last_request_at
    if elapsed < REQUEST_DELAY_SECONDS:
        time.sleep(REQUEST_DELAY_SECONDS - elapsed)
    _last_request_at = time.monotonic()


def request_json(params: dict[str, Any]) -> dict[str, Any]:
    url = f"{COMMONS_API}?{urlencode(params, doseq=True)}"
    request = Request(
        url,
        headers={"User-Agent": COMMONS_USER_AGENT, "Accept": "application/json"},
    )
    last_error: Exception | None = None
    for attempt in range(MAX_REQUEST_ATTEMPTS):
        wait_for_request_slot()
        try:
            with urlopen(request, timeout=20) as response:
                return json.load(response)
        except (HTTPError, URLError, TimeoutError, OSError) as error:
            last_error = error
            if attempt >= MAX_REQUEST_ATTEMPTS - 1:
                break

            retry_after = 0.0
            if isinstance(error, HTTPError):
                try:
                    retry_after = float(error.headers.get("Retry-After") or 0)
                except (TypeError, ValueError):
                    retry_after = 0.0
            delay = max(retry_after, min(60.0, 2.0**attempt))
            print(
                f"  Commons request delayed for {delay:.0f}s after {error}; retrying...",
                file=sys.stderr,
                flush=True,
            )
            time.sleep(delay)
    raise OSError(f"Commons API request failed: {last_error}")


_last_download_at = 0.0


def download_commons_image(image_url: str) -> tuple[bytes, str]:
    global _last_download_at

    last_error: Exception | None = None
    for attempt in range(MAX_IMAGE_DOWNLOAD_ATTEMPTS):
        elapsed = time.monotonic() - _last_download_at
        if elapsed < IMAGE_DOWNLOAD_DELAY_SECONDS:
            time.sleep(IMAGE_DOWNLOAD_DELAY_SECONDS - elapsed)
        _last_download_at = time.monotonic()

        try:
            return download_image(image_url)
        except ValueError:
            raise
        except (HTTPError, URLError, TimeoutError, OSError) as error:
            last_error = error
            if isinstance(error, HTTPError) and error.code not in {429, 500, 502, 503, 504}:
                raise
            if attempt >= MAX_IMAGE_DOWNLOAD_ATTEMPTS - 1:
                break

            retry_after = 0.0
            if isinstance(error, HTTPError):
                try:
                    retry_after = float(error.headers.get("Retry-After") or 0)
                except (TypeError, ValueError):
                    retry_after = 0.0
            delay = max(retry_after, min(90.0, 3.0 * (2.0**attempt)))
            print(
                f"  Image request delayed for {delay:.0f}s after {error}; retrying...",
                file=sys.stderr,
                flush=True,
            )
            time.sleep(delay)
    raise OSError(f"Commons image download failed: {last_error}")


def metadata_value(metadata: dict[str, Any], key: str) -> str:
    entry = metadata.get(key)
    if isinstance(entry, dict):
        return str(entry.get("value") or "")
    return str(entry or "")


def plain_text(value: str) -> str:
    without_tags = re.sub(r"<[^>]+>", " ", value)
    decoded = html.unescape(without_tags).replace("_", " ")
    return " ".join(decoded.split())


def normalized_text(value: str) -> str:
    return plain_text(value).casefold()


def commons_license(metadata: dict[str, Any]) -> str | None:
    non_free = metadata_value(metadata, "NonFree").strip().casefold()
    if non_free in {"1", "true", "yes"}:
        return None

    license_url = plain_text(metadata_value(metadata, "LicenseUrl"))
    license_name = plain_text(metadata_value(metadata, "LicenseShortName"))
    usage_terms = plain_text(metadata_value(metadata, "UsageTerms"))
    combined = " ".join(value for value in (license_url, license_name, usage_terms) if value)
    if not license_is_allowed(combined):
        return None
    return license_url or license_name or usage_terms


def candidate_text(page: dict[str, Any], image_info: dict[str, Any]) -> str:
    metadata = image_info.get("extmetadata") or {}
    values = (
        str(page.get("title") or ""),
        metadata_value(metadata, "ObjectName"),
        metadata_value(metadata, "ImageDescription"),
        metadata_value(metadata, "Categories"),
    )
    return normalized_text(" ".join(values))


def is_relevant(page: dict[str, Any], image_info: dict[str, Any], species: str, part: str) -> bool:
    text = candidate_text(page, image_info)
    if species.casefold() not in text:
        return False
    return any(re.search(pattern, text) for pattern in PART_MATCH_PATTERNS[part])


def commons_pages(species: str, part: str, max_results: int) -> Iterable[dict[str, Any]]:
    yielded_ids: set[int] = set()
    for term in PART_SEARCH_TERMS[part]:
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
                "gsrsearch": f'"{species}" {term}',
                "gsrnamespace": 6,
                "gsrlimit": limit,
                "prop": "imageinfo",
                "iiprop": "url|extmetadata|mime|size",
                "iiurlwidth": 800,
            }
            if offset is not None:
                params["gsroffset"] = offset

            payload = request_json(params)
            pages = payload.get("query", {}).get("pages") or []
            checked += len(pages)
            for page in pages:
                page_id = int(page.get("pageid") or 0)
                if page_id and page_id not in yielded_ids:
                    yielded_ids.add(page_id)
                    yield page

            next_offset = payload.get("continue", {}).get("gsroffset")
            if next_offset is None or not pages:
                break
            offset = int(next_offset)
            time.sleep(REQUEST_DELAY_SECONDS)


def existing_rows() -> list[dict[str, str]]:
    if not MANIFEST_PATH.exists():
        return []
    with MANIFEST_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def existing_part_count(rows: list[dict[str, str]], species: str, part: str) -> int:
    marker = f"/suggested_{part}/"
    return sum(
        1
        for row in rows
        if row.get("scientific_name") == species
        and marker in str(row.get("file_path") or "")
        and str(row.get("review_status") or "pending").casefold() in {"pending", "approved"}
    )


def source_page_url(title: str) -> str:
    return f"https://commons.wikimedia.org/wiki/{quote(title.replace(' ', '_'), safe='():,_-')}"


def collect_part(
    species: str,
    part: str,
    target: int,
    max_search_results: int,
    audit_only: bool,
) -> tuple[int, int]:
    rows = existing_rows()
    existing = existing_part_count(rows, species, part)
    needed = max(0, target - existing)
    seen_urls, seen_hashes, _, _ = existing_manifest()
    seen_source_ids = {
        str(row.get("source_record_id") or "").strip()
        for row in rows
        if str(row.get("source_record_id") or "").strip()
    }
    qualified = 0
    downloaded = 0
    failures = 0
    destination = CANDIDATE_ROOT / safe_species_folder(species) / f"suggested_{part}"

    print(
        f"{species} [{part}]: target={target}, existing={existing}, needed={needed}",
        flush=True,
    )
    if needed == 0 and not audit_only:
        return existing, 0

    try:
        pages = commons_pages(species, part, max_search_results)
        for page in pages:
            image_info_rows = page.get("imageinfo") or []
            if not image_info_rows:
                continue
            image_info = image_info_rows[0]
            if str(image_info.get("mime") or "").casefold() not in SUPPORTED_MIME_TYPES:
                continue
            metadata = image_info.get("extmetadata") or {}
            license_value = commons_license(metadata)
            if not license_value or not is_relevant(page, image_info, species, part):
                continue

            image_url = str(image_info.get("thumburl") or image_info.get("url") or "").strip()
            page_id = str(page.get("pageid") or "unknown")
            source_record_id = f"commons:{page_id}"
            if source_record_id in seen_source_ids:
                continue
            if (
                not image_url.startswith(("https://", "http://"))
                or "/thumb/" not in image_url
                or image_url in seen_urls
            ):
                continue
            qualified += 1
            if audit_only:
                continue
            if downloaded >= needed:
                break

            try:
                payload, extension = download_commons_image(image_url)
            except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
                failures += 1
                print(f"  skip {image_url}: {error}", file=sys.stderr, flush=True)
                continue

            seen_urls.add(image_url)
            digest = hashlib.sha256(payload).hexdigest()
            if digest in seen_hashes:
                continue

            candidate_id = f"commons_{page_id}_{digest[:10]}"
            destination.mkdir(parents=True, exist_ok=True)
            output_path = destination / f"{candidate_id}{extension}"
            output_path.write_bytes(payload)
            seen_hashes.add(digest)

            title = str(page.get("title") or "")
            artist = plain_text(metadata_value(metadata, "Artist"))
            credit = plain_text(metadata_value(metadata, "Credit"))
            append_manifest(
                {
                    "candidate_id": candidate_id,
                    "file_path": relative_path(output_path),
                    "scientific_name": species,
                    "reviewed_plant_part": "",
                    "source": "Wikimedia Commons targeted search",
                    "source_record_id": source_record_id,
                    "source_record_url": source_page_url(title),
                    "source_image_url": image_url,
                    "creator": artist,
                    "rights_holder": credit or artist,
                    "license": license_value,
                    "country": "",
                    "state_province": "",
                    "locality": "",
                    "downloaded_at": datetime.now(timezone.utc).isoformat(),
                    "sha256": digest,
                    "review_status": "pending",
                    "review_notes": (
                        f"Search suggestion: {part}. Confirm the exact species and visible plant part "
                        "before approval; Commons search metadata is not a verified training label."
                    ),
                }
            )
            downloaded += 1
            seen_source_ids.add(source_record_id)
            print(f"  downloaded {existing + downloaded}/{target}: {output_path.name}", flush=True)
    except OSError as error:
        failures += 1
        print(f"  search failed: {error}", file=sys.stderr, flush=True)

    if audit_only:
        print(f"  audit qualifying_results={qualified}", flush=True)
        return qualified, failures

    total = existing + downloaded
    print(
        f"  added={downloaded}, total={total}, qualifying_results={qualified}, failures={failures}",
        flush=True,
    )
    if total < target:
        print("  WARNING: target not reached; field collection or expert-contributed images are needed.")
    return total, failures


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
        description="Collect licensed Wikimedia Commons candidates suggested by plant-part search terms."
    )
    parser.add_argument("--mode", choices=("audit", "download"), default="audit")
    parser.add_argument("--all-new", action="store_true", help="Process the 20 new guide species.")
    parser.add_argument("--species", action="append", help="Scientific name; repeat as needed.")
    parser.add_argument(
        "--part",
        action="append",
        choices=tuple(PART_SEARCH_TERMS),
        required=True,
        help="Suggested plant part; repeat for multiple parts.",
    )
    parser.add_argument("--target-per-part", type=int, default=10)
    parser.add_argument("--max-search-results", type=int, default=100)
    args = parser.parse_args()
    if not 1 <= args.target_per_part <= 100:
        parser.error("--target-per-part must be between 1 and 100")
    if not 1 <= args.max_search_results <= 500:
        parser.error("--max-search-results must be between 1 and 500")
    return args


def main() -> int:
    args = parse_args()
    try:
        species_names = selected_species(args)
        parts = list(dict.fromkeys(args.part))
        for species in species_names:
            for part in parts:
                collect_part(
                    species,
                    part,
                    args.target_per_part,
                    args.max_search_results,
                    args.mode == "audit",
                )
    except (ValueError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import time
from datetime import datetime, timezone
from typing import Any, Iterable
from urllib.error import HTTPError, URLError

from collect_commons_part_candidates import (
    COMMONS_API,
    REQUEST_DELAY_SECONDS,
    SUPPORTED_MIME_TYPES,
    candidate_text,
    commons_license,
    download_commons_image,
    existing_rows,
    metadata_value,
    plain_text,
    request_json,
    source_page_url,
)
from collect_gbif_candidates import (
    CANDIDATE_ROOT,
    NEW_SPECIES,
    append_manifest,
    existing_manifest,
    relative_path,
    safe_species_folder,
)


NON_FIELD_PATTERNS = (
    r"\bherbarium\b",
    r"\bpressed specimen\b",
    r"\btype specimen\b",
    r"\bbotanical illustration\b",
    r"\bdrawing\b",
    r"\bengraving\b",
    r"\batlas der\b",
    r"\bblanco2\b",
    r"\bdistribution map\b",
    r"\brange map\b",
)


def commons_species_pages(species: str, max_results: int) -> Iterable[dict[str, Any]]:
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
            "gsrsearch": f'"{species}"',
            "gsrnamespace": 6,
            "gsrlimit": limit,
            "prop": "imageinfo",
            "iiprop": "url|extmetadata|mime|size",
            "iiurlwidth": 960,
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
        time.sleep(REQUEST_DELAY_SECONDS)


def is_field_species_image(page: dict[str, Any], image_info: dict[str, Any], species: str) -> bool:
    text = candidate_text(page, image_info)
    if species.casefold() not in text:
        return False
    return not any(re.search(pattern, text) for pattern in NON_FIELD_PATTERNS)


def collect_species(species: str, target: int, max_search_results: int) -> None:
    rows = existing_rows()
    seen_urls, seen_hashes, species_counts, _ = existing_manifest()
    seen_source_ids = {
        str(row.get("source_record_id") or "").strip()
        for row in rows
        if str(row.get("source_record_id") or "").strip()
    }
    existing = species_counts.get(species, 0)
    needed = max(0, target - existing)
    print(f"{species}: target={target}, existing={existing}, needed={needed}", flush=True)
    if needed == 0:
        return

    destination = CANDIDATE_ROOT / safe_species_folder(species) / "unclassified"
    downloaded = 0
    qualified = 0
    duplicates = 0
    failures = 0

    try:
        for page in commons_species_pages(species, max_search_results):
            image_info_rows = page.get("imageinfo") or []
            if not image_info_rows:
                continue
            image_info = image_info_rows[0]
            if str(image_info.get("mime") or "").casefold() not in SUPPORTED_MIME_TYPES:
                continue
            metadata = image_info.get("extmetadata") or {}
            license_value = commons_license(metadata)
            if not license_value or not is_field_species_image(page, image_info, species):
                continue

            page_id = str(page.get("pageid") or "unknown")
            source_record_id = f"commons:{page_id}"
            image_url = str(image_info.get("thumburl") or image_info.get("url") or "").strip()
            if source_record_id in seen_source_ids or image_url in seen_urls:
                duplicates += 1
                continue
            if not image_url.startswith(("https://", "http://")):
                continue
            qualified += 1
            if downloaded >= needed:
                break

            try:
                payload, extension = download_commons_image(image_url)
            except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
                failures += 1
                print(f"  skip {image_url}: {error}", file=sys.stderr, flush=True)
                continue

            digest = hashlib.sha256(payload).hexdigest()
            seen_urls.add(image_url)
            if digest in seen_hashes:
                duplicates += 1
                continue

            candidate_id = f"commons_{page_id}_{digest[:10]}"
            destination.mkdir(parents=True, exist_ok=True)
            output_path = destination / f"{candidate_id}{extension}"
            output_path.write_bytes(payload)
            seen_hashes.add(digest)
            seen_source_ids.add(source_record_id)
            title = str(page.get("title") or "")
            artist = plain_text(metadata_value(metadata, "Artist"))
            credit = plain_text(metadata_value(metadata, "Credit"))
            append_manifest(
                {
                    "candidate_id": candidate_id,
                    "file_path": relative_path(output_path),
                    "scientific_name": species,
                    "reviewed_plant_part": "",
                    "source": "Wikimedia Commons species search",
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
                        "General Wikimedia Commons species candidate. Confirm species and assign "
                        "leaves, bark, roots, or flowers before training."
                    ),
                }
            )
            downloaded += 1
            print(f"  downloaded {existing + downloaded}/{target}: {output_path.name}", flush=True)
    except OSError as error:
        failures += 1
        print(f"  search failed: {error}", file=sys.stderr, flush=True)

    print(
        f"{species}: added={downloaded}, total={existing + downloaded}, qualified={qualified}, "
        f"duplicates={duplicates}, failures={failures}",
        flush=True,
    )
    if existing + downloaded < target:
        print("  WARNING: reusable field-photo search results were exhausted before the target.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect reusable Wikimedia Commons species-photo candidates for manual review."
    )
    parser.add_argument("--all-new", action="store_true", help="Process the 20 new guide species.")
    parser.add_argument("--species", action="append", help="Scientific name; repeat as needed.")
    parser.add_argument("--target", type=int, default=100)
    parser.add_argument("--max-search-results", type=int, default=500)
    args = parser.parse_args()
    if not 1 <= args.target <= 5000:
        parser.error("--target must be between 1 and 5000")
    if not 1 <= args.max_search_results <= 500:
        parser.error("--max-search-results must be between 1 and 500")
    return args


def selected_species(args: argparse.Namespace) -> list[str]:
    values = list(NEW_SPECIES) if args.all_new else list(args.species or [])
    names: list[str] = []
    for value in values:
        normalized = " ".join(value.replace("_", " ").split())
        if normalized and normalized not in names:
            names.append(normalized)
    if not names:
        raise ValueError("Choose --all-new or provide at least one --species value.")
    return names


def main() -> int:
    args = parse_args()
    try:
        for species in selected_species(args):
            collect_species(species, args.target, args.max_search_results)
    except (ValueError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

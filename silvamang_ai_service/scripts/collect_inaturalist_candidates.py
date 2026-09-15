from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from collect_gbif_candidates import (
    CANDIDATE_ROOT,
    MANIFEST_PATH,
    NEW_SPECIES,
    USER_AGENT,
    append_manifest,
    download_result,
    existing_manifest,
    relative_path,
    safe_species_folder,
)


INAT_API = "https://api.inaturalist.org/v1"
ALLOWED_PHOTO_LICENSES = {"cc0", "cc-by", "cc-by-sa"}
PHOTO_ID_PATTERN = re.compile(r"/photos/(\d+)/", re.IGNORECASE)
PAGE_SIZE = 200
DOWNLOAD_BATCH_SIZE = 24
API_RETRY_DELAYS_SECONDS = (2, 5, 10)


def request_json(path: str, params: dict[str, Any]) -> dict[str, Any]:
    url = f"{INAT_API}/{path}?{urlencode(params)}"
    request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    for attempt in range(len(API_RETRY_DELAYS_SECONDS) + 1):
        try:
            with urlopen(request, timeout=45) as response:
                return json.load(response)
        except (HTTPError, URLError, TimeoutError, OSError):
            if attempt >= len(API_RETRY_DELAYS_SECONDS):
                raise
            time.sleep(API_RETRY_DELAYS_SECONDS[attempt])
    raise RuntimeError("unreachable")


def resolve_taxon(scientific_name: str) -> tuple[int, int]:
    payload = request_json(
        "taxa",
        {
            "q": scientific_name,
            "rank": "species",
            "is_active": "true",
            "per_page": 30,
        },
    )
    for taxon in payload.get("results") or []:
        if str(taxon.get("name") or "").casefold() == scientific_name.casefold():
            return int(taxon["id"]), int(taxon.get("observations_count") or 0)
    raise ValueError(f"iNaturalist did not return an exact active species for {scientific_name!r}.")


def observation_page(taxon_id: int, page: int) -> dict[str, Any]:
    return request_json(
        "observations",
        {
            "taxon_id": taxon_id,
            "photos": "true",
            "quality_grade": "research",
            "photo_license": ",".join(sorted(ALLOWED_PHOTO_LICENSES)),
            "per_page": PAGE_SIZE,
            "page": page,
            "order_by": "created_at",
            "order": "desc",
        },
    )


def photo_id_from_url(value: str) -> str:
    match = PHOTO_ID_PATTERN.search(value)
    return match.group(1) if match else ""


def existing_photo_ids() -> set[str]:
    ids: set[str] = set()
    if not MANIFEST_PATH.exists():
        return ids
    with MANIFEST_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            photo_id = photo_id_from_url(str(row.get("source_image_url") or ""))
            if photo_id:
                ids.add(photo_id)
    return ids


def exact_or_descendant_taxon(observation: dict[str, Any], species_taxon_id: int) -> bool:
    taxon = observation.get("taxon") or {}
    return int(taxon.get("id") or 0) == species_taxon_id or species_taxon_id in {
        int(value) for value in (taxon.get("ancestor_ids") or [])
    }


def original_photo_url(photo: dict[str, Any]) -> str:
    url = str(photo.get("url") or "").strip()
    for size in ("square", "small", "medium", "large"):
        url = url.replace(f"/{size}.", "/original.")
    return url


def collect_species(scientific_name: str, target: int, max_pages: int, workers: int) -> None:
    taxon_id, observation_count = resolve_taxon(scientific_name)
    seen_urls, seen_hashes, species_counts, _ = existing_manifest()
    seen_photo_ids = existing_photo_ids()
    already_downloaded = species_counts.get(scientific_name, 0)
    needed = max(0, target - already_downloaded)
    print(
        f"{scientific_name}: target={target}, existing={already_downloaded}, needed={needed}, "
        f"iNaturalist taxon={taxon_id}, observations={observation_count}",
        flush=True,
    )
    if needed == 0:
        return

    destination = CANDIDATE_ROOT / safe_species_folder(scientific_name) / "unclassified"
    destination.mkdir(parents=True, exist_ok=True)
    downloaded = 0
    duplicates = 0
    failures = 0
    observations_checked = 0

    for page_number in range(1, max_pages + 1):
        page = observation_page(taxon_id, page_number)
        observations = page.get("results") or []
        if not observations:
            break
        observations_checked += len(observations)

        queued_photo_ids: set[str] = set()
        tasks: list[tuple[dict[str, Any], dict[str, Any], str, str]] = []
        for observation in observations:
            if not exact_or_descendant_taxon(observation, taxon_id):
                continue
            for photo in observation.get("photos") or []:
                photo_id = str(photo.get("id") or "")
                license_code = str(photo.get("license_code") or "").strip().lower()
                source_url = original_photo_url(photo)
                if license_code not in ALLOWED_PHOTO_LICENSES or not source_url.startswith("https://"):
                    continue
                if photo_id in seen_photo_ids or photo_id in queued_photo_ids or source_url in seen_urls:
                    duplicates += 1
                    continue
                queued_photo_ids.add(photo_id)
                tasks.append((observation, photo, photo_id, source_url))

        task_index = 0
        while downloaded < needed and task_index < len(tasks):
            remaining = needed - downloaded
            batch_size = min(DOWNLOAD_BATCH_SIZE, remaining, len(tasks) - task_index)
            batch = tasks[task_index : task_index + batch_size]
            task_index += batch_size
            urls = [task[3] for task in batch]
            with ThreadPoolExecutor(max_workers=min(workers, batch_size)) as executor:
                results = list(executor.map(download_result, urls))

            for task, result in zip(batch, results):
                observation, photo, photo_id, source_url = task
                payload, extension, error = result
                if error is not None or payload is None or extension is None:
                    failures += 1
                    print(f"  skip photo {photo_id}: {error}", file=sys.stderr, flush=True)
                    continue

                digest = hashlib.sha256(payload).hexdigest()
                seen_urls.add(source_url)
                seen_photo_ids.add(photo_id)
                if digest in seen_hashes:
                    duplicates += 1
                    continue

                observation_id = str(observation.get("id") or "")
                candidate_id = f"inat_{observation_id}_{photo_id}_{digest[:10]}"
                output_path = destination / f"{candidate_id}{extension}"
                output_path.write_bytes(payload)
                seen_hashes.add(digest)
                attribution = str(photo.get("attribution") or "")
                append_manifest(
                    {
                        "candidate_id": candidate_id,
                        "file_path": relative_path(output_path),
                        "scientific_name": scientific_name,
                        "reviewed_plant_part": "",
                        "source": "iNaturalist research-grade observation",
                        "source_record_id": f"inat:{observation_id}",
                        "source_record_url": f"https://www.inaturalist.org/observations/{observation_id}",
                        "source_image_url": source_url,
                        "creator": attribution,
                        "rights_holder": attribution,
                        "license": str(photo.get("license_code") or ""),
                        "country": "",
                        "state_province": "",
                        "locality": observation.get("place_guess") or "",
                        "downloaded_at": datetime.now(timezone.utc).isoformat(),
                        "sha256": digest,
                        "review_status": "pending",
                        "review_notes": (
                            "Research-grade iNaturalist candidate. Confirm species and assign leaves, "
                            "bark, roots, or flowers before training."
                        ),
                    }
                )
                downloaded += 1
                print(
                    f"  downloaded {already_downloaded + downloaded}/{target}: {output_path.name}",
                    flush=True,
                )
                if downloaded >= needed:
                    break

        if downloaded >= needed or len(observations) < PAGE_SIZE:
            break
        time.sleep(1)

    print(
        f"{scientific_name}: added={downloaded}, total={already_downloaded + downloaded}, "
        f"duplicates={duplicates}, failures={failures}, observations_checked={observations_checked}",
        flush=True,
    )
    if already_downloaded + downloaded < target:
        print("  WARNING: reusable research-grade photos were exhausted before the target.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download reusable iNaturalist research-grade photos for manual dataset review."
    )
    parser.add_argument("--all-new", action="store_true", help="Process the 20 new guide species.")
    parser.add_argument("--species", action="append", help="Scientific name; repeat as needed.")
    parser.add_argument("--target", type=int, default=100)
    parser.add_argument("--max-pages", type=int, default=20)
    parser.add_argument("--workers", type=int, default=6)
    args = parser.parse_args()
    if not 1 <= args.target <= 5000:
        parser.error("--target must be between 1 and 5000")
    if not 1 <= args.max_pages <= 50:
        parser.error("--max-pages must be between 1 and 50")
    if not 1 <= args.workers <= 16:
        parser.error("--workers must be between 1 and 16")
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
        for scientific_name in selected_species(args):
            collect_species(scientific_name, args.target, args.max_pages, args.workers)
    except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import argparse
import csv
import html
import mimetypes
import os
import threading
from collections import Counter
from datetime import datetime, timezone
from functools import lru_cache
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from pathlib import Path
from tempfile import NamedTemporaryFile
from urllib.parse import parse_qs, urlencode, urlparse

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = PROJECT_ROOT / "dataset" / "metadata" / "candidate_image_manifest.csv"
CANDIDATE_ROOT = (PROJECT_ROOT / "dataset" / "candidates").resolve()
ALLOWED_STATUSES = {"all", "pending", "approved", "rejected", "flagged"}
APPROVED_PARTS = {"leaves", "bark", "roots", "flowers"}
ALLOWED_SUGGESTED_PARTS = {"all", "unclassified", *APPROVED_PARTS}
MANIFEST_LOCK = threading.Lock()
PREVIEW_MAX_DIMENSION = 2400
Image.MAX_IMAGE_PIXELS = 200_000_000


def read_manifest() -> tuple[list[str], list[dict[str, str]]]:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Candidate manifest not found: {MANIFEST_PATH}")

    with MANIFEST_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def update_review(
    candidate_id: str,
    review_status: str,
    plant_part: str,
    review_notes: str,
) -> bool:
    with MANIFEST_LOCK:
        fieldnames, rows = read_manifest()
        updated = False
        reviewed_at = datetime.now(timezone.utc).isoformat(timespec="seconds")

        for row in rows:
            if row.get("candidate_id") != candidate_id:
                continue

            row["review_status"] = review_status
            row["reviewed_plant_part"] = plant_part if review_status == "approved" else ""
            note = review_notes.strip()
            row["review_notes"] = note or f"Reviewed locally at {reviewed_at}."
            updated = True
            break

        if not updated:
            return False

        MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
        with NamedTemporaryFile(
            "w",
            encoding="utf-8",
            newline="",
            dir=MANIFEST_PATH.parent,
            prefix="candidate_manifest_",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            writer = csv.DictWriter(temporary, fieldnames=fieldnames, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(rows)
            temporary_path = Path(temporary.name)

        os.replace(temporary_path, MANIFEST_PATH)
        return True


def safe_candidate_path(row: dict[str, str]) -> Path | None:
    relative = row.get("file_path", "").strip()
    if not relative:
        return None

    candidate_path = (PROJECT_ROOT / relative).resolve()
    try:
        candidate_path.relative_to(CANDIDATE_ROOT)
    except ValueError:
        return None
    return candidate_path if candidate_path.is_file() else None


@lru_cache(maxsize=32)
def candidate_preview(path_value: str, modified_ns: int) -> tuple[bytes, str]:
    del modified_ns
    candidate_path = Path(path_value)
    with Image.open(candidate_path) as image:
        if max(image.size) <= PREVIEW_MAX_DIMENSION:
            media_type = mimetypes.guess_type(candidate_path.name)[0] or "application/octet-stream"
            return candidate_path.read_bytes(), media_type

        image.draft("RGB", (PREVIEW_MAX_DIMENSION, PREVIEW_MAX_DIMENSION))
        image.thumbnail((PREVIEW_MAX_DIMENSION, PREVIEW_MAX_DIMENSION))
        preview = image.convert("RGB")
        output = BytesIO()
        preview.save(output, format="JPEG", quality=86, optimize=True)
        return output.getvalue(), "image/jpeg"


def escaped(value: object) -> str:
    return html.escape(str(value or ""), quote=True)


def option(value: str, selected: str, label: str | None = None) -> str:
    selected_attribute = " selected" if value == selected else ""
    return f'<option value="{escaped(value)}"{selected_attribute}>{escaped(label or value)}</option>'


def suggested_part_for(row: dict[str, str]) -> str:
    candidate_parent = Path(row.get("file_path", "")).parent.name
    if candidate_parent.startswith("suggested_"):
        part = candidate_parent.removeprefix("suggested_").casefold()
        if part in APPROVED_PARTS:
            return part
    return "unclassified"


class CandidateReviewHandler(BaseHTTPRequestHandler):
    server_version = "SILVAMANGCandidateReview/1.0"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self.render_review(parse_qs(parsed.query))
            return
        if parsed.path == "/candidate-image":
            self.serve_candidate_image(parse_qs(parsed.query))
            return
        if parsed.path == "/health":
            self.send_text(HTTPStatus.OK, "ok", "text/plain; charset=utf-8")
            return
        self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/review":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        try:
            content_length = min(int(self.headers.get("Content-Length", "0")), 64 * 1024)
        except ValueError:
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid request size")
            return

        form = parse_qs(self.rfile.read(content_length).decode("utf-8"))
        candidate_id = form.get("candidate_id", [""])[0]
        action = form.get("action", [""])[0]
        notes = form.get("review_notes", [""])[0]

        if action in APPROVED_PARTS:
            status, part = "approved", action
        elif action in {"rejected", "flagged", "pending"}:
            status, part = action, ""
        else:
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid review action")
            return

        if not update_review(candidate_id, status, part, notes):
            self.send_error(HTTPStatus.NOT_FOUND, "Candidate not found")
            return

        redirect_query = urlencode(
            {
                "species": form.get("filter_species", ["all"])[0],
                "status": form.get("filter_status", ["pending"])[0],
                "part": form.get("filter_part", ["all"])[0],
                "index": form.get("index", ["0"])[0],
            }
        )
        self.send_response(HTTPStatus.SEE_OTHER)
        self.send_header("Location", f"/?{redirect_query}")
        self.end_headers()

    def render_review(self, query: dict[str, list[str]]) -> None:
        _, rows = read_manifest()
        species_values = sorted(
            {row.get("scientific_name", "") for row in rows if row.get("scientific_name")}
        )
        selected_species = query.get("species", ["all"])[0]
        selected_status = query.get("status", ["pending"])[0]
        selected_part = query.get("part", ["all"])[0]
        if selected_species != "all" and selected_species not in species_values:
            selected_species = "all"
        if selected_status not in ALLOWED_STATUSES:
            selected_status = "pending"
        if selected_part not in ALLOWED_SUGGESTED_PARTS:
            selected_part = "all"

        filtered = [
            row
            for row in rows
            if (selected_species == "all" or row.get("scientific_name") == selected_species)
            and (selected_status == "all" or row.get("review_status", "pending") == selected_status)
            and (selected_part == "all" or suggested_part_for(row) == selected_part)
        ]
        filtered.sort(key=lambda row: (row.get("scientific_name", ""), row.get("downloaded_at", "")))

        try:
            requested_index = int(query.get("index", ["0"])[0])
        except ValueError:
            requested_index = 0
        index = max(0, min(requested_index, max(0, len(filtered) - 1)))

        status_counts = Counter(row.get("review_status") or "pending" for row in rows)
        part_counts = Counter(
            row.get("reviewed_plant_part")
            for row in rows
            if row.get("review_status") == "approved" and row.get("reviewed_plant_part")
        )
        species_options = option("all", selected_species, "All species") + "".join(
            option(species, selected_species) for species in species_values
        )
        status_options = "".join(
            option(status, selected_status, status.title())
            for status in ("pending", "approved", "rejected", "flagged", "all")
        )
        part_options = "".join(
            option(part, selected_part, label)
            for part, label in (
                ("all", "All suggested parts"),
                ("leaves", "Suggested: Leaves"),
                ("flowers", "Suggested: Flowers"),
                ("roots", "Suggested: Roots"),
                ("bark", "Suggested: Bark"),
                ("unclassified", "Unclassified"),
            )
        )

        if filtered:
            row = filtered[index]
            image_query = urlencode({"id": row.get("candidate_id", "")})
            previous_index = max(0, index - 1)
            next_index = min(len(filtered) - 1, index + 1)
            base_filters = {
                "species": selected_species,
                "status": selected_status,
                "part": selected_part,
            }
            previous_url = "/?" + urlencode({**base_filters, "index": previous_index})
            next_url = "/?" + urlencode({**base_filters, "index": next_index})
            source_url = row.get("source_record_url", "")
            source_link = (
                f'<a href="{escaped(source_url)}" target="_blank" rel="noreferrer">Open source record</a>'
                if source_url
                else "No source record"
            )
            display_notes = row.get("review_notes", "")
            if row.get("review_status") == "pending" and display_notes.startswith("Confirm species"):
                display_notes = ""
            suggested_part = suggested_part_for(row).title()
            current_content = f"""
                <main class="review-layout">
                  <section class="image-stage">
                    <img src="/candidate-image?{image_query}" alt="Candidate {escaped(row.get('candidate_id'))}">
                  </section>
                  <aside class="review-panel">
                    <div class="position">Candidate {index + 1} of {len(filtered)}</div>
                    <h1>{escaped(row.get('scientific_name'))}</h1>
                    <dl>
                      <dt>Status</dt><dd>{escaped(row.get('review_status') or 'pending')}</dd>
                      <dt>Suggested part</dt><dd>{escaped(suggested_part)}</dd>
                      <dt>Candidate ID</dt><dd>{escaped(row.get('candidate_id'))}</dd>
                      <dt>Country</dt><dd>{escaped(row.get('country') or 'Unknown')}</dd>
                      <dt>Creator</dt><dd>{escaped(row.get('creator') or 'Unknown')}</dd>
                      <dt>License</dt><dd>{escaped(row.get('license') or 'Unknown')}</dd>
                      <dt>Source</dt><dd>{source_link}</dd>
                    </dl>
                    <form method="post" action="/review">
                      <input type="hidden" name="candidate_id" value="{escaped(row.get('candidate_id'))}">
                      <input type="hidden" name="filter_species" value="{escaped(selected_species)}">
                      <input type="hidden" name="filter_status" value="{escaped(selected_status)}">
                      <input type="hidden" name="filter_part" value="{escaped(selected_part)}">
                      <input type="hidden" name="index" value="{index}">
                      <label for="review-notes">Review notes</label>
                      <textarea id="review-notes" name="review_notes" rows="3">{escaped(display_notes)}</textarea>
                      <div class="part-actions">
                        <button class="approve" name="action" value="leaves">Approve: Leaves</button>
                        <button class="approve" name="action" value="bark">Approve: Bark</button>
                        <button class="approve" name="action" value="roots">Approve: Roots</button>
                        <button class="approve" name="action" value="flowers">Approve: Flowers</button>
                      </div>
                      <div class="secondary-actions">
                        <button class="reject" name="action" value="rejected">Reject</button>
                        <button class="flag" name="action" value="flagged">Flag</button>
                        <button name="action" value="pending">Reset Pending</button>
                      </div>
                    </form>
                    <nav>
                      <a class="nav-button" href="{previous_url}">Previous</a>
                      <a class="nav-button" href="{next_url}">Next</a>
                    </nav>
                  </aside>
                </main>
            """
        else:
            current_content = """
                <main class="empty-state">
                  <h1>No candidates match this filter</h1>
                  <p>Choose another species, review status, or suggested part.</p>
                </main>
            """

        document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SILVAMANG Candidate Review</title>
  <style>
    :root {{ color-scheme: light; font-family: Arial, sans-serif; background: #f3f6f3; color: #17221d; }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; }}
    header {{ display: flex; align-items: center; gap: 20px; padding: 14px 22px; background: #123f30; color: white; }}
    header strong {{ font-size: 18px; white-space: nowrap; }}
    .filters {{ display: flex; gap: 10px; flex: 1; }}
    select, textarea, button, .nav-button {{ font: inherit; border-radius: 6px; }}
    select {{ min-width: 170px; border: 1px solid #bed0c6; padding: 9px 12px; background: white; }}
    .counts {{ display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px 12px; font-size: 13px; white-space: nowrap; }}
    .part-count {{ color: #d7f6e5; }}
    .review-layout {{ min-height: calc(100vh - 66px); display: grid; grid-template-columns: minmax(0, 1fr) 390px; }}
    .image-stage {{ display: grid; place-items: center; min-height: 0; padding: 20px; background: #202522; }}
    .image-stage img {{ display: block; max-width: 100%; max-height: calc(100vh - 106px); object-fit: contain; }}
    .review-panel {{ padding: 22px; overflow: auto; background: white; border-left: 1px solid #d7e0da; }}
    .position {{ color: #627269; font-size: 14px; }}
    h1 {{ margin: 7px 0 18px; font-size: 25px; letter-spacing: 0; }}
    dl {{ display: grid; grid-template-columns: 90px 1fr; gap: 8px 12px; margin: 0 0 20px; font-size: 14px; }}
    dt {{ color: #627269; }}
    dd {{ margin: 0; overflow-wrap: anywhere; }}
    a {{ color: #146b48; }}
    label {{ display: block; margin-bottom: 6px; font-size: 14px; font-weight: 700; }}
    textarea {{ width: 100%; resize: vertical; border: 1px solid #bed0c6; padding: 9px; }}
    .part-actions {{ display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 12px; }}
    .secondary-actions {{ display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; margin-top: 8px; }}
    button, .nav-button {{ min-height: 42px; border: 1px solid #a8b9af; padding: 9px 12px; background: #eef3f0; color: #17221d; cursor: pointer; text-align: center; text-decoration: none; }}
    button:hover, .nav-button:hover {{ filter: brightness(.96); }}
    button.approve {{ border-color: #19734d; background: #19734d; color: white; }}
    button.reject {{ border-color: #ad3434; color: #8c2020; background: #fff1f1; }}
    button.flag {{ border-color: #b47a17; color: #6d4707; background: #fff7df; }}
    nav {{ display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 18px; }}
    .empty-state {{ min-height: calc(100vh - 66px); display: grid; place-content: center; text-align: center; }}
    .empty-state h1 {{ margin-bottom: 0; }}
    @media (max-width: 850px) {{
      header {{ align-items: stretch; flex-direction: column; gap: 10px; }}
      .filters {{ flex-wrap: wrap; }}
      select {{ flex: 1; min-width: 140px; }}
      .counts {{ flex-wrap: wrap; }}
      .review-layout {{ grid-template-columns: 1fr; }}
      .image-stage {{ min-height: 48vh; }}
      .image-stage img {{ max-height: 46vh; }}
      .review-panel {{ border-left: 0; border-top: 1px solid #d7e0da; }}
    }}
  </style>
</head>
<body>
  <header>
    <strong>SILVAMANG Candidate Review</strong>
    <form class="filters" method="get" action="/">
      <select name="species" aria-label="Species filter">{species_options}</select>
      <select name="status" aria-label="Status filter">{status_options}</select>
      <select name="part" aria-label="Suggested part filter">{part_options}</select>
      <button type="submit">Apply Filter</button>
    </form>
    <div class="counts">
      <span>Pending: {status_counts['pending']}</span>
      <span>Approved: {status_counts['approved']}</span>
      <span>Rejected: {status_counts['rejected']}</span>
      <span>Flagged: {status_counts['flagged']}</span>
      <span class="part-count">Approved Leaves: {part_counts['leaves']}</span>
      <span class="part-count">Approved Bark: {part_counts['bark']}</span>
      <span class="part-count">Approved Roots: {part_counts['roots']}</span>
      <span class="part-count">Approved Flowers: {part_counts['flowers']}</span>
    </div>
  </header>
  {current_content}
</body>
</html>"""
        self.send_text(HTTPStatus.OK, document, "text/html; charset=utf-8")

    def serve_candidate_image(self, query: dict[str, list[str]]) -> None:
        candidate_id = query.get("id", [""])[0]
        _, rows = read_manifest()
        row = next((item for item in rows if item.get("candidate_id") == candidate_id), None)
        candidate_path = safe_candidate_path(row) if row else None
        if candidate_path is None:
            self.send_error(HTTPStatus.NOT_FOUND, "Candidate image not found")
            return

        try:
            payload, media_type = candidate_preview(
                str(candidate_path),
                candidate_path.stat().st_mtime_ns,
            )
        except (OSError, ValueError) as error:
            self.send_error(HTTPStatus.UNPROCESSABLE_ENTITY, f"Preview failed: {error}")
            return

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", media_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def send_text(self, status: HTTPStatus, content: str, media_type: str) -> None:
        payload = content.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", media_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format_string: str, *args: object) -> None:
        print(f"[{self.log_date_time_string()}] {format_string % args}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Review downloaded GBIF candidates in a local browser.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8765, type=int)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    read_manifest()
    server = ThreadingHTTPServer((args.host, args.port), CandidateReviewHandler)
    print(f"Candidate reviewer: http://{args.host}:{args.port}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

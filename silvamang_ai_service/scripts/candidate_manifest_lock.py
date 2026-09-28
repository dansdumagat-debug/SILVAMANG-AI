from __future__ import annotations

import os
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator


class CandidateManifestBusyError(RuntimeError):
    """Raised when another process is already updating the candidate manifest."""


def lock_path_for(manifest_path: Path) -> Path:
    manifest = Path(manifest_path)
    return manifest.with_name(f".{manifest.name}.lock")


@contextmanager
def candidate_manifest_write_lock(manifest_path: Path) -> Iterator[None]:
    """Coordinate atomic manifest replacements across local review processes."""

    lock_path = lock_path_for(manifest_path)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise CandidateManifestBusyError(
            f"Candidate manifest is being updated by another process: {lock_path}"
        ) from exc

    try:
        details = (
            f"pid={os.getpid()}\n"
            f"created_at={datetime.now(timezone.utc).isoformat()}\n"
        ).encode("utf-8")
        os.write(descriptor, details)
        os.close(descriptor)
        descriptor = -1
        yield
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        lock_path.unlink(missing_ok=True)

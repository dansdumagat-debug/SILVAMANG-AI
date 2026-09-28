from __future__ import annotations

import shutil
import uuid
from pathlib import Path

import pytest


@pytest.fixture
def tmp_path() -> Path:
    """Workspace-local replacement for pytest temp dirs on restricted Windows hosts."""

    root = Path(__file__).resolve().parent / ".test-artifacts"
    root.mkdir(exist_ok=True)
    directory = root / f"test-{uuid.uuid4().hex}"
    directory.mkdir()
    try:
        yield directory
    finally:
        shutil.rmtree(directory, ignore_errors=True)

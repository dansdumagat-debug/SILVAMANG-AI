from __future__ import annotations

import hashlib
import re
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
from typing import Iterable


SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
PART_ALIASES = {
    "leaf": "leaves",
    "leaves": "leaves",
    "bark": "bark",
    "barks": "bark",
    "root": "roots",
    "roots": "roots",
    "flower": "flowers",
    "flowers": "flowers",
}


def species_folder_name(scientific_name: str) -> str:
    return "_".join(scientific_name.strip().split())


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


@lru_cache(maxsize=8192)
def _sha256(path_value: str, size: int, modified_ns: int) -> str:
    del size, modified_ns
    digest = hashlib.sha256()
    with Path(path_value).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_for(path: Path) -> str:
    stat = path.stat()
    return _sha256(str(path), stat.st_size, stat.st_mtime_ns)


class CandidatePathResolver:
    """Resolve manifest entries after candidates have moved into part folders.

    Resolution is deliberately limited to the candidate root and, when supplied,
    the species folder recorded by the manifest. A stored SHA-256 value is treated
    as authoritative so that a reused filename cannot silently select another
    image.
    """

    def __init__(self, project_root: Path, candidate_root: Path) -> None:
        self.project_root = project_root.resolve()
        self.candidate_root = candidate_root.resolve()
        self._by_name: dict[str, list[Path]] | None = None
        self._by_stem: dict[str, list[Path]] | None = None

    def refresh(self) -> None:
        self._by_name = None
        self._by_stem = None

    def _build_index(self) -> None:
        by_name: dict[str, list[Path]] = defaultdict(list)
        by_stem: dict[str, list[Path]] = defaultdict(list)
        if self.candidate_root.is_dir():
            for path in sorted(self.candidate_root.rglob("*")):
                if (
                    not path.is_file()
                    or path.is_symlink()
                    or path.suffix.casefold() not in SUPPORTED_EXTENSIONS
                ):
                    continue
                resolved = path.resolve()
                if not _is_within(resolved, self.candidate_root):
                    continue
                by_name[path.name.casefold()].append(resolved)
                by_stem[path.stem.casefold()].append(resolved)
        self._by_name = dict(by_name)
        self._by_stem = dict(by_stem)

    def _indexed_matches(self, row: dict[str, str]) -> list[Path]:
        if self._by_name is None or self._by_stem is None:
            self._build_index()
        assert self._by_name is not None
        assert self._by_stem is not None

        recorded_name = Path(str(row.get("file_path") or "")).name.casefold()
        candidate_id = str(row.get("candidate_id") or "").strip().casefold()
        matches: list[Path] = []
        if recorded_name:
            matches.extend(self._by_name.get(recorded_name, []))
        if candidate_id:
            matches.extend(self._by_stem.get(candidate_id, []))
        return list(dict.fromkeys(matches))

    def resolve_all(self, row: dict[str, str]) -> list[Path]:
        expected_hash = str(row.get("sha256") or "").strip().casefold()
        expected_species = species_folder_name(str(row.get("scientific_name") or ""))
        if not SHA256_PATTERN.fullmatch(expected_hash) or not expected_species:
            return []

        relative_value = str(row.get("file_path") or "").strip()
        matches: list[Path] = []
        if relative_value:
            relative_path = Path(relative_value)
            if not relative_path.is_absolute():
                direct = (self.project_root / relative_path).resolve()
                if direct.is_file() and _is_within(direct, self.candidate_root):
                    matches.append(direct)
        matches.extend(self._indexed_matches(row))
        matches = list(dict.fromkeys(matches))

        species_root = (self.candidate_root / expected_species).resolve()
        matches = [path for path in matches if _is_within(path, species_root)]

        verified: list[Path] = []
        for path in matches:
            try:
                if sha256_for(path).casefold() == expected_hash:
                    verified.append(path)
            except OSError:
                continue
        matches = verified

        return sorted(matches, key=lambda path: path.as_posix().casefold())

    def resolve(self, row: dict[str, str]) -> Path | None:
        matches = self.resolve_all(row)
        if not matches:
            return None

        reviewed_part = normalize_part(str(row.get("reviewed_plant_part") or ""))
        if reviewed_part:
            matching_part = [path for path in matches if part_hint_from_path(path) == reviewed_part]
            if matching_part:
                return matching_part[0]
        return matches[0]


def normalize_part(value: str) -> str:
    normalized = value.strip().casefold().replace("suggested_", "")
    return PART_ALIASES.get(normalized, "")


def part_hint_from_path(path: Path | None) -> str:
    if path is None:
        return ""
    return normalize_part(path.parent.name)


def candidate_part_hint(row: dict[str, str], resolved_paths: Iterable[Path] = ()) -> str:
    reviewed = normalize_part(str(row.get("reviewed_plant_part") or ""))
    if reviewed:
        return reviewed

    hints = {part_hint_from_path(path) for path in resolved_paths}
    hints.discard("")
    if len(hints) == 1:
        return hints.pop()

    recorded = Path(str(row.get("file_path") or ""))
    return part_hint_from_path(recorded)

#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path


def resolve_iso_path(iso_path: str, isos_dir: Path) -> Path:
    candidate = Path(iso_path)
    if candidate.is_absolute():
        return candidate
    return (isos_dir / candidate).resolve()


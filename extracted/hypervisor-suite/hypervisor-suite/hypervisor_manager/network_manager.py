#!/usr/bin/env python3
from __future__ import annotations

import subprocess


def bridge_exists(bridge_name: str) -> bool:
    try:
        subprocess.check_output(["ip", "link", "show", bridge_name])
        return True
    except Exception:
        return False


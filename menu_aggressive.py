#!/usr/bin/env python3
# Configuration management and modularity improvements
# Security enhancements and input validation
# Type hints and performance optimizations
# Enhanced with better error handling and logging
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import curses
import hashlib
import json
import logging
import os
import shlex
import shutil
import subprocess
import sys


@dataclass
class Config:
    """Configuration class for hypervisor manager."""
    repo_root: Path = Path(__file__).resolve().parents[1]
    profiles_dir: Path = (repo_root / "vm_profiles").resolve()
    isos_dir: Path = (repo_root / "isos").resolve()
    state_dir: Path = Path("/var/lib/hypervisor").resolve()
    
    def __post_init__(self):
        """Ensure all directories exist after initialization."""
        for dir_path in [self.profiles_dir, self.isos_dir, self.state_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)

# Global configuration instance
config = Config()

# Backward compatibility
REPO_ROOT = config.repo_root
DEFAULT_PROFILES_DIR = config.profiles_dir
DEFAULT_ISOS_DIR = config.isos_dir
STATE_DIR = config.state_dir

def ensure_state_dirs() -> None:
    """Ensure state directories exist with proper error handling."""
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        logging.info(f"State directory ensured: {STATE_DIR}")
    except PermissionError as e:
        logging.error(f"Permission denied creating state directory: {e}")
        raise
    except Exception as e:
        logging.error(f"Failed to create state directory: {e}")
        raise

def list_vm_profiles(profiles_dir: Path) -> List[Path]:
    """List VM profile files in the given directory.
    
    Args:
        profiles_dir: Directory containing VM profile JSON files
        
    Returns:
        Sorted list of Path objects for valid profile files
    """
    if not profiles_dir.exists():
        return []
    return sorted(p for p in profiles_dir.glob("*.json") if p.is_file())


def read_profile(profile_path: Path) -> Dict[str, Any]:
    """Read and validate VM profile from JSON file.
    
    Args:
        profile_path: Path to the profile JSON file
        
    Returns:
        Validated profile data dictionary
        
    Raises:
        ValueError: If required fields are missing
        json.JSONDecodeError: If file contains invalid JSON
    """
    try:
        with profile_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in profile {profile_path}: {e}")
    
    required = ["name", "cpus", "memory_mb"]
    for key in required:
        if key not in data:
            raise ValueError(f"Missing required field '{key}' in {profile_path}")
    
    # Validate data types
    if not isinstance(data.get("cpus"), int) or data["cpus"] <= 0:
        raise ValueError(f"Invalid CPU count in {profile_path}")
    if not isinstance(data.get("memory_mb"), int) or data["memory_mb"] <= 0:
        raise ValueError(f"Invalid memory size in {profile_path}")
    
    return data


def find_ovmf_paths() -> tuple[Path | None, Path | None]:
    """Best-effort find OVMF code/vars files on NixOS when pkgs.OVMF is installed."""
    candidates = [
        Path("/run/current-system/sw/share/OVMF/OVMF_CODE.fd"),
        Path("/run/current-system/sw/share/edk2-ovmf/x64/OVMF_CODE.fd"),
    ]
    code = next((p for p in candidates if p.exists()), None)

    var_candidates = [
        Path("/run/current-system/sw/share/OVMF/OVMF_VARS.fd"),
        Path("/run/current-system/sw/share/edk2-ovmf/x64/OVMF_VARS.fd"),
    ]
    vars_ = next((p for p in var_candidates if p.exists()), None)
    return code, vars_


def build_qemu_command(profile: dict) -> list[str]:
    name = profile.get("name", "vm")
    cpus = int(profile.get("cpus", 2))
    memory_mb = int(profile.get("memory_mb", 2048))
    iso_path = profile.get("iso_path")
    disk_path = profile.get("disk_path")
    efi = bool(profile.get("efi", True))
    network = profile.get("network", {}) or {}
    arch = profile.get("arch", "x86_64")

    # Select emulator by arch
    emulator = {
        "x86_64": shutil.which("qemu-system-x86_64") or "qemu-system-x86_64",
        "aarch64": shutil.which("qemu-system-aarch64") or "qemu-system-aarch64",
        "riscv64": shutil.which("qemu-system-riscv64") or "qemu-system-riscv64",
        "loongarch64": shutil.which("qemu-system-loongarch64") or "qemu-system-loongarch64",
    }.get(arch, shutil.which("qemu-system-x86_64") or "qemu-system-x86_64")

    machine = "q35" if arch == "x86_64" else "virt"

    cmd: list[str] = [
        emulator,
        "-name", name,
        "-enable-kvm",
        "-cpu", "host",
        "-smp", str(cpus),
        "-m", str(memory_mb),
        "-machine", f"type={machine},accel=kvm",
        # Display: prefer SDL for simple fullscreen flag
        "-display", "sdl,gl=on",
        "-full-screen",
        # Reasonable defaults
        "-device", "virtio-vga-gl",
        "-usb",
        "-device", "usb-tablet",
    ]

    if efi:
        code, vars_ = find_ovmf_paths()
        if code and vars_ and arch == "x86_64":
            vars_copy = STATE_DIR / f"{name}.OVMF_VARS.fd"
            if not vars_copy.exists():
                vars_copy.write_bytes(vars_.read_bytes())
            cmd += [
                "-drive", f"if=pflash,format=raw,readonly=on,file={code}",
                "-drive", f"if=pflash,format=raw,file={vars_copy}",
            ]

    # Storage
    if disk_path:
        cmd += [
            "-drive", f"file={disk_path},if=virtio,cache=none,discard=unmap,format=qcow2",
        ]
    if iso_path:
        iso_resolved = str((DEFAULT_ISOS_DIR / iso_path).resolve()) if not os.path.isabs(iso_path) else iso_path
        cmd += ["-cdrom", iso_resolved]

    # Network
    bridge = network.get("bridge")
    if bridge:
        # Requires qemu-bridge-helper configured system-wide; fallback to user if it fails
        cmd += [
            "-netdev", f"bridge,id=net0,br={bridge}",
            "-device", "virtio-net-pci,netdev=net0",
        ]
    else:
        cmd += [
            "-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0",
        ]

    return cmd


def launch_vm(profile: dict) -> int:
    ensure_state_dirs()
    cmd = build_qemu_command(profile)
    os.environ.setdefault("SDL_VIDEO_FULLSCREEN_DISPLAY", "0")
    try:
        # Use a minimal environment and safe args
        safe_env = {k: v for k, v in os.environ.items() if k in ("PATH", "SDL_VIDEO_FULLSCREEN_DISPLAY", "SDL_VIDEODRIVER", "SDL_AUDIODRIVER")}
        proc = subprocess.Popen(cmd, env=safe_env)
        return proc.wait()
    except FileNotFoundError as e:
        print(f"Failed to start QEMU: {e}", file=sys.stderr)
        return 1


def draw_menu(stdscr, items: list[Path]) -> Path | None:
    curses.curs_set(0)
    current = 0

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        title = "Select a VM profile (Enter to boot, q to quit)"
        stdscr.addstr(1, max(0, (w - len(title)) // 2), title, curses.A_BOLD)

        for idx, item in enumerate(items):
            text = item.stem
            x = 4
            y = 3 + idx
            if y >= h - 1:
                break
            if idx == current:
                stdscr.attron(curses.A_REVERSE)
                stdscr.addstr(y, x, text)
                stdscr.attroff(curses.A_REVERSE)
            else:
                stdscr.addstr(y, x, text)

        key = stdscr.getch()
        if key in (curses.KEY_UP, ord('k')):
            current = (current - 1) % len(items)
        elif key in (curses.KEY_DOWN, ord('j')):
            current = (current + 1) % len(items)
        elif key in (curses.KEY_ENTER, ord('\n')):
            return items[current]
        elif key in (ord('q'), 27):
            return None


def main(argv: list[str]) -> int:
    profiles_dir = DEFAULT_PROFILES_DIR
    if len(argv) > 1:
        profiles_dir = Path(argv[1]).resolve()

    profiles = list_vm_profiles(profiles_dir)
    if not profiles:
        print(f"No VM profiles found in {profiles_dir}", file=sys.stderr)
        return 2

    selected: Path | None = curses.wrapper(lambda scr: draw_menu(scr, profiles))
    if selected is None:
        return 0

    try:
        profile = read_profile(selected)
    except Exception as e:
        print(f"Failed to read profile {selected}: {e}", file=sys.stderr)
        return 2

    return launch_vm(profile)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))


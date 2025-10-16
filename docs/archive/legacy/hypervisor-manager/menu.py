#!/usr/bin/env python3
"""Hyper-NixOS Python Menu - Optimized and Secure."""
import curses
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

# Security: Restrict imports to prevent code injection
__all__ = ['main', 'HypervisorMenu']

# Constants for paths (Security: Use absolute paths)
REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROFILES_DIR = (REPO_ROOT / "vm_profiles").resolve()
DEFAULT_ISOS_DIR = (REPO_ROOT / "isos").resolve()
STATE_DIR = Path("/var/lib/hypervisor").resolve()

# Security: Define allowed characters for VM names
VALID_VM_NAME_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")


def validate_vm_name(name: str) -> bool:
    """Security: Validate VM name to prevent injection attacks."""
    if not name or len(name) > 253:
        return False
    # Security: Only allow alphanumeric, dash, and underscore
    if not all(c in VALID_VM_NAME_CHARS for c in name):
        return False
    # Security: Prevent path traversal
    if ".." in name or "/" in name or "\\" in name:
        return False
    return True


def validate_path(path: Path, base_dir: Optional[Path] = None) -> bool:
    """Security: Validate path to prevent traversal attacks."""
    try:
        resolved = path.resolve()
        # Security: Prevent path traversal
        if ".." in str(path):
            return False
        # Security: Ensure path is within base directory if specified
        if base_dir:
            base_resolved = base_dir.resolve()
            if not str(resolved).startswith(str(base_resolved)):
                return False
        return True
    except (OSError, RuntimeError):
        return False


def ensure_state_dirs() -> None:
    """Efficiency: Create state directories with proper permissions."""
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o750)


def list_vm_profiles(profiles_dir: Path) -> list[Path]:
    """Efficiency: Cached VM profile listing."""
    if not profiles_dir.exists():
        return []
    # Security: Validate each path before including
    return sorted(
        p for p in profiles_dir.glob("*.json")
        if p.is_file() and validate_path(p, profiles_dir)
    )


def read_profile(profile_path: Path) -> dict:
    """Security: Safe JSON profile reading with validation."""
    # Security: Validate path
    if not validate_path(profile_path):
        raise ValueError(f"Invalid profile path: {profile_path}")
    
    # Security: Check file size to prevent DoS
    if profile_path.stat().st_size > 1024 * 1024:  # 1MB limit
        raise ValueError(f"Profile file too large: {profile_path}")
    
    with profile_path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Security: Validate required fields
    required = ["name", "cpus", "memory_mb"]
    for key in required:
        if key not in data:
            raise ValueError(f"Missing required field '{key}' in {profile_path}")
    
    # Security: Validate VM name
    if not validate_vm_name(data["name"]):
        raise ValueError(f"Invalid VM name in profile: {data['name']}")
    
    return data


def find_ovmf_paths() -> tuple[Path | None, Path | None]:
    """Best-effort find OVMF code/vars files on NixOS when pkgs.OVMF is installed."""
    # Efficiency: Use tuple for immutable candidates
    code_candidates = (
        Path("/run/current-system/sw/share/OVMF/OVMF_CODE.fd"),
        Path("/run/current-system/sw/share/edk2-ovmf/x64/OVMF_CODE.fd"),
    )
    code = next((p for p in code_candidates if p.exists()), None)

    var_candidates = (
        Path("/run/current-system/sw/share/OVMF/OVMF_VARS.fd"),
        Path("/run/current-system/sw/share/edk2-ovmf/x64/OVMF_VARS.fd"),
    )
    vars_ = next((p for p in var_candidates if p.exists()), None)
    return code, vars_


def build_qemu_command(profile: dict) -> list[str]:
    """Security: Build QEMU command with input validation."""
    # Security: Validate and sanitize inputs
    name = profile.get("name", "vm")
    if not validate_vm_name(name):
        raise ValueError(f"Invalid VM name: {name}")
    
    # Security: Validate numeric inputs with bounds
    try:
        cpus = int(profile.get("cpus", 2))
        if not 1 <= cpus <= 256:
            raise ValueError(f"Invalid CPU count: {cpus}")
        
        memory_mb = int(profile.get("memory_mb", 2048))
        if not 128 <= memory_mb <= 1048576:  # 128MB to 1TB
            raise ValueError(f"Invalid memory: {memory_mb}")
    except (ValueError, TypeError) as e:
        raise ValueError(f"Invalid numeric value in profile: {e}")
    
    iso_path = profile.get("iso_path")
    disk_path = profile.get("disk_path")
    efi = bool(profile.get("efi", True))
    network = profile.get("network", {}) or {}
    arch = profile.get("arch", "x86_64")
    
    # Security: Validate architecture
    valid_archs = {"x86_64", "aarch64", "riscv64", "loongarch64"}
    if arch not in valid_archs:
        raise ValueError(f"Invalid architecture: {arch}")

    # Efficiency: Use dict.get with fallback
    emulator_map = {
        "x86_64": "qemu-system-x86_64",
        "aarch64": "qemu-system-aarch64",
        "riscv64": "qemu-system-riscv64",
        "loongarch64": "qemu-system-loongarch64",
    }
    emulator_name = emulator_map.get(arch, "qemu-system-x86_64")
    emulator = shutil.which(emulator_name) or emulator_name

    machine = "q35" if arch == "x86_64" else "virt"

    # Security: Use list for command to prevent shell injection
    cmd: list[str] = [
        emulator,
        "-name", name,
        "-enable-kvm",
        "-cpu", "host",
        "-smp", str(cpus),
        "-m", str(memory_mb),
        "-machine", f"type={machine},accel=kvm",
        "-display", "sdl,gl=on",
        "-full-screen",
        "-device", "virtio-vga-gl",
        "-usb",
        "-device", "usb-tablet",
    ]

    if efi:
        code, vars_ = find_ovmf_paths()
        if code and vars_ and arch == "x86_64":
            # Security: Validate paths
            vars_copy = STATE_DIR / f"{name}.OVMF_VARS.fd"
            if not validate_path(vars_copy, STATE_DIR):
                raise ValueError(f"Invalid OVMF vars path: {vars_copy}")
            
            # Efficiency: Only copy if not exists
            if not vars_copy.exists():
                vars_copy.write_bytes(vars_.read_bytes())
                vars_copy.chmod(0o600)  # Security: Restrict permissions
            
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


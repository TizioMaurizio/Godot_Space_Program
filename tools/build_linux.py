#!/usr/bin/env python3
"""Build Linux release packages using only Python stdlib and Godot's CLI.

Example on Windows:
  python tools/build_linux.py --godot C:/path/to/Godot_v4.6.1-stable_win64.exe
Works on Linux with the matching Godot editor as well. Imports happen in an
isolated copy so an open editor's UID cache is not modified by the build.
"""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import zipfile

VERSION = "4.6.1"
TEMPLATE_SHA256 = "e6d372afd4fdfaae9571eb5e3568afcd96ce6db9a569244034154faf0ac69875"
TEMPLATE_NAME = f"Godot_v{VERSION}-stable_export_templates.tpz"
TEMPLATE_URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/{TEMPLATE_NAME}"
ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".godot" / "build-cache"
LOGS = ROOT / ".godot" / "build-logs"
OUTPUT = ROOT / "build" / "linux-x86_64"
PACKAGE = OUTPUT / "GodotSpaceProgram"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def download(url, destination):
    print(f"Downloading {destination.name} ...", flush=True)
    request = urllib.request.Request(url, headers={"User-Agent": "GodotSpaceProgram-build"})
    partial = destination.with_suffix(destination.suffix + ".part")
    with urllib.request.urlopen(request, timeout=120) as response, partial.open("wb") as target:
        shutil.copyfileobj(response, target, length=1024 * 1024)
    partial.replace(destination)


def install_templates(archive):
    if os.name == "nt":
        data_root = Path(os.environ["APPDATA"]) / "Godot"
    else:
        data_root = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))) / "godot"
    target = data_root / "export_templates" / f"{VERSION}.stable"
    required = ["linux_release.x86_64", "linux_debug.x86_64", "version.txt"]
    if archive is None and all((target / name).is_file() for name in required):
        print(f"Using installed export templates: {target}", flush=True)
        return
    archive = archive or CACHE / TEMPLATE_NAME
    if not archive.exists():
        download(TEMPLATE_URL, archive)
    print("Verifying the official template archive SHA-256 ...", flush=True)
    if digest(archive) != TEMPLATE_SHA256:
        raise RuntimeError(f"Template archive checksum mismatch: {archive}")
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for name in required:
            member = f"templates/{name}"
            with bundle.open(member) as source, (target / name).open("wb") as output:
                shutil.copyfileobj(source, output)
            if name != "version.txt":
                (target / name).chmod(0o755)
    print(f"Installed Linux x86-64 templates: {target}", flush=True)


def run_godot(executable, arguments, cwd, name):
    completed = subprocess.run(
        [str(executable), *arguments], cwd=cwd,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace",
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )
    (LOGS / f"{name}.log").write_text(completed.stdout, encoding="utf-8")
    if completed.returncode or re.search(r"(?m)^(?:SCRIPT )?ERROR:", completed.stdout):
        print(completed.stdout)
        raise RuntimeError(f"Godot {name} failed; see {LOGS / (name + '.log')}")
    print(f"Godot {name}: OK", flush=True)
    return completed.stdout


def package_release():
    shutil.copy2(ROOT / "tools" / "linux_README.txt", PACKAGE / "README.txt")
    launcher = (ROOT / "tools" / "launch_linux.sh").read_text(encoding="utf-8")
    (PACKAGE / "launch.sh").write_text(launcher, encoding="utf-8", newline="\n")
    for name in ["LICENSE.txt", "COPYRIGHT.txt"]:
        cached = CACHE / f"GODOT_{name}"
        if not cached.exists():
            download(f"https://raw.githubusercontent.com/godotengine/godot/{VERSION}-stable/{name}", cached)
        shutil.copy2(cached, PACKAGE / f"GODOT_{name}")
    executable = PACKAGE / "GodotSpaceProgram.x86_64"
    with executable.open("rb") as stream:
        header = stream.read(20)
    if header[:4] != b"\x7fELF" or header[4] != 2 or header[18:20] != b"\x3e\x00":
        raise RuntimeError("Export is not an ELF64 x86-64 executable")
    if not (PACKAGE / "GodotSpaceProgram.pck").is_file():
        raise RuntimeError("Missing exported PCK")
    modes = {"GodotSpaceProgram.x86_64": 0o755, "launch.sh": 0o755}
    files = sorted(PACKAGE.iterdir())
    zip_path = OUTPUT / "GodotSpaceProgram-linux-x86_64.zip"
    tar_path = OUTPUT / "GodotSpaceProgram-linux-x86_64.tar.gz"
    now = int(time.time())
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            mode = modes.get(path.name, 0o644)
            info = zipfile.ZipInfo(f"GodotSpaceProgram/{path.name}", time.localtime(now)[:6])
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with path.open("rb") as source, archive.open(info, "w") as destination:
                shutil.copyfileobj(source, destination)
    with tarfile.open(tar_path, "w:gz", compresslevel=6) as archive:
        for path in files:
            info = tarfile.TarInfo(f"GodotSpaceProgram/{path.name}")
            info.size = path.stat().st_size
            info.mode = modes.get(path.name, 0o644)
            info.mtime = now
            with path.open("rb") as source:
                archive.addfile(info, source)
    checksums = "".join(f"{digest(path)}  {path.name}\n" for path in [zip_path, tar_path])
    (OUTPUT / "SHA256SUMS.txt").write_text(checksums, encoding="utf-8", newline="\n")
    for path in [zip_path, tar_path]:
        print(f"Created {path} ({path.stat().st_size / 1048576:.1f} MiB)", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot"), help="Godot 4.6.1 editor executable")
    parser.add_argument("--templates-archive", type=Path, help="Optional official 4.6.1 template TPZ")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Provide --godot /path/to/the/Godot/editor")
    executable = Path(args.godot).resolve()
    CACHE.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    PACKAGE.mkdir(parents=True, exist_ok=True)
    version = run_godot(executable, ["--version"], ROOT, "version").strip()
    if not version.startswith(f"{VERSION}.stable"):
        raise RuntimeError(f"This build requires Godot {VERSION} stable; got {version!r}")
    install_templates(args.templates_archive)
    # Keep the isolated workspace under the ignored project cache for inspection.
    workspace = Path(tempfile.mkdtemp(prefix="linux-export-", dir=ROOT / ".godot"))
    for directory in ["data", "definitions", "game", "shaders", "simulation", "ui"]:
        shutil.copytree(ROOT / directory, workspace / directory)
    for name in ["project.godot", "export_presets.cfg", "icon.svg"]:
        shutil.copy2(ROOT / name, workspace / name)
    run_godot(executable, ["--headless", "--editor", "--path", ".", "--import", "--quit"], workspace, "import")
    run_godot(executable, ["--headless", "--path", ".", "--export-release", "Linux x86_64", str(PACKAGE / "GodotSpaceProgram.x86_64")], workspace, "export-linux")
    package_release()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, zipfile.BadZipFile) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)

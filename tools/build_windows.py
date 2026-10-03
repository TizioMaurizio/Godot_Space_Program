#!/usr/bin/env python3
"""Export a self-contained Windows x86-64 EXE and ZIP through Godot's CLI."""

import argparse
import os
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import zipfile

from build_linux import (
    CACHE, LOGS, ROOT, VERSION, TEMPLATE_NAME, TEMPLATE_SHA256, TEMPLATE_URL,
    digest, download, run_godot,
)

OUTPUT = ROOT / "build" / "windows-x86_64"
PACKAGE = OUTPUT / "GodotSpaceProgram"


def install_windows_templates(archive):
    data_root = (Path(os.environ["APPDATA"]) / "Godot" if os.name == "nt" else
                 Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot")
    target = data_root / "export_templates" / f"{VERSION}.stable"
    required = ["windows_release_x86_64.exe", "windows_debug_x86_64.exe", "version.txt"]
    if archive is None and all((target / name).is_file() for name in required):
        print(f"Using installed Windows templates: {target}", flush=True)
        return
    archive = archive or CACHE / TEMPLATE_NAME
    if not archive.exists():
        download(TEMPLATE_URL, archive)
    print("Verifying official template archive SHA-256 ...", flush=True)
    if digest(archive) != TEMPLATE_SHA256:
        raise RuntimeError(f"Template archive checksum mismatch: {archive}")
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for name in required:
            with bundle.open(f"templates/{name}") as source, (target / name).open("wb") as out:
                shutil.copyfileobj(source, out)
    print("Windows x86-64 templates installed.", flush=True)


def package_release():
    executable = PACKAGE / "GodotSpaceProgram.exe"
    with executable.open("rb") as stream:
        header = stream.read(64)
        if header[:2] != b"MZ":
            raise RuntimeError("Export is not a Windows executable")
        stream.seek(struct.unpack_from("<I", header, 0x3C)[0])
        pe = stream.read(26)
        if pe[:4] != b"PE\0\0" or struct.unpack_from("<H", pe, 4)[0] != 0x8664:
            raise RuntimeError("Export is not an x86-64 PE executable")
        stream.seek(-4, 2)
        if stream.read(4) != b"GDPC":
            raise RuntimeError("Missing embedded Godot resource pack")
    files = [executable]
    for name in ["LICENSE.txt", "COPYRIGHT.txt"]:
        cached = CACHE / f"GODOT_{name}"
        if not cached.exists():
            download(f"https://raw.githubusercontent.com/godotengine/godot/{VERSION}-stable/{name}", cached)
        destination = PACKAGE / f"GODOT_{name}"
        shutil.copy2(cached, destination)
        files.append(destination)
    readme = PACKAGE / "README.txt"
    shutil.copy2(ROOT / "tools/windows_README.txt", readme)
    files.append(readme)
    launcher = PACKAGE / "Launch Vulkan.cmd"
    launcher.write_text((ROOT / "tools/launch_windows_vulkan.cmd").read_text(encoding="utf-8"),
                        encoding="utf-8", newline="\r\n")
    files.append(launcher)
    archive_path = OUTPUT / "GodotSpaceProgram-windows-x86_64.zip"
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            archive.write(path, f"GodotSpaceProgram/{path.name}")
    (OUTPUT / "SHA256SUMS.txt").write_text(
        f"{digest(executable)}  GodotSpaceProgram/GodotSpaceProgram.exe\n"
        f"{digest(archive_path)}  {archive_path.name}\n", encoding="utf-8")
    print(f"Created {executable} ({executable.stat().st_size / 1048576:.1f} MiB)", flush=True)
    print(f"Created {archive_path} ({archive_path.stat().st_size / 1048576:.1f} MiB)", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot"), help="Godot 4.6.1 editor executable")
    parser.add_argument("--templates-archive", type=Path, help="Optional official template TPZ")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Provide --godot /path/to/Godot")
    executable = Path(args.godot).resolve()
    for directory in [CACHE, LOGS, PACKAGE]:
        directory.mkdir(parents=True, exist_ok=True)
    version = run_godot(executable, ["--version"], ROOT, "windows-version").strip()
    if not version.startswith(f"{VERSION}.stable"):
        raise RuntimeError(f"Expected Godot {VERSION} stable; got {version!r}")
    install_windows_templates(args.templates_archive)
    workspace = Path(tempfile.mkdtemp(prefix="windows-export-", dir=ROOT / ".godot"))
    for directory in ["data", "definitions", "game", "shaders", "simulation", "ui"]:
        shutil.copytree(ROOT / directory, workspace / directory)
    for name in ["project.godot", "export_presets.cfg", "icon.svg"]:
        shutil.copy2(ROOT / name, workspace / name)
    run_godot(executable, ["--headless", "--editor", "--path", ".", "--import", "--quit"], workspace, "windows-import")
    run_godot(executable, ["--headless", "--path", ".", "--export-release", "Windows x86_64",
                          str(PACKAGE / "GodotSpaceProgram.exe")], workspace, "export-windows")
    package_release()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, zipfile.BadZipFile) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)

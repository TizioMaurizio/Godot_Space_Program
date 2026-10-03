# Linux x86-64 build

The project can be exported from Windows or Linux using the Godot command line. No desktop automation or editor interaction is required.

## Build

Requirements: Python 3.11 or newer and the **Godot 4.6.1 stable editor**. From the project root:

```powershell
python tools/build_linux.py --godot 'C:\path\to\Godot_v4.6.1-stable_win64.exe'
```

On Linux:

```sh
python3 tools/build_linux.py --godot /path/to/godot
```

The script downloads the official matching export-template archive if Linux templates are absent, verifies its SHA-256 against the published release digest, and installs only the Linux x86-64 templates. The full official archive is approximately 1.25 GB; it is cached under `.godot/build-cache/` for reuse. An already downloaded copy can be supplied with `--templates-archive /path/to/Godot_v4.6.1-stable_export_templates.tpz`.

The build imports an isolated project copy under `.godot/` and invokes the `Linux x86_64` release preset. This keeps the running editor's resource cache untouched. Build output is ignored by Git.

Outputs under `build/linux-x86_64/`:

- `GodotSpaceProgram-linux-x86_64.tar.gz`
- `GodotSpaceProgram-linux-x86_64.zip`
- `SHA256SUMS.txt`
- Unpacked `GodotSpaceProgram/` containing the executable, PCK, launcher, instructions and Godot license notices.

Both archives store Unix executable permissions for the executable and launcher. The build validates the output's ELF64/x86-64 header and requires the companion PCK. Godot logs are retained under `.godot/build-logs/`.

With matching templates already installed, the underlying Godot command is:

```sh
godot --headless --path . --export-release "Linux x86_64" /absolute/output/GodotSpaceProgram.x86_64
```

Create the output directory first. The Python wrapper additionally handles isolated import, template setup, packaging and checksums. Godot's export and platform behavior are documented in its [command-line guide](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html) and [Linux export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_linux.html).

## Play on Linux

```sh
tar -xzf GodotSpaceProgram-linux-x86_64.tar.gz
cd GodotSpaceProgram
./launch.sh
```

If your archive tool did not preserve permissions:

```sh
chmod +x launch.sh GodotSpaceProgram.x86_64
./launch.sh
```

Keep the executable and `.pck` together. The exported game does not require the Godot editor. It targets **64-bit Intel/AMD Linux**, with a graphical session and an OpenGL 3.3-compatible driver; it is not an ARM build.

For a command-line startup check without opening a graphical window:

```sh
./launch.sh --headless --quit-after 120
```

## Recorded validation

The completed Phases 1–6 upgrade was rebuilt on 2026-10-01. The final ZIP/tar.gz are approximately 26.2 MiB; the PCK is 277,396 bytes and includes the part catalog/craft JSON. The actual final tarball passed menu, launchpad and orbit headless startup under Ubuntu/WSL with success exits and no Godot errors or leaked-object warnings. The initial upgrade smoke exposed an unused AudioStreamGeneratorPlayback on the Dummy backend; FlightAudio now avoids that allocation. Graphical Linux gameplay remains untested.

Final archive SHA-256:

```text
50b985ead3e9e91228142b0ec9ab613b6ab8af0d226a2010b70d584079523ce1  GodotSpaceProgram-linux-x86_64.zip
e49ef771697df009d31853104378207cd25e2ca2098e11a21c3688c4ea5acb27  GodotSpaceProgram-linux-x86_64.tar.gz
```

The following entries describe earlier builds.

The generated tarball was extracted and its launcher executed under **Ubuntu 24.04.4 LTS, x86-64, via WSL**. The exported binary was identified as an ELF64 x86-64 release executable. Menu startup, launchpad startup (`--flight-smoke`) and orbital startup (`--orbit-smoke`) all exited successfully with no Godot runtime errors. The launcher ran directly with the executable permissions stored in the archive.

This was headless runtime verification; a graphical Linux desktop playthrough was not performed. WSL emitted an unrelated systemd user-session startup warning before running the three successful checks.

On 2026-10-01, the package was rebuilt under the Godot Space Program name. The renamed tarball and launcher passed headless menu and orbit startup checks under Ubuntu/WSL. Previously generated Aster Flight Lab packages were retained separately; the filenames above refer to the renamed build.

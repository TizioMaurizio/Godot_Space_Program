# Codex handoff — 2026-10-03

## Current objective

Move the project and Codex history to another Windows PC, then resume the unfinished **Aster Orbital Research Station (AORS)** implementation. The latest development instruction is to reuse existing parts, add only a small reusable catalog with **S/M/X/XL** container sizes, shorten the supplied brief where useful, and release a playable spacecraft after essential checks. The user accepts remaining physics problems and explicitly prefers limited testing before that release. [Full station brief](AORS_BRIEF.md); this later instruction takes precedence over its exhaustive testing requests.

## Completed work and implementation state

- The earlier Aster Flight Lab was renamed **Godot Space Program**. Phases 1–6 added modular parts, resources, mass/COM/full inertia, structural failures and debris, assembly editor, terrain/water, planet visuals, Neris and patched-conic lunar missions. See [UPGRADE_REPORT.md](UPGRADE_REPORT.md) and [VALIDATION.md](VALIDATION.md). The initial repository commit is `9aa5514`; these upgrades remain **uncommitted** in the source snapshot.
- Existing documentation reports 20 passing assertion suites/variants. October 1 logs present on this PC have empty error files; these are historical results, **not validation of the partial station changes**. Windows and Linux CLI build scripts and release packages exist; the migration omits reproducible build binaries/caches. Windows Vulkan startup/exit passed on Intel Iris Xe; OpenGL export shutdown had driver crashes.
- AORS is **started, not delivered**. `tools/generate_station.py` produced `data/parts/standard_parts.json`, `data/craft/aors_complete.json`, `docking_tug.json`, `module_launcher.json`, and two initialized orbital scenarios in `data/scenarios/`. It uses reusable containers, nodes, trusses, eight solar wings, radiators, five docking ports and RCS blocks. Recipes are fixtures, not proof of successful launch/docking.
- `simulation/electric_power.gd` and `simulation/rcs_system.gd` contain preliminary implementations. `rocket_state.gd` has RCS/docking fields and RCS force integration; associated part/module/catalog work is partial. Inspect actual code before assuming these systems are connected to the game. Dedicated docking/flight-save systems and station scenario/menu/render/UI integration are still to be implemented or checked. No completed AORS validation/release is recorded.
- The migration commit contains only the handoff, station brief and restore helper. **A clone alone does not contain the upgraded game or partial AORS implementation.** Restore the archive's `workspace/` into a clean checkout of the handoff commit. This deliberately preserves the original uncommitted state for review.

## Architectural decisions

- `CraftDesign -> PartGraph -> RocketState : FlightBody`: one authoritative rigid integrated body per connected tree. No static/decorative station or parallel station physics. Render nodes never own flight state; graph loops/flexible structures remain unsupported.
- Scalar-double absolute translation in the Aster inertial frame, quaternion attitude, full aggregate inertia; preserve part world poses and velocity fields during COM/resource changes. Splitting, docking and undocking must conserve mass and linear/angular momentum.
- Parts own module/resource state. `FlightSession`/`SpacecraftRegistry` own vessels and a shared clock; `FlightSnapshot` supplies views. Use the same physics for normal flight, coast warp and predictions, with SOI crossing protection. `SurfaceQuery` supplies rendering/contact/water geometry.
- Craft JSON saves are **design-only**, not flight saves. Add a separate versioned flight-state schema for persistent station/vessel state. Power, RCS, docking and persistence should be generic spacecraft systems.
- AORS uses original procedural assets. Its initial scenario is explicitly **prebuilt/initialized for playtesting**, in a 120 km Aster orbit, 51.6° inclination, RAAN 25°. A nearby tug starts 650 m away. The long brief's individual bespoke parts can be replaced by the standardized reusable catalog.

## Unresolved issues and next actions

1. Restore the workspace/history, read the brief and latest transcript, inspect Git status and import the project with Godot 4.6.1. Never reset away the restored implementation.
2. Inspect station catalog/recipes and complete one playable initialized AORS scenario with the actual modular physics and procedural visuals. Check recipe validity and usable camera framing.
3. Wire finite-propellant RCS, electrical generation/eclipse/batteries/control availability, targeting/relative navigation, real docking/undocking, vessel switching, persistence, map selection and proximity warp guards. Follow brief capture limits and conservation rules; avoid teleport/visual parenting shortcuts.
4. Run essential import/playability and targeted docking/conservation/save-load checks; release a Windows build without an exhaustive new validation campaign. Report remaining defects honestly. Update implementation/validation docs and commit source when a reviewable milestone is ready.
5. Existing limits: large atmospheric craft exceed the intended CPU budget; terrain recentring can stall; electrical/thermal/flight persistence claims in older reports predate partial station work. Old architecture-plan stop gates were superseded by the user's later authorization to implement Phases 1–6 continuously. Linux graphics remain untested.

## Relevant files and commands

Read `README.md`, `docs/UPGRADE_REPORT.md`, `docs/VALIDATION.md`, `docs/AORS_BRIEF.md`; inspect `tools/generate_station.py`, `data/parts/{catalog,standard_parts}.json`, `data/craft/`, `data/scenarios/`, `definitions/part_definition.gd`, `simulation/parts/`, `simulation/{rocket_state,flight_session,spacecraft_registry,electric_power,rcs_system}.gd`, `game/{main,rocket_visual}.gd`, `ui/{assembly_editor,flight_hud,orbit_map}.gd`.

```powershell
# Supply the new PC's actual Godot 4.6.1 executable path.
& 'C:\path\Godot_v4.6.1-stable_win64.exe' --headless --editor --path . --import --quit
.\tests\run_tests.ps1 -Godot 'C:\path\Godot_v4.6.1-stable_win64.exe' -Only validate_parts,validate_modules,validate_celestial
python tools/build_windows.py --godot 'C:\path\Godot_v4.6.1-stable_win64.exe'
python tools/build_linux.py --godot 'C:\path\Godot_v4.6.1-stable_win64.exe'
# Optional broader verification when justified:
.\tests\run_tests.ps1 -Godot 'C:\path\Godot_v4.6.1-stable_win64.exe' -WithRendering
```

`tools/check_development.ps1` has the old PC's Godot path hard-coded; prefer the parameterized test runner or adjust the helper before use. Preserve `.uid` files; restart an editor with stale resource registrations rather than deleting its active cache. `python tools/generate_station.py` overwrites generated catalog/recipes, so inspect edits before rerunning it.

## Conversation and machine continuity

- Old repository: `C:\Users\m.vetere\Documents\Godot_Space_Program` (also stored with lowercase drive, forward slashes and `\\?\` prefix). Historical transcript commands reference it; fresh commands must use the new checkout.
- Old Codex home: `C:\Users\m.vetere\.codex`; VS Code bundled CLI `0.159.0-alpha.12.1`, extension `openai.chatgpt-26.930.21537-win32-x64`, Python 3.12, PowerShell, Git and GitHub CLI. Old Godot: `C:\Users\m.vetere\Desktop\Godot_v4.6.1-stable_win64.exe`.
- Development thread: `01a0ed07-848f-7aa2-8f63-17ad624ae8b6` (started September 29; native paginated history). Migration thread: `01a1028b-67de-7e91-a3ab-33639c1abcb1` (October 3). Both are packaged, with referenced pasted attachments and readable transcripts.
- History resides in `sessions/YYYY/MM/DD/rollout-*.jsonl`, `state_5.sqlite`, `thread_history_1.sqlite`, and `session_index.jsonl`; selected project goal/memory records are supplementary. `history.jsonl` is absent. The package contains freshly rebuilt project-scoped databases, not entire user databases.
- Original session files were only read. Authentication, configuration, browser state, logs containing unrelated sessions, OS keychains, caches and plugins are excluded. Credentials found inside exported history are redacted; opaque encrypted reasoning is omitted. Sign in and configure Git/Codex/plugins separately on the new PC.
- See [CODEX_MIGRATION.md](CODEX_MIGRATION.md) for verification/import. Exact restoration across alpha versions/frontends is best effort; the handoff, full station brief, source snapshot and readable transcripts are the fallback. An active turn's later messages/final answer cannot be included in a snapshot created during that turn.

# Godot Space Program

Moving to another PC or continuing with a new coding agent? Read [HANDOFF.txt](HANDOFF.txt) for current source-transfer status, setup, architecture, standard parts and a reusable spacecraft prompt. Ordinary iteration uses **F5 in Godot**; export builds are made only when explicitly requested.

An original, playable Godot 4.x spacecraft construction and orbital-flight simulation. Build a real part graph, launch through Aster's rotating atmosphere, stage, reach orbit, encounter the moon Neris, land or return. Forces, mass, torque, joint loads and water displacement determine what happens; entering an orbit never changes the physics.

Tested with **Godot 4.6.1**, Compatibility/OpenGL renderer. Open `project.godot` and press **F5**. No external art, plugins or double-precision engine build is required. Choose Orbital Test Vehicle, Basic Suborbital Rocket, Neris Explorer, or **Vehicle Assembly**. The [upgrade report](docs/UPGRADE_REPORT.md), [validation record](docs/VALIDATION.md), [journal](docs/DEVELOPMENT_JOURNAL.md) and [approved architecture](docs/IMPLEMENTATION_PLAN.md) describe implementation and evidence.

## AORS station playtest

On the main menu choose **AORS IN ORBIT / PREBUILT**, or **AORS + DOCKING TUG / PREBUILT**. The station is explicitly initialized at 120 km altitude and 51.6° inclination. Its 44 physical parts total 193.85 t, with eight solar wings, six radiators and five S docking ports. [Station capture](docs/validation/30_aors_station.png).

Use **F6** to switch vessels, **F7** for vessel/target/port selection, **V** to toggle RCS, and **I/K, J/L, U/O** to translate along the craft's axes. **C** cycles craft/both-vessel/target-port camera focus. Approach slowly, align opposite port axes, and release thrust/SAS for the capture springs. Docking is automatic when armed and within the stated limits: 0.12 m plane gap, 0.10 m lateral offset, 0.25 m/s relative speed and 7.5° alignment. **N** toggles docking arm/safe; **G** undocks the first docking connection. Map markers can be clicked to target or double-clicked to switch.

**F5/F9** or the on-screen buttons save/load the whole flight, including docked graphs, resources and damage. **ADD LAUNCH** opens the builder; launching from a station session adds another craft at Aster's launchpad while retaining the station. The **X Module Launcher** prebuilt uses existing Forge stages and a reusable X container for further construction. Its complete ascent/campaign has not been flight-qualified for this playtest.

Container families are **S/M/X/XL**: 1.2/2/3/4 m diameters and 2/4/6/8 m lengths. Ten new reusable definitions support the station; laboratories, habitation, logistics and service reuse the same containers. The truss uses repeated 12 m segments. Solar generation, eclipse, joule batteries and priority load shedding are functional on configured vessels. Radiators and airlocks have physical mass/collision but thermal/EVA gameplay is deferred. This is an early playable release with limited checks, rather than a completed historical ISS replica or a fully tested assembly campaign.

## Controls

| Control | Action |
| --- | --- |
| W/S, A/D, Q/E | Pitch, yaw, roll |
| Shift/Ctrl; Z/X | Adjust throttle; full/cut |
| Space | Execute the next configured stage's actions |
| T/H; P/R | SAS off/hold; prograde/retrograde |
| 1/2; 3/4 | Radial out/in; normal/antinormal |
| Right-drag / wheel | Camera orbit / zoom |
| Comma / period | Decrease / increase time warp |
| M | Flight / orbit map |
| F / Tab / B in map | Fit orbit / focus craft or body / system scale |
| Click a part / I | Inspect part / close inspector |
| F4 | Structural stress overlay |
| F1 / F3; Esc | Handbook / physics values; pause |

Q/E and horizontal camera drag retain the requested inverted directions. Manual attitude input overrides SAS temporarily. SAS OFF removes control torque while aerodynamic and thrust torques remain active. PROGRADE is air-relative below the atmosphere and relative to the current central body in vacuum.

## Vehicle assembly

Start with **New**, choose a command capsule or probe, then add catalog parts by dragging onto the craft or using an attachment button. Stack sizes must match; use the adapter where needed. Radial ports support **1, 2, 3, 4, 6 or 8** copies. Highlighted attachment previews and geometric checks reject occupied ports and overlapping parts.

Select a part to change tank fill, engine thrust limit/gimbal, crossfeed, wheel availability or gear deployment. Move/copy operates on an attached branch; group editing applies to symmetry partners. R rotates, Delete removes, F fits, Ctrl+Z/Y undo/redo. Drag stage actions between stage cards; reorder stages with arrows. Disable automatic staging when arranging a custom sequence.

COM, initial-stage thrust and estimated pressure-centre markers accompany mass, thrust, TWR, delta-v, burn-time and alignment information. **Save** writes a versioned craft to `user://craft`; **Load** includes saved and prebuilt vehicles. **Launch** instantiates that exact design. Craft saves contain construction recipes, not running flight saves.

## First orbit

1. Select **Orbital Test Vehicle**. Press **Z**, then **Space**.
2. Climb vertically to 1 km. Pitch east with W: roughly 65° at 5 km, 35° at 20 km, then 5–10° at 40–45 km. Release controls between corrections so HOLD stops the turn.
3. Cut with X when predicted apoapsis reaches about 120 km. Stage with Space; P follows prograde during the coast. If the booster empties first, stage and continue the ascent.
4. About 50 seconds before apoapsis, burn prograde with Z. Cut when periapsis exceeds 60 km. The craft continues orbiting under gravity.

The current production regression reaches approximately **158 × 65 km in 309 seconds**, with about **75% upper-stage propellant** remaining. A separate rendered acceptance test constructs the rocket from scratch in the editor, saves/reloads it, launches and reaches orbit.

## Map, warp and Neris

The live 3D map shows the current body's orbit, apsides, atmospheric segments and radius-based impact estimate. B zooms out to the Aster–Neris system. Neris' orbital track and SOI ring are shown; long trajectories add timed patched-conic encounter segments and predicted lunar periapsis. Predictions omit future thrust, drag and perturbations, and are bounded in time/sample count. Ordinary conic impact markers use the reference radius; terrain is authoritative during actual flight.

Warp rates are **1, 2, 3, 4, 10, 50, 100 and 1,000×**. In atmosphere or under thrust, 1–4× repeats the unchanged 1/120 s force steps. Vacuum coast reuses the double-precision Kepler solver. Attitude is held in coast warp. Inputs cancel high warp; conservative guards stop it before atmosphere, terrain, nearby component contact or an SOI crossing could be skipped. After a boundary, increase warp again manually. Powered/atmospheric debris continues force integration.

**Neris** has a 100 km radius, 0.8 m/s² surface gravity, no atmosphere, a 3,000 km orbit radius and a roughly 262 km SOI radius. Its ephemeris, body-relative gravity, warp and prediction use one shared clock. Capture requires an engine burn: merely entering the SOI cannot capture or circularize a craft.

For a lunar mission, establish an Aster parking orbit, burn prograde to extend apoapsis toward Neris' orbit, and use encounter/periapsis markers to refine the approach. Correct a terrain-intersecting approach before arrival, then burn retrograde near lunar periapsis for capture. Depart approximately opposite Neris' orbital motion to lower the Aster return periapsis. The test pilot demonstrates the complete launch → lunar capture → full lunar orbit → escape → atmospheric return sequence with real burns. It is test guidance, not an in-game autopilot or maneuver-node system.

Neris Explorer adds a parachute and four landing legs. Its third stage deploys the legs; its fourth cuts the upper engine and deploys the chute. Use controlled, slow powered lunar descent; parachutes do nothing in lunar vacuum. The included landing test is a separate initialized descent, not a claim that the complete return mission also landed.

## Terrain, water and failure

A shared procedural spherical terrain field supplies both rendered LOD tiles and physical contact heights/normals. Aster has mountains, plains, coasts and a raised launch site; Neris has cratered terrain. Oceans are physical water with waves, per-part displaced-volume buoyancy, water drag and angular damping. Intact capsules float partly submerged; dense or flooded wrecks can sink. Fast water impacts can destroy parts. Contact drives splash rings, spray, foam, wakes and underwater fog.

Every part contributes aerodynamic forces and a pressure-centre moment. Approximate shielding reduces downstream exposure. Joint axial/shear/bending/torsion loads can break the graph deterministically; each disconnected component retains its own resources, velocity, rotation and active modules. Nearby wrecks remain physical. Click a part or enable F4 to inspect the cause. Collision proxies are rigid primitives; connected assemblies do not visibly flex.

Cloud layers, ocean waves, atmosphere glow, local sunrise/sunset and land-only night lights are procedural and share one Sun direction. Reentry plasma and airflow FX use actual density and relative speed. Heating is an explicitly qualitative visual proxy; there is no thermal destruction or heat-shield model.

## Source and validation

| Directory | Responsibility |
| --- | --- |
| `definitions/`, `data/` | Part/body resources, catalog JSON and craft recipes |
| `simulation/` | Double translation, mass/inertia, graph/modules, forces, loads, contacts, water, orbits and celestial clock |
| `game/` | Flight orchestration, camera, original meshes/shaders/audio and effects |
| `ui/` | Assembly, HUD, map and inspector |
| `tests/` | Numerical, conservation, full-mission, editor and rendered input checks |

Windows full validation:

```powershell
.\tests\run_tests.ps1 -Godot 'C:\path\to\Godot.exe' -WithRendering
```

The runner imports an isolated `.godot/regression-project` copy, records logs in `.godot/test-results`, and rejects engine error logs and nonzero native exits. It can take several minutes; rendered checks need a graphics device. Generated captures are under the isolated project's `docs/validation`. Individual numerical tests can be run using `godot --headless --path . --script tests/validate_celestial.gd` after import.

Build a Linux x86-64 release entirely from the command line:

```text
python tools/build_linux.py --godot /path/to/Godot
```

See [Linux instructions](docs/LINUX_BUILD.md). If an editor left open during external changes reports stale resource UIDs, restart the editor itself; retain existing UID sidecars.

For Windows x86-64, run `python tools/build_windows.py --godot C:/path/to/Godot.exe`. The CLI builder uses the matching verified templates and an isolated import, then creates `build/windows-x86_64/GodotSpaceProgram/GodotSpaceProgram.exe` with embedded game data and `GodotSpaceProgram-windows-x86_64.zip` with instructions/license notices. Extract the ZIP and double-click the EXE; no editor or separate PCK is needed. SHA-256 checksums accompany the package.

The ZIP also includes **Launch Vulkan.cmd**. On the development Intel Iris Xe machine, the installed OpenGL driver crashed during exported graphical shutdown; the Vulkan/Mobile alternative passed startup and exit. Use that launcher on this machine. This is a backend alternative, not a change to the project's default renderer or physics.

## Approximations and limits

- One rigid integrated body per connected tree, full aggregate inertia; no flexible joints, graph loops, tank slosh or resolved fluid inside tanks.
- Approximate part aerodynamics, volume-sampled water, impulse contacts and patched conics; no CFD, full N-body tides or weather simulation.
- Explicit finite reaction-wheel torque; legacy craft retain idealized electricity unless configured with joule capacity, while the station/tug use the new power system. The training capsule has intentionally strong authority. Gimbal input is bounded, but SAS does not yet allocate commands optimally across gimbals/fins/wheels.
- Solar power, batteries and live flight saves are implemented in the AORS playtest. Part temperature remains a placeholder; thermal damage, crew/career and maneuver nodes are deferred.
- Terrain clipmaps rebuild on recentring, which can delay detail during fast low flight. Coarse orbital terrain and simplified ocean reflections remain visual approximations.
- Debris beyond 200 km from the active craft is culled. Full physics cost and achievable warp depend on part count and debris; see measured performance in the validation report.
- No multiplayer or additional planets. Linux graphical gameplay and other GPUs remain untested.

All visible assets are generated from original procedural code, Godot primitives and its built-in font; no proprietary game assets are included.

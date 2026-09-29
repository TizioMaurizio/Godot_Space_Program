# Aster Flight Lab

A playable, original Godot 4.x launch-to-orbit prototype. Choose a predefined two-stage rocket, fly through a rotating atmosphere, separate the booster and establish an orbit using Newtonian physics. No rocket editor or orbit mode.

## Play

Open `project.godot` in **Godot 4.6.1** (the tested version), then press **F5**. No downloads, external assets, plugins or special double-precision engine build are required. The Compatibility renderer supports ordinary desktop hardware.

Select **Orbital Test Vehicle → Go to launchpad** (or press Enter). Press **Z**, then **Space** to launch. **F1** opens the flight handbook; **F3** opens the physics telemetry overlay. Relaunch and vehicle selection are always available at the top right.

If an editor left open during an external import reports **Unrecognized UID** for newly added files, restart the **Godot editor itself**, then press F5. Restarting only the running game does not refresh the editor's in-memory resource registry. Keep the `.gd.uid` and `.gdshader.uid` files with the source files.

| Control | Action |
| --- | --- |
| W / S | Pitch east / back at launch; body-relative pitch thereafter |
| A / D | Yaw |
| Q / E | Roll (directions inverted from the initial release) |
| Shift / Ctrl | Increase / decrease throttle |
| Z / X | Full / zero throttle |
| Space | First ignition; subsequently separate booster and activate upper stage |
| T / H | SAS off / hold current attitude |
| P / R | Prograde / retrograde |
| 1 / 2 | Radial out / in |
| 3 / 4 | Normal / antinormal |
| Right mouse drag / wheel | Orbit camera / zoom |
| , / . | Decrease / increase time warp |
| Esc | Pause / resume |
| F1 / F3 | Flight handbook / debug values |
| M | Toggle 3D orbit map / flight view |
| F / Tab (map) | Fit orbit / switch focus between planet and spacecraft |

Manual attitude input temporarily overrides SAS. HOLD captures your orientation when you release the controls. PROGRADE uses air-relative velocity below the atmosphere boundary, then inertial velocity in space. A faded navigation marker lies behind the craft; a solid marker is on the forward hemisphere. The green ring is prograde, the crossed orange ring retrograde.

## Orbit map

Press **M** or click **ORBIT MAP** to open the interactive 3D map. **Right-drag** rotates its camera, the **wheel** zooms, **F** fits the whole trajectory and restores its orbital-plane view, and **Tab** switches between planet and spacecraft focus. Press M or click FLIGHT to return. The flight camera keeps its own settings.

The map shows Aster, the atmosphere, your current position/direction of travel, and the predicted coast trajectory. **Ap** and **Pe** mark the apsides of non-circular trajectories. Circular orbits have no unique apsis positions, so their altitude values appear in the sidebar without unstable markers. Orange path segments enter the atmosphere. Suborbital paths end at their first **SURFACE INTERSECTION**; escape paths are open and displayed to a finite range. The sidebar includes orbital speed, period, eccentricity, inclination, propellant, throttle, SAS and warp state.

This is a live map: the simulation continues, and steering, staging, throttle and comma/period warp still work. **Esc** pauses/resumes. The path updates during a burn. It is an instantaneous coast prediction, so future thrust and atmospheric drag change the actual trajectory and impact point. Maneuver nodes, transfer planning and additional bodies are not included yet.

## First orbit

1. Launch at full throttle. Leave SAS in HOLD and climb vertically to about **1 km**.
2. Hold **W** briefly to tip east. Watch the pitch instrument: aim for **65° at 5 km**, **35° at 20 km**, then progressively toward **5–10° at 40–45 km**. Release W between corrections; HOLD stops the turn. Heading should be near **090°**.
3. Watch **apoapsis**, not just altitude. When apoapsis reaches about **120 km**, press **X**. You will still be well below that height and climbing.
4. Press **Space** to drop the booster, even if it still has a little fuel. Press **P** to follow prograde while coasting. If the booster runs dry earlier, stage then and continue the ascent with the upper stage.
5. About **50 seconds before apoapsis**, press **Z** to burn prograde with stage 2. Watch periapsis rise from a negative value. Apsides can change quickly near circularization; reduce throttle with Ctrl if desired.
6. Once periapsis is above **60 km** and **ORBIT ACHIEVED** appears, press **X**. The spacecraft continues orbiting naturally. Press **.** to accelerate time, and **,** to slow it again.

The manual-input validation flight with aerodynamic moments reaches a **162 × 65 km orbit in 301.6 s**, with **72.6% upper-stage propellant** left. The ascent profile is forgiving, but flying vertically for too long wastes fuel and does not establish orbit. Overshooting horizontal speed can produce an escape trajectory, displayed as ESCAPE.

## Time warp and reentry

Press **.** to increase speed and **,** to decrease it: **1×, 2×, 3×, 4×, 10×, 50×, 100×, 1,000×**. The right-hand HUD shows the current rate and mode.

- **Physics warp, 1–4×:** all forces, aerodynamic torque, fuel consumption, controls and debris continue at the original fixed 1/120 s step. Higher rates run more substeps, without stretching the physics timestep. Available in the atmosphere and during burns; warp is disabled on the pad and after impact.
- **Coast warp, 10–1,000×:** available above the atmosphere with the throttle at zero. The two-body trajectory is propagated with a double-precision universal-variable Kepler solver, including elliptical and escape trajectories. Orientation and angular velocity are held during this mode; they resume with physics. Steering, throttle, staging and SAS commands immediately return to 1×.
- **Atmosphere approach:** high warp automatically returns to 1× before it could cross into the atmosphere. A conservative distance bound protects the entire next interval, including suborbital trajectories; a 1 km boundary margin avoids rapid mode switching. The game does not automatically accelerate again after exiting air.

Air drag now depends on the craft's presentation to the flow: broadside flight exposes more area. Drag acts at an offset centre of pressure and creates torque even with **SAS OFF**. The included aft pressure centre tends to align the nose into the airflow, with oscillations damped by the air. Stage resources expose pressure-centre offset, side drag and damping for other stability characteristics. The same model applies to discarded stages.

Fast atmospheric flight produces animated airflow streaks. Reentry adds a windward plasma glow and streaming wake, driven by air-relative speed and density. **HEATING** is a qualitative visual intensity, not temperature or damage; this update does not add thermal destruction or heat shields. The Sun now uses a white core/halo, with matching light direction. Horizontal camera dragging is inverted from the initial release.

## Physics and scale

All simulation units are metres, seconds, kilograms and newtons. Aster is a **600 km-radius** scaled test planet with **9.81 m/s²** surface gravity, **60 km** atmosphere and **6-hour** rotation. `mu = g R²`; this is internally consistent, but not a full-scale model of Earth.

Position and velocity use double-precision scalar components independently of Godot scene coordinates. The scene uses a craft-relative foreground and a separate 1:1000 background viewport for the planet. Physics runs at 60 fixed ticks per second with two 1/120 s substeps per unit of physics warp. Ordinary coast uses velocity Verlet; atmospheric drag uses an endpoint velocity predictor. High coast warp solves the same Newtonian two-body dynamics with universal variables. Attitude integrates quaternion orientation under control and aerodynamic torque, with implicit rotational air damping.

See [architecture and plan](docs/IMPLEMENTATION_PLAN.md), [development journal](docs/DEVELOPMENT_JOURNAL.md) and [validation results](docs/VALIDATION.md).

## Data and source

| Directory | Responsibility |
| --- | --- |
| `definitions/` | Typed planet, atmosphere, vehicle, stage and engine Resources |
| `data/` | Editable `.tres` planet and rocket definitions |
| `simulation/` | Gravity, atmosphere, drag, orbits, propellant, staging, attitude and instrumentation |
| `game/` | Session, keyboard controls, camera, procedural meshes and world rendering |
| `ui/` | Selection screen, HUD, navigation indicator and debug overlay |
| `tests/` | Physics, engine/staging, full-ascent and rendered gameplay regressions |

Duplicate the resources to define additional vehicles or planets and change the selected resource in `game/main.gd`. The vertical slice deliberately exposes only one vehicle in the menu. Models, stages and tank state are separate from resource definitions, allowing a future builder to generate the same vehicle data.

## Run validation

From the project directory (replace `godot` with your Godot executable):

```text
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/validate_physics.gd
godot --headless --path . --script tests/validate_vehicle.gd
godot --headless --path . --script tests/validate_reentry_warp.gd
godot --headless --path . --script tests/validate_map.gd
godot --headless --path . --script tests/validate_ascent.gd
godot --path . --script tests/validate_gameplay.gd
godot --path . --script tests/validate_map_gameplay.gd
```

On Windows, `tests/run_tests.ps1 -Godot 'C:\path\to\Godot.exe' -WithRendering` runs all checks and rejects runtime error logs as well as nonzero exit codes. Physics tests run faster than real time. The last test needs a graphics device and saves screenshots in `docs/validation/`. Its orbital screenshot uses a seeded circular state; the separate ascent regression proves launch-to-orbit without teleportation or direct attitude assignment.

## Deliberate limits

Single spherical planet; no terrain collision beyond the sphere. Point-mass translation with cylinder inertia for attitude. Aerodynamics use approximate projected drag, a stage-defined pressure-centre offset and rotational damping; no lift, detailed part-by-part stability or temperature/damage simulation. Idealized electric attitude control has no power budget. Collision ends the flight; there is no landing or recovery system. Discarded stages are removed on impact or beyond 200 km from the active craft. Atmospheric debris continues at full physics steps even during spacecraft coast warp, so actual acceleration can be CPU-limited. The local visual launch surface is a tangent plane, not terrain. The attitude indicator is an approximate projected horizon, not a full spherical navball. The map shows only the active craft's instantaneous two-body coast path, without future drag/thrust, maneuver nodes or other planets. No rocket editor, missions, multiplayer or save system.

All visible assets are generated from Godot primitives, shaders and its built-in font. No proprietary game assets are used.

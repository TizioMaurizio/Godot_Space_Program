# Validation report

## 2026-10-03 — AORS release checks (limited by user request)

`validate_station.gd`: zero failures, native exit 0, empty error log. Checks three craft recipes, initialized scenario, 193,850 kg mass, one Kepler orbit (<0.01 m closing error), fast docking rejection, valid capture geometry, linear/angular momentum on merge, true 50-part docked graph, state restore, undock, RCS fuel/force, solar generation, distributed batteries and eclipse.

`validate_station_gameplay.gd`: zero failures, native exit 0, empty error log on Vulkan/Mobile. Loads real main scene, station and visiting craft, relative navigation, switching/map, physical soft/hard capture from a near-port fixture, quicksave/reload and undock. Captures 30–33. The short `validate_vehicle.gd` and `validate_modules.gd` also pass. Full older ascent/lunar campaigns and large-station performance sweeps were deliberately not repeated before this playtest release, as requested by the user.

Known release scope: prebuilt orbital station and nearby tug, reusable module carrier, generic docking assembly, save/load and power are available. The carrier's full ascent and a full station assembled through separate launches are unvalidated. Thermal radiators, EVA, articulated arrays, selection of a particular undocking edge in a multi-visitor assembly, electrical network caching and further UI polish remain deferred.

## Windows release package

The Windows x86-64 export has an embedded PCK and passed PE architecture/footer checks. The extracted ZIP's EXE passed headless menu, launchpad and orbit startup, exit 0, empty error logs. Graphical Compatibility/OpenGL startup hit the existing Intel igxelpicd64.dll 32.0.101.5542 shutdown crash. The exported EXE's Vulkan/Mobile graphical launchpad check passed with exit 0 and empty error logs; `Launch Vulkan.cmd` in the package selects it. No system driver or default project renderer was changed. This is a release startup check, not a full Vulkan gameplay regression. Build/smoke logs: `.godot/build-logs/windows-*.log`.

## Final consolidated result — 2026-10-01

All 20 assertion suites/variants have passing runs with exit code 0 and empty error logs after the corrections below. Import, headless scene startup and the profiling script also pass. The full batch identified failures; corrected cases were rerun explicitly rather than treating the initial batch as successful. No physics constants or numerical acceptance tolerances were relaxed.

The final upgraded Linux tarball additionally passed menu, launchpad and orbit startup on Ubuntu/WSL, with no errors or leaked-object warnings. The build/export was entirely command-line driven; graphical Linux play is not claimed. Package checksums and reproduction are in [LINUX_BUILD.md](LINUX_BUILD.md).

| Area | Final checked suites |
| --- | --- |
| Baseline numerical/controls | validate_physics, validate_vehicle, validate_reentry_warp, validate_map |
| New part/module/structural/water | validate_parts, validate_modules, validate_structure, validate_surface_water |
| Missions | nominal and manual validate_ascent (each followed by a complete unpowered orbit), validate_celestial, validate_lunar_mission, validate_lunar_landing |
| Actual rendered scenes/input | validate_gameplay, validate_map_gameplay, validate_structure_gameplay, validate_editor, validate_surface_gameplay, validate_planet_visuals, validate_lunar_gameplay |

Latest manual-input ascent: **307.77 s, 158.847 × 65.088 km**, **74.2%** upper propellant, **22.149 kPa** Max-Q; full engine-off orbit passed with unchanged mass and <1e-6 m reported Pe drift. Latest editor acceptance: **308.55 s, 158.146 × 65.025 km**. The rendered lunar landing now also reaches contact, preserves all eight parts and reports zero displayed surface-relative speed: [capture 29](validation/29_neris_landed.png).

Corrections were verified with their original assertions plus added coverage: transient contact-force clearing; isolated powered debris for two seconds; subsequent component collision/fuel starvation; multi-engine shared-tank scarcity and missing oxidizer; parachute inflation/tearing; disabled wheel torque; malformed craft input. An invalidated host WASAPI device interrupted one graphics run, so graphics automation now explicitly uses the Dummy audio backend. Audible device behavior is not covered by that rerun.

Windows crash events identified the intermittent graphics teardown fault in **igxelpicd64.dll 32.0.101.5542**, exception 0xc0000005, offset 0x1f4784. The final failing graphics fixtures now disable viewport updates, drain/synchronize rendering, free their scene, and defer quit until the render callback returns. The subsequent structural and lunar graphics runs both exited 0 with empty logs. This is validation of the final runs, not a guarantee against all driver problems on this or other GPUs. No OS driver was replaced.

### Performance

Measured on Intel Core i7-1255U (10 cores/12 logical processors), 16 GB RAM, Godot 4.6.1 debug editor executable, Windows, headless script. These are wall-clock microbenchmarks with ordinary host/background activity; they are not portable frame-rate guarantees. Each full-craft measurement averages 40 fixed 1/120 s substeps after warmup. The stress craft is a chain of fueled tank parts; automatic joint deletion is disabled only in this benchmark so part count stays fixed, while forces and load evaluation still run. Vacuum is nonrotating free fall; air is 20 km altitude at approximately 1,000 m/s.

| Parts | Vacuum ms/substep | Air ms/substep | Approx. air physics cost per 60 Hz tick (two substeps) |
| ---: | ---: | ---: | ---: |
| 10 | 0.414 | 2.665 | 5.330 ms |
| 50 | 1.244 | 18.300 | 36.600 ms |
| 100 | 2.290 | 19.949 | 39.898 ms |
| 300 | 3.524 | 71.628 | 143.256 ms |

**The proposed 100-part <4 ms/tick budget is not met**, especially in atmosphere. At 4× physics warp the cost is roughly four times these two-substep values, before rendering and other bodies. Smaller shipped craft are the validated playability target; 300 parts remain a finite stress case, not a promised real-time experience. Earlier runs under different concurrent load varied significantly (100-part vacuum 1.444 ms, air 22.096 ms); retain this variability when interpreting the table.

Topology-time mass aggregation is linear; the original quieter 100/300-part measurements were 3.078/10.619 ms. Cached single-tank mass updates were approximately 0.026–0.028 ms independent of total part count. Full flight caches include part axes/pressure centres/per-kg inertia, actuator lists, fuel routes, graph traversal/joint frames, aero shielding bins and contact spatial hashing. Exact nonrotating uniform-free-fall load evaluation has an algebraic zero-load fast path; no small-but-nonzero torque/load is suppressed. Further atmospheric performance work is explicitly outstanding.

Logs: `.godot/test-results/` and `.godot/phase-results/`. Reproduce all checks with `tests/run_tests.ps1 -Godot <engine> -WithRendering`; use `-Only @('validate_structure','validate_lunar_gameplay')` for a targeted rerun. Tests import an isolated project and preserve the user's open editor cache. [Consolidated architecture/features/limits report](UPGRADE_REPORT.md).

## Upgrade Phase 6 — completed acceptance sequences

`validate_celestial.gd`, `validate_lunar_mission.gd`, `validate_lunar_landing.gd` and `validate_lunar_gameplay.gd` each passed all assertions with native exit 0 and empty error logs in the development sandbox.

| Mission event | Shared simulation time | Physical result |
| --- | ---: | --- |
| Launch → Aster orbit | 308.55 s | 158.146 × 65.025 km; 74.6% upper propellant |
| Parking orbit | 773.27 s | 158.155 × 145.021 km |
| Translunar injection cutoff | 1843.42 s | Aster Ap 2350.751 km; 54.2% upper propellant |
| Neris SOI entry | 5413.42 s | Hyperbolic approach; initial Pe -83.456 km |
| Real approach-correction burn | 5450.83 s | Lunar Pe 25.006 km |
| Retrograde capture | 5915.13 s | Lunar orbit 109.899 × 22.677 km |
| Full unpowered lunar orbit | 10678.64 s | Mass unchanged; Pe drift <0.1 m |
| Lunar departure | 12074.63 s | Positive lunar specific energy |
| Neris escape | 12349.63 s | Continuous inertial state; Aster return conic |
| Aster atmospheric return | 15129.63 s | 59.082 km altitude, 2918.32 m/s, 33.3% upper propellant |

The mission pilot never assigns authoritative position, velocity or attitude. It uses real burns, controller targets and guarded coast. Aster return is proven; safe reentry/recovery in this same mission is not claimed. The separate initialized Neris Explorer descent landed and settled with all eight parts at 46.67 s, using 1.4% upper propellant.

Celestial checks: exact inertial state preservation on reference selection; 30 s normal/coast agreement within 5 cm and 1 mm/s; one lunar orbit Pe drift <1 cm; zero air density; whole-interval guard catches an SOI flyby even if both coarse endpoints would be outside; prediction is read-only and finds encounter/periapsis. Screenshots 26–28 are seeded rendering cases and are not substituted for the physical mission test.

## Upgrade Phase 5

`validate_planet_visuals.gd` passed all assertions, native exit code 0, empty error log. Shared two-layer clouds/atmospheric shell, simulation-time advection and unchanged physical density were checked. Actual orbital/day-night/twilight captures 23–25 were inspected. Phase 4 production ascent: 308.55 s, Ap 158.146 km, Pe 65.025 km, 74.6% upper propellant, Max-Q 22.229 kPa; full engine-off orbit passed with unchanged mass and less than 1e-6 m reported periapsis drift. Core physics, vehicle, map, parts and structure assertions passed. Reentry/warp assertions passed but a script-resource teardown leak is under diagnosis; do not interpret that run as a clean full-suite pass.

## Upgrade Phases 3–4

`validate_editor.gd`: zero failures, successful native process exit and empty error log. Builds a two-stage craft from an empty editor, saves/reloads the exact design, launches and physically reaches orbit (308.72 s, 158.380 × 65.046 km). Also covers symmetry 1/2/3/4/6/8, occupied-port rejection, group deletion, branch copy/move, undo/redo and stage action moves. Captures: 18_vehicle_assembly.png and 19_editor_craft_orbit.png.

`validate_surface_water.gd`: zero failures. Shared render/query surface error below 0.01 m; double frame round-trip below 1e-6 m; capsule equilibrium submerged fraction 0.1076 (expected 0.1102, tolerance 0.02), settles below 0.3 m/s and survives; dense engine sinks; 100 m/s water impact destroys capsule without numerical blow-up. Water fixtures are explicitly seeded independent physical tests, not evidence of an end-to-end mission splashdown.

`validate_surface_gameplay.gd`: actual curved LOD, floating capsule, foam/wakes and underwater fog assertions pass. Captures 20_terrain_launchpad.png, 21_capsule_splashdown.png and 22_underwater.png. Full earlier numerical/flight regression rerun is in progress; subsequent entries record final outcomes.

## Upgrade Phase 2 — part forces and structural failure

`validate_structure.gd` passed free-fall balance, rated-joint survival, deterministic overload failure, component/mass conservation, shielding, force summation, aerodynamic moments, gentle contact and high-energy destruction/persistent wreck checks. `validate_structure_gameplay.gd` passed physical graph breakup, preservation of all six parts, continuing propulsion on a separated tank/engine component and retained nearby rendered debris. Capture: `17_structural_breakup.png`.

Production per-part-aero ascent: 308.72 s, Ap 158.380 km, Pe 65.046 km, 74.4% upper propellant, 22.275 kPa Max-Q; full engine-off coast passed the unchanged drift criterion. This is the expected visible effect of the new aerodynamic model, not an engine/gravity adjustment. Existing rendered gameplay assertions passed. Contact geometry remains a spherical planetary surface until Phase 4; destroyed parts retain inert mass/resources rather than modeling fluid venting.

The rendered teardown gate was resolved on Godot 4.6.1 by releasing the test scene before stopping its renderer. Testing 4.6.3 alone did not fix that lifecycle issue; no engine upgrade is required by this implementation.

## Upgrade Phase 1 — part architecture (2026-10-01)

The active OTV is now a six-PartInstance graph with actual tank resources, module ignition, individual engine forces, full aggregate inertia and changing COM. `validate_parts.gd` checks 29,000 kg wet / 6,000 kg dry mass, analytic COM/tensor math, isolation of stage fuel, mass/COM change, actual off-axis and gimballed engine torque, stage delta-v, graph component membership, spinning split momentum/pose continuity, JSON round-trip/rejection and cached mass-update accuracy at 10/50/100/300 parts.

Nominal ascent: 301.71 s, Ap 161.974 km / Pe 65.051 km, 72.7% upper-stage propellant, Max-Q 24.965 kPa. Manual-input ascent: 301.52 s, Ap 162.130 km / Pe 65.028 km, 72.6% propellant, Max-Q 24.961 kPa. Both completed a full engine-off orbit within the unchanged 5 m periapsis-drift tolerance. These match the approved reference envelopes. The original numerical/vehicle/reentry/warp/map assertions passed. A shutdown script-cache issue was corrected by removing the extra assembly inheritance facade and separating factories from value/design classes; the rendered map test passed with empty error logs afterward. No physics tolerance or gravitational/engine constant was relaxed.

Mass-system profile: cached per-burn updates about 0.03 ms independent of total part count when one tank changes; full rebuild about 3.08 ms at 100 parts and 10.62 ms at 300. Runtime flight/structure/contact profiling will be reported after those systems are integrated. Phase 1's explicitly configured `legacy_envelope` aerodynamics is retained only for migration/reference testing; per-part aerodynamic evaluation is the next phase.

Gate note: an empty-log rendered run still returned native access violation -1073741819 under Godot 4.6.1. Native shutdown must be clean as well as assertions passing; a patched engine is being evaluated before treating that run as a complete gate pass.

Tested on 2026-09-29 with Godot **4.6.1 stable**, standard single-precision engine build, Windows, Compatibility/OpenGL renderer, Intel Iris Xe. Tests execute the project's GDScript physics rather than an independent reimplementation.

## Translational physics

`tests/validate_physics.gd` checks:

- Surface acceleration: **9.810000 m/s²**; acceleration at twice the radius: **2.452500 m/s²**.
- Circular orbit at 100 km, integrated at 1/120 s for **three periods**: maximum radial deviation **0.000250269 m**, within a 1 m acceptance tolerance. Relative energy tolerance is 1e-8.
- Analytic elliptical apsides and half-period time to apoapsis from vis-viva initial conditions.
- Escape and radial trajectories are not classified as stable orbits.
- Density decreases monotonically and reaches exactly zero at 60 km. The last 10% of atmosphere is smoothly tapered.
- Doubling airspeed yields **4× drag**. Co-rotating air and vehicle produce zero drag.
- Dynamic pressure at 100 m/s and 1.225 kg/m³: **6,125 Pa**.

## Rocket and attitude

`tests/validate_vehicle.gd` checks fuel/oxidizer mass reduction, `F / mass_flow = Isp g0`, increasing acceleration as mass falls, zero-throttle behavior, complete depletion, pressure-dependent thrust, conservation of momentum at separation, continued debris physics, staging bounds, SAS convergence and manual pitch/yaw/roll response.

## Complete physical ascent

`tests/validate_ascent.gd` starts with the vehicle constrained to the rotating pad. The test pilot changes throttle, requests staging and commands torque-controlled attitudes. It never writes the spacecraft position or velocity and never snaps the orientation. Test automation is not active in the playable game.

The nominal profile with aerodynamic moments enabled:

| Event | Result |
| --- | --- |
| Initial wet mass | 29,000 kg |
| Peak dynamic pressure | 24.975 kPa |
| Ascent cutoff target | 120 km apoapsis |
| Coast apoapsis after residual atmospheric drag | About 119.4 km |
| Upper-stage restart | 50 s before predicted apoapsis |
| Orbit achieved | 301.79 s after initial simulation start |
| Apsides at cutoff | 161.924 km apoapsis / 65.044 km periapsis |
| Upper-stage propellant remaining | 72.7% |
| Post-cutoff validation | One full orbital period, no thrust |
| Post-cutoff mass | Unchanged |
| Post-cutoff periapsis drift | Less than 0.000001 m in this run; acceptance tolerance 5 m |

The additional `--manual-pilot` variant steers using discrete W/S-equivalent rate commands, a one-degree deadband and decisions at 10 Hz, then ordinary PROGRADE mode for circularization. With the reentry/aerodynamics update it reached **162.128 × 65.015 km** at **301.59 s**, with **72.6%** upper-stage propellant and **24.973 kPa** maximum dynamic pressure, then completed a full engine-off orbit. This verifies the flight can be achieved without feeding precise attitude targets into the controller.

## Reentry and time warp update

`tests/validate_reentry_warp.gd` verifies aerodynamic torque and damping independently of control torque, coast propagation, warp limits, and camera inversion:

| Check | Recorded result |
| --- | --- |
| Passive alignment, SAS OFF, steady flow | 40° to 3.88° error in 60 simulated seconds |
| Applied control torque during passive test | Zero |
| Passive roll damping in air | 1.0 to 0.8873 rad/s in 10 simulated seconds |
| Aerodynamic torque/damping/heating in vacuum | Zero |
| Broadside drag | Greater than 3× axial drag in the test configuration |
| 1,000× circular coast, three orbital periods | Maximum radius error 0.000000019 m |
| Kepler versus 120 Hz force integration | Within 1 cm for the tested elliptical, near-parabolic and hyperbolic trajectories |
| Throttle/steering during coast warp | Returns to 1× |
| Atmospheric warp request | Capped at 4× physics |
| Unsafe interval near atmosphere | Returns to 1× before entry |

The rendered input test additionally verifies comma/period, inverted Q/E, 4× state equivalence to eight ordinary 1/120 s substeps, 1,000× mission-time advance, and immediate cutoff of coast warp on a throttle command. Atmosphere effects are triggered by actual simulation density/airspeed, and disappear in vacuum. These tests use seeded reentry states to isolate the effect; launch-to-orbit remains a separate end-to-end physical regression.

## Rendered gameplay

`tests/validate_gameplay.gd` loads the actual main scene with a graphics device and injects Godot input events. It verifies vehicle selection, ignition, launch, manual pitch, stage separation, engine cutoff, prograde selection, pause, orbit recognition, impact and relaunch. It captures the menu, pad, ascent, staging, handbook, orbit and debug overlay.

The orbit rendering case is explicitly initialized in a circular orbit to test camera/HUD coverage. It is **not** used as evidence of launch-to-orbit capability; the separate ascent regression provides that evidence.

Screenshots: [selection](validation/01_vehicle_selection.png), [launchpad](validation/02_launchpad.png), [ascent](validation/03_ascent.png), [staging](validation/04_staging.png), [handbook](validation/05_handbook.png), [orbit](validation/06_orbit.png), [debug](validation/07_debug.png).

Update captures: [time warp](validation/08_time_warp.png), [reentry plasma](validation/09_reentry.png), [airflow streaks](validation/10_airflow.png), [white Sun](validation/11_white_sun.png).

## Orbit map update

`validate_map.gd` verifies circular path closure/radius, ellipse apsis positions, source-state immutability, exact first-surface clipping including a 0.1 m grazing penetration, finite open escape paths, radial ballistic paths and changed-velocity predictions. `validate_map_gameplay.gd` verifies M toggling, both map/flight buttons, independent camera rotation, wheel zoom, Tab focus, F fit, active throttle and warp, pause preservation and reset on relaunch. The pre-existing rendered gameplay suite also passed with the map integrated.

Rendered captures: [launchpad](validation/12_map_launchpad.png), [circular orbit](validation/13_map_circular.png), [elliptical orbit and apsides](validation/14_map_elliptical.png), [suborbital surface intersection](validation/15_map_suborbital.png), [escape trajectory](validation/16_map_escape.png).

The map is a read-only instantaneous two-body coast prediction. It does not integrate future thrust or aerodynamic forces; the UI states this limitation. In this update, imports and tests ran in an isolated project copy to avoid altering the open editor's UID cache.

## Reproduction and limits

### 2026-10-01 rename and baseline review

The Godot Space Program rename was tested in an isolated project copy. All existing numerical, vehicle, aero/warp, map-prediction and both ascent-pilot assertions passed, as did headless startup and rendered gameplay. Existing simulation/definition/data/test source files were unchanged. The first full run flagged an unsuccessful map-process exit after its assertions passed with no logged errors; an independent map retry passed with exit code 0. That initial process-exit issue was not reproduced.

Menu, flight and map screenshots were inspected for the new title's layout. The rebuilt GodotSpaceProgram Linux archive passed headless menu and orbital startup via its launcher under Ubuntu/WSL. These results validate the rename and current baseline; the part architecture in `IMPLEMENTATION_PLAN.md` is a proposal awaiting approval, not an implemented or tested upgrade.

Use the commands in [README](../README.md), or `tests/run_tests.ps1 -Godot 'C:\path\to\Godot.exe' -WithRendering`. The runner treats Godot error logs as failures even if the process exits with code zero.

Normal flight and physics warp use fixed 120 Hz integration per simulated second, independent of rendering. High vacuum warp propagates the same Newtonian two-body dynamics with universal variables, holding attitude until ordinary physics resumes. Reproducibility here means identical state updates for identical commands, configuration and step count on the same runtime; bit-identical output across all CPUs or Godot versions is not promised. Automated pilots demonstrate feasible ascents, not a guarantee that arbitrary manual flight reaches orbit. Heating remains a visual proxy, with no thermal damage model.

Native desktop automation could not connect to its helper. Actual rendered viewport inspection and engine input-event tests were completed instead. Other GPUs, platforms, Godot versions, long-duration interplanetary escapes and parameter combinations beyond the included vehicle/planet have not been tested.

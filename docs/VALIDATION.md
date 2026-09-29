# Validation report

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

Use the commands in [README](../README.md), or `tests/run_tests.ps1 -Godot 'C:\path\to\Godot.exe' -WithRendering`. The runner treats Godot error logs as failures even if the process exits with code zero.

Normal flight and physics warp use fixed 120 Hz integration per simulated second, independent of rendering. High vacuum warp propagates the same Newtonian two-body dynamics with universal variables, holding attitude until ordinary physics resumes. Reproducibility here means identical state updates for identical commands, configuration and step count on the same runtime; bit-identical output across all CPUs or Godot versions is not promised. Automated pilots demonstrate feasible ascents, not a guarantee that arbitrary manual flight reaches orbit. Heating remains a visual proxy, with no thermal damage model.

Native desktop automation could not connect to its helper. Actual rendered viewport inspection and engine input-event tests were completed instead. Other GPUs, platforms, Godot versions, long-duration interplanetary escapes and parameter combinations beyond the included vehicle/planet have not been tested.

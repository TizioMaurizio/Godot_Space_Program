# Development journal

## 2026-09-29 — Architecture and prototype

The existing project was an empty Godot 4.6 configuration. The implementation follows `IMPLEMENTATION_PLAN.md`.

The test planet uses a 600,000 m radius and 9.81 m/s² surface gravity. Its gravitational parameter is derived as mu = g R² = 3.5316e12 m³/s². This is a deliberately scaled Earth-like test world, not an Earth replica. Atmosphere: 60 km cutoff, 6 km scale height, 1.225 kg/m³ sea-level density, 101325 Pa sea-level pressure, 288.15 K reference temperature. Rotation period: 21,600 s. Shorter orbital distances reduce launch duration while all force and orbit calculations remain in SI units and internally consistent.

Godot's standard Vector3 uses single-precision components; GDScript scalar floats are doubles. Simulation positions and velocities therefore use a small scalar-double vector type. The active craft is the rendering origin; nearby objects use relative positions. The planet is drawn in a separate, scaled background viewport, keeping near-camera geometry and orbital distances out of the same depth buffer. References: [large world coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html), [fixed-tick physics](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html).

Flight dynamics are independent of Node3D and Godot rigid-body gravity. Velocity Verlet preserves coast orbits; thrust and aerodynamic forces enter the same integration path. The only surface constraint is the rotating launchpad before release, plus an impact check after release. There is no orbital motion mode or automated orbit insertion in gameplay.

Validation results and final limitations will be appended as systems are exercised.

## Core validation

The first circular-orbit prototype completed three periods at 100 km with a maximum radius error of 0.000250269 m. Surface and 2R gravity checks passed. The atmosphere/drag tests confirmed monotonic density, zero density above the boundary and 4× drag at twice the speed. A diagnostic `%g` format unsupported by GDScript was replaced with decimal formatting.

### Implemented formulas

- Gravity: `a = -mu * r / |r|³`.
- Atmosphere: `rho = rho0 exp(-max(h,0)/H)`, multiplied by a smooth fade over 54–60 km; pressure follows the same normalized profile. Atmospheric inertial velocity is `omega × r`.
- Drag: `F = -0.5 rho Cd A |v_air| v_air`; dynamic pressure `q = 0.5 rho |v_air|²`.
- Propulsion: constant maximum vacuum mass flow `F_vac / (Isp_vac g0)` times throttle; Isp interpolates between vacuum and sea level using absolute pressure relative to standard 101325 Pa. Thrust equals actual consumed mass per time times local Isp and standard `g0 = 9.80665`.
- Translation: kick-drift-kick velocity Verlet. Gravity is sampled at both positions; the velocity-dependent drag endpoint uses predicted velocity. Burn is limited to available fuel/oxidizer, with average pre/post-burn mass during the integration substep.
- Orbit: `h = r × v`, `energy = v²/2 - mu/r`, `e_vector = (v × h)/mu - r_hat`, `a = -mu/(2 energy)`, `rp = h²/[mu (1+e)]`, `ra = a(1+e)`. Mean anomaly yields time to apoapsis. Stable requires a bound ellipse with both apsides above the configured atmosphere boundary.
- Attitude: local cylinder inertia, quaternion orientation and Euler rigid-body angular equations. A proportional/damping feedback controller sets limited torque, with 12°/s desired-rate and 18°/s² acceleration limits. Manual input commands body rates; with SAS off and no manual input there is no artificial angular damping.
- Staging: separate state objects with residual propellant and inertia. Opposing mass-weighted offsets and separation velocities conserve system center of mass and linear momentum. This first approximation does not conserve the entire extended vehicle's angular momentum through a detailed structural breakup.

## Rocket and gameplay

Added typed engine, stage and vehicle resources. The Orbital Test Vehicle is 29,000 kg at liftoff: a 3,500 kg dry / 18,000 kg propellant booster, a 1,000 kg dry / 5,000 kg propellant upper stage and a 1,500 kg payload. Both engines are throttleable and restartable. Vacuum thrust is 540 kN / 100 kN; Isp is 285–320 s / 270–360 s. Vacuum ideal delta-v is about 6,921 m/s.

Completed selection, pad release, throttle, body-axis pitch/yaw/roll, booster staging, all eight SAS states, impact/relaunch, pause, flight director, handbook, debug telemetry, attitude scope, mouse orbit/zoom camera, procedural rocket/planet/pad, sky/stars and exhaust. Surface-relative and inertial speeds are shown separately. Orbital classification stays part of telemetry; it never changes force integration.

The initial depletion test caught a sub-nanogram floating-point tank residue. Tank values below 1e-9 kg now become exactly zero. Staging momentum and torque-controller convergence passed.

## Complete ascent validation

The torque-command pilot followed the documented eastward profile. It cut thrust at 120 km predicted apoapsis, staged, coasted, then restarted prograde 50 s before apoapsis. Stable orbit was reached at 297.80 s, with Ap 164.445 km, Pe 65.064 km, 71.4% upper-stage propellant and 26.854 kPa peak dynamic pressure. The subsequent engine-off orbital period remained stable, with unchanged mass and sub-micrometre periapsis drift in the recorded run.

## Rendered integration and corrections

Godot headless scene execution and actual OpenGL rendering were both exercised. Engine input events verified selection, launch, pitch, staging, cutoff, SAS, pause, crash and relaunch. Visual captures revealed that a canvas background obscured the local 3D scene; fixed by explicitly compositing two independent viewports (background and transparent foreground) before the HUD. This preserves separate depth buffers and large-world precision. Corrected another unsupported numeric format in the debug vector formatter and aligned the navigation horizon with the pitch control axis.

Native desktop UI automation failed to connect to its Windows helper after recovery attempts. Godot's own rendering and input-event test harness supplied visual and interaction coverage. Captures are stored under `docs/validation/`.

## Known limitations and next steps

Final validation added a discrete manual-input pilot: W/S-equivalent inputs at 10 Hz with a one-degree deadband, HOLD between corrections, and normal PROGRADE for insertion. It achieved Ap **164.873 km**, Pe **65.011 km** at **297.40 s**, retained **71.1%** upper-stage propellant and completed an engine-off orbit. This exercises the same rate-command path used by player steering. The final suite also checks yaw/roll, final-stage bounds, zero-throttle propellant use, analytic ellipse apsides, time to apoapsis, radial trajectories and escape classification. Physics energy drift over three circular orbits was **0.00000000000009 relative**. Headless scene import/execution and rendered gameplay completed with no runtime errors. The distant camera near/far planes now adapt to altitude to preserve background depth precision.

This milestone uses point-mass translation, approximate cylinder inertia, axis-independent drag and idealized unlimited electric attitude-control authority. No lift, aerodynamic moments, heating, structural failure, landing gear or part-to-part collision. Surface impacts end the flight. The local tangent ground patch is visual and disappears above 2.5 km; the spherical planet remains. The attitude scope uses an approximate clipped horizon rather than a textured spherical instrument. Engine exhaust is procedural geometry. No audio, save system, map, time warp, editor or additional worlds are included.

Rendering converts relative coordinates to standard Vector3, while absolute position/velocity remain scalar doubles. Distant scenery still has normal single-precision rendering limits; the two-view approach avoids those limits affecting flight dynamics. Adding terrain, lift/aerodynamic moments, a fuel/power budget for reaction control, and broader parameter/platform testing are suitable later work. Keep any future builder producing the same resource definitions rather than embedding forces in UI or individual meshes.

## Reentry, control inversion and time warp update

User-requested additions supersede the initial no-warp / no-aerodynamic-moments scope above.

### Aerodynamic rotation

Drag now uses `CdA = Cd_axial A_axial + Cd_side (2 radius length) sin²(alpha)`. Its body-space line of action is offset by `pressure_center_fraction * length` along the vehicle's +Y axis. `torque = offset × drag_force` enters the same angular integration as attitude control; SAS OFF disables only control torque. Default pressure centre is 0.12 vehicle lengths aft of COM. Stability depends on this offset, following [NASA's centre-of-pressure explanation](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/rocket-center-of-pressure/).

Distributed-flow rotational damping is approximated from density, airspeed and body dimensions; its velocity term is integrated implicitly to avoid numerical energy gain. Stage resources configure side Cd, pressure-centre fraction and damping. Discarded stages share the model. This is still an approximate single-body model, without lift or calculated part-by-part centres of pressure/mass.

The wind-tunnel regression reduced a 40° misalignment to 3.88° over 60 s with zero SAS torque. Roll decayed from 1.0 to 0.8873 rad/s in 10 s at the tested density. The original 10-second settling threshold was too strict for the lightly damped oscillation; the final test checks longer-term convergence and separately checks damping, torque direction and zero control torque. Vacuum removes all air moments/damping and preserves free principal-axis spin. Broadside drag exceeds axial drag. A discrete-input ascent still reached 162.128 × 65.015 km at 301.59 s with 72.6% upper-stage propellant and then coasted for a full orbit.

### Time acceleration

Comma and period traverse 1, 2, 3, 4, 10, 50, 100, 1000×. Atmospheric and powered flight are limited to 4×, achieved by repeating the fixed 1/120 s integration. High vacuum coast solves the Newtonian two-body problem using the [universal anomaly and Lagrange coefficients](https://orbital-mechanics.space/time-since-periapsis-and-keplers-equation/universal-variables.html); scalar doubles and small-z Stumpff series avoid float32 rounding and cancellation. It does not circularize, alter orbital energy deliberately, or turn a suborbital path into an orbit.

Coast warp holds angular state, consumes no fuel, and exits on steering, throttle, staging, SAS commands or an unsafe next coast interval. For trajectories whose periapsis approaches atmosphere, a conservative travel bound using current speed and maximum boundary gravity prevents even an enter-and-exit crossing within a single accelerated tick. A 1 km margin is used. Failure to converge in the coast solver falls back to 1× without partially mutating state. Atmospheric debris continues normal substeps; vacuum debris uses the same guarded coast solver.

Three circular periods at 1000× produced 0.000000019 m maximum radial error. Coast/force propagation agrees within 1 cm for the tested elliptical, near-parabolic and hyperbolic cases. Input tests verify that 4× produces exactly the same state as eight 1/120 s steps, and that throttle input exits 1000× immediately. Pause and relaunch retain their behavior.

### Visuals and input

Inverted horizontal camera drag and the Q/E roll signs, with regression checks. Replaced the hard-coded amber Sun with a neutral white core/halo and aligned both directional lights with its direction.

Added an air-relative plasma shell, a streaming emissive wake and moving pale airflow streaks. The heating proxy is `clamp(sqrt(rho) (v_air/2200)^3 / 0.2, 0, 1)`; it is qualitative FX intensity, not temperature, heat flux or damage. FX respond to actual air-relative flow and fade outside air. The HUD now shows warp mode/rate, heating intensity and aerodynamic torque in debug view, with updated instructions and reentry guidance.

Rendered tests caught overly dark transparent FX: corrected foreground compositing to premultiplied alpha, consistent with [Godot's viewport behavior](https://github.com/godotengine/godot/issues/99715). Reentry, dense airflow and the white Sun were inspected in actual OpenGL captures. No external assets or packages were added.

Final `tests/run_tests.ps1 -WithRendering` run passed all requested checks with empty error logs: physics/orbital regressions, engine/staging/attitude regressions, the new reentry/warp suite, both complete ascent variants with an engine-off orbit, headless scene execution and rendered gameplay input/FX checks. The nominal attitude-target pilot reached 161.924 × 65.044 km at 301.79 s with 72.7% upper-stage propellant; the discrete-input result above also passed again. Documentation and the F1 handbook include the new controls and limitations.

## Editor UID warning investigation

The user reported five `Unrecognized UID` messages in the editor after the update. They correspond exactly to the new AtmosphericFX script, reentry shader, KeplerCoast script, TimeWarp script and reentry/warp test. All source files and UID sidecars are present; a fresh Godot process resolves all five IDs to the correct paths. A fresh main-scene launch also exited successfully with no errors. The still-open editor predates the external import, consistent with a stale in-memory resource registry. No source IDs were deleted or regenerated. Refresh by restarting the editor itself; documented this in README. Desktop automation was unavailable, so the user's running editor was not force-closed.

## Interactive orbit map

Added the requested map as a read-only visualization, separate from flight dynamics. `OrbitPrediction` derives the current conic from double-precision position/velocity: angular momentum, eccentricity vector, semilatus rectum and an orthogonal orbital-plane basis. Samples follow `r = p / (1 + e cos(nu))` from the craft forward. Ellipses close only when unobstructed; escaping/very extended paths are clipped to a finite display range. Surface roots are calculated before sampling so even grazing intersections cannot be skipped between vertices. Radial degeneracy uses a bounded vacuum-gravity preview and reports a finite turning altitude for bound radial motion.

`OrbitMap` renders a separate scaled planet, atmosphere and depth-tested orbit line in an independent viewport. Screen-space markers show the current craft, apsides and first surface intersection, with collision avoidance for adjacent labels. Circular orbits intentionally omit non-unique apsis pins but retain sidebar values. Orange path segments enter the atmosphere. All predictions are explicitly labeled as coast paths: future burns and atmospheric drag are not forecast.

M / HUD button toggles map; right-drag rotates, wheel zooms, F fits the orbit and Tab switches focus. The map maintains an independent camera. Flight controls, staging, throttle, pause and warp remain active. Returning to selection/relaunch clears map state. The sidebar shows orbit and vehicle values, plus SAS/warp state. No maneuver planning or other bodies were added.

Validation ran in `.godot/map-validation-project`, an isolated source copy, so test imports did not change the running editor's resource registry. `validate_map.gd` covers circular/elliptical geometry, analytic apsis positions, 0.1 m grazing and deep surface intersections, finite escaping/radial paths, read-only state and response to changed velocity. `validate_map_gameplay.gd` exercises actual scene inputs, warp/burns/pause while mapped, camera independence, focus/fit, both toggle buttons and relaunch; it also saves actual rendered map captures. Existing gameplay regressions were rerun against the new scene. All completed with zero failures and empty error logs.

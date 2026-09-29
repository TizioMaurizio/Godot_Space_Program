# Orbital flight vertical slice

1. Build an independent, SI-unit flight dynamics core and verify a circular orbit over multiple periods.
2. Add configurable rotating atmosphere, pressure and drag; validate density and force scaling.
3. Add resource-defined stages, engines and consumable fuel/oxidizer, inertial attitude dynamics and feedback stabilization.
4. Build the vehicle-selection / launch / manual ascent / staging / orbit gameplay loop.
5. Add flight telemetry, attitude indicator, contextual ascent guidance, following camera and procedural environment.
6. Run headless physics regressions, a complete launch-to-orbit regression, and rendered gameplay smoke tests; document results and limitations.

## Architecture and risks

- `simulation/`: double-scalar vectors, translational integrator, gravity, atmosphere, osculating elements, rocket state and attitude controller. No scene-tree dependencies.
- `definitions/` and `data/`: typed Godot Resources for planets, atmospheres, engines, stages and vehicles. SI units throughout.
- `game/`: session orchestration, input, rendering of simulation state, camera and procedural meshes.
- `ui/`: selection, flight instruments, original attitude indicator and debug telemetry.
- `tests/`: executable Godot headless validation scripts.
- Precision: GDScript float components retain 64-bit coordinates. Convert to Vector3 only after subtracting the camera-relative origin. Planet rendering uses a separate scaled background viewport.
- Stability: 60 Hz simulation, two fixed 1/120 s substeps; velocity Verlet for coast, predictor/corrector drag, bounded propellant consumption. No engine physics gravity or orbit mode.
- Attitude: quaternion orientation, integrated angular velocity and cylinder inertia; torque-limited PD stabilization, no transform snapping during flight.
- Orbital elements: explicitly handle circular, radial, parabolic and unbound cases; stable orbit requires a bound ellipse with both apsides above the atmosphere.
- Scope: single spherical planet, two-stage predefined vehicle, simple crash collision with the surface. No construction, map view, time warp, heating or landing system.

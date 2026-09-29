extends SceneTree
## Run: Godot --headless --path . --script tests/validate_physics.gd

var failures: int = 0

func check(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	var planet: PlanetDefinition = load("res://data/aster.tres")
	check(absf(PlanetPhysics.gravity(DVec3.new(0, planet.radius, 0), planet).length() - planet.surface_gravity) < 1e-9, "surface gravity = %.6f m/s²" % planet.surface_gravity)
	check(absf(PlanetPhysics.gravity(DVec3.new(0, 2 * planet.radius, 0), planet).length() - planet.surface_gravity / 4) < 1e-9, "gravity at 2R = g/4")
	var body := FlightBody.new()
	var r: float = planet.radius + 100000.0
	body.position = DVec3.new(0, r, 0)
	body.velocity = DVec3.new(-sqrt(planet.mu() / r), 0, 0)
	var initial := OrbitalMechanics.elements(body.position, body.velocity, planet)
	var period: float = initial.period
	var dt: float = 1.0 / 120.0
	var max_error: float = 0.0
	for i in range(int(3.0 * period / dt)):
		body.integrate(dt, planet, DVec3.new())
		max_error = maxf(max_error, absf(body.position.length() - r))
	var final := OrbitalMechanics.elements(body.position, body.velocity, planet)
	var energy_error: float = absf((final.energy - initial.energy) / initial.energy)
	check(max_error < 1.0, "3 coast orbits: maximum radial error %.9f m" % max_error)
	check(energy_error < 1e-8, "relative specific-energy error %.14f" % energy_error)
	check(final.stable, "circular orbit classified stable")
	# Analytic ellipse initialized at periapsis; no integrator assumptions in expectation.
	var rp: float = planet.radius + 80000.0
	var ra: float = planet.radius + 200000.0
	var a: float = (rp + ra) * 0.5
	var ellipse := OrbitalMechanics.elements(DVec3.new(0, rp, 0), DVec3.new(-sqrt(planet.mu() * (2.0 / rp - 1.0 / a)), 0, 0), planet)
	check(absf(ellipse.periapsis - 80000.0) < 0.01 and absf(ellipse.apoapsis - 200000.0) < 0.01, "elliptical apsides match vis-viva initial conditions")
	check(absf(ellipse.time_to_ap - ellipse.period * 0.5) < 0.01, "time to apoapsis at periapsis = half a period")
	var escaping := OrbitalMechanics.elements(DVec3.new(0, r, 0), DVec3.new(-sqrt(2.1 * planet.mu() / r), 0, 0), planet)
	check(not escaping.bound and not escaping.stable and is_inf(escaping.apoapsis), "hyperbolic escape has no finite apoapsis and is not stable orbit")
	var radial := OrbitalMechanics.elements(DVec3.new(0, r, 0), DVec3.new(0, 100, 0), planet)
	check(not radial.stable and radial.periapsis <= -planet.radius + 0.01, "radial flight is not falsely classified as orbit")
	var previous: float = INF
	var monotonic: bool = true
	for altitude in range(0, 65001, 100):
		var rho: float = PlanetPhysics.density(altitude, planet.atmosphere)
		monotonic = monotonic and rho <= previous
		previous = rho
	check(monotonic and previous == 0.0, "atmosphere density decreases monotonically to zero")
	var d1 := Aerodynamics.drag(DVec3.new(100, 0, 0), 1.225, 0.3, 7).length()
	var d2 := Aerodynamics.drag(DVec3.new(200, 0, 0), 1.225, 0.3, 7).length()
	check(absf(d2 / d1 - 4.0) < 1e-10, "doubling airspeed quadruples drag")
	check(PlanetPhysics.air_velocity(DVec3.new(0, planet.radius, 0), planet).x < 0, "atmosphere rotates east at the equatorial pad")
	var co_rotating := PlanetPhysics.air_velocity(DVec3.new(0, planet.radius, 0), planet)
	check(Aerodynamics.drag(co_rotating.minus(co_rotating), 1.225, 0.3, 7).length() == 0, "co-rotating craft has zero aerodynamic drag")
	check(absf(Aerodynamics.dynamic_pressure(DVec3.new(100, 0, 0), 1.225) - 6125.0) < 1e-8, "dynamic pressure = rho v² / 2")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

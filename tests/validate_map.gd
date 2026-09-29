extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition: failures += 1

func _initialize() -> void:
	var planet: PlanetDefinition = load("res://data/aster.tres")
	var r: float = planet.radius + 100000
	var pos := DVec3.new(0, r, 0)
	var vel := DVec3.new(-sqrt(planet.mu() / r), 0, 0)
	var circular := OrbitPrediction.sample(pos, vel, planet)
	var radial_error: float = 0
	for point: DVec3 in circular.points:
		radial_error = maxf(radial_error, absf(point.length() - r))
	check(circular.closed and circular.points.size() == 721 and radial_error < 0.001, "circular map path closes at the correct physical radius")
	check(circular.apoapsis_position == null and circular.periapsis_position == null, "circular path avoids ambiguous apsis markers")
	check(pos.x == 0 and pos.y == r and vel.y == 0, "prediction leaves source position and velocity unchanged")
	var rp: float = planet.radius + 80000
	var ra: float = planet.radius + 300000
	var ellipse := OrbitPrediction.sample(DVec3.new(0, rp, 0), DVec3.new(-sqrt(planet.mu() * (2 / rp - 2 / (rp + ra))), 0, 0), planet)
	check(ellipse.closed and absf(ellipse.apoapsis_position.length() - ra) < 0.001 and absf(ellipse.periapsis_position.length() - rp) < 0.001, "elliptical map apsides match analytic orbital radii")
	check(ellipse.apoapsis_position.y < 0 and ellipse.periapsis_position.y > 0, "apsis markers lie on the correct ends of the major axis")
	for depth in [80000.0, 0.1]:
		rp = planet.radius - depth
		ra = planet.radius + 120000
		var suborbital := OrbitPrediction.sample(DVec3.new(0, ra, 0), DVec3.new(-sqrt(planet.mu() * (2 / ra - 2 / (rp + ra))), 0, 0), planet)
		var minimum: float = INF
		for point: DVec3 in suborbital.points:
			minimum = minf(minimum, point.length())
		check(suborbital.impact != null and not suborbital.closed and minimum >= planet.radius - 0.001, "surface intersection clips trajectory, including %.1f m grazing penetration" % depth)
		check(absf(suborbital.impact.length() - planet.radius) < 0.001, "impact marker lies exactly on spherical surface")
	var escaping := OrbitPrediction.sample(pos, vel.scaled(1.6), planet)
	check(not escaping.closed and escaping.clipped and escaping.apoapsis_position == null, "escape path is finite to display, open, and has no apoapsis")
	var finite: bool = true
	for point: DVec3 in escaping.points:
		finite = finite and is_finite(point.length())
	check(finite, "escape projection contains no infinite vertices")
	var radial := OrbitPrediction.sample(DVec3.new(0, planet.radius + 30000, 0), DVec3.new(0, 200, 0), planet)
	check(radial.radial and radial.impact != null and radial.points.size() > 2, "radial ballistic flight has a valid finite surface-intersecting path")
	check(is_finite(radial.orbit.apoapsis) and radial.apoapsis_position != null, "bound radial flight reports a finite turning altitude, not escape")
	var changed := OrbitPrediction.sample(pos, vel.scaled(1.1), planet)
	check(changed.orbit.apoapsis > circular.orbit.apoapsis + 10000, "trajectory prediction responds to changed velocity during burns")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

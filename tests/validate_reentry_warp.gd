extends SceneTree

var failures: int = 0
var planet: PlanetDefinition = load("res://data/aster.tres")
var vehicle: VehicleDefinition = load("res://data/orbital_test_vehicle.tres")

func check(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition:
		failures += 1

func entry_body() -> FlightBody:
	var body := FlightBody.new()
	body.mass = 6000.0
	body.length = 12.0
	body.position = DVec3.new(0, planet.radius + 25000, 0)
	body.velocity = PlanetPhysics.air_velocity(body.position, planet).plus(DVec3.new(0, 1800, 0))
	body.orientation = Quaternion(Vector3.BACK, deg_to_rad(40.0))
	return body

func _initialize() -> void:
	var body := entry_body()
	body.sample_atmosphere(planet)
	var first_angle: float = body.orientation.angle_to(Quaternion.IDENTITY)
	var controller := AttitudeController.new()
	controller.set_mode(AttitudeController.Mode.OFF, body.orientation)
	check(body.aerodynamic_torque.length() > 1000, "off-centre drag generates aerodynamic torque")
	# Hold the wind-tunnel flow fixed to isolate the angular aerodynamic response.
	for i in range(7200):
		body.sample_atmosphere(planet)
		controller.step(body, planet, Vector3.ZERO, 1.0 / 120)
	check(body.orientation.angle_to(Quaternion.IDENTITY) < first_angle * 0.2, "airflow reorients the craft with SAS OFF: %.2f to %.2f deg in 60 s" % [rad_to_deg(first_angle), rad_to_deg(body.orientation.angle_to(Quaternion.IDENTITY))])
	check(controller.last_torque.length() == 0, "SAS-off reorientation uses zero control torque")
	body.orientation = Quaternion.IDENTITY
	body.sample_atmosphere(planet)
	var axial_drag: float = body.drag_force.length()
	body.orientation = Quaternion(Vector3.BACK, PI / 2)
	body.sample_atmosphere(planet)
	check(body.drag_force.length() > axial_drag * 3, "broadside presentation increases drag")
	check(body.heating > 0.1, "dense hypersonic airflow activates heating FX proxy")
	body.position = DVec3.new(0, planet.radius + 100000, 0)
	body.sample_atmosphere(planet)
	check(body.aerodynamic_torque.length() == 0 and body.damping_coefficient.length() == 0 and body.heating == 0, "vacuum produces no aerodynamic torque, damping or heating")
	body.angular_velocity = Vector3(0.2, 0, 0)
	for i in range(120):
		body.integrate_attitude(Vector3.ZERO, 1.0 / 120)
	check(absf(body.angular_velocity.x - 0.2) < 1e-6, "SAS-off principal-axis spin persists in vacuum")
	body = entry_body()
	body.orientation = Quaternion.IDENTITY
	body.angular_velocity = Vector3(0, 1, 0)
	for i in range(1200):
		body.sample_atmosphere(planet)
		body.integrate_attitude(Vector3.ZERO, 1.0 / 120)
	check(absf(body.angular_velocity.y) < 0.95, "atmospheric damping reduces roll without SAS: 1.0 to %.4f rad/s" % body.angular_velocity.y)
	var r: float = planet.radius + 100000
	var orbit_body := FlightBody.new()
	orbit_body.position = DVec3.new(0, r, 0)
	orbit_body.velocity = DVec3.new(-sqrt(planet.mu() / r), 0, 0)
	var start := OrbitalMechanics.elements(orbit_body.position, orbit_body.velocity, planet)
	var max_drift: float = 0.0
	var solved: bool = true
	for i in range(int(3.0 * start.period / (1000.0 / 60.0))):
		solved = KeplerCoast.advance(orbit_body, planet, 1000.0 / 60.0) and solved
		max_drift = maxf(max_drift, absf(orbit_body.position.length() - r))
	check(solved and max_drift < 0.01, "1000x coast for three periods: radius drift %.9f m" % max_drift)
	# Compare coast against the force integrator for ellipse, parabola and escape.
	for speed_factor in [0.9, sqrt(2.0), 1.6]:
		var direct := FlightBody.new()
		var coast := FlightBody.new()
		direct.position = DVec3.new(0, r, 0)
		direct.velocity = DVec3.new(-sqrt(planet.mu() / r) * speed_factor, 150, 0)
		coast.position = direct.position
		coast.velocity = direct.velocity
		var forward_ok: bool = KeplerCoast.advance(coast, planet, 30.0)
		for i in range(3600):
			direct.integrate(1.0 / 120, planet, DVec3.new())
		check(forward_ok and coast.position.minus(direct.position).length() < 0.01, "Kepler/force agreement at speed factor %.3f" % speed_factor)
	var rocket := RocketState.new(vehicle, planet)
	rocket.on_pad = false
	rocket.position = DVec3.new(0, r, 0)
	rocket.velocity = DVec3.new(-sqrt(planet.mu() / r), 0, 0)
	var warp := TimeWarp.new()
	for i in range(20): warp.change(1, rocket, planet)
	check(warp.rate() == 1000, "coasting outside atmosphere permits 1000x")
	warp.enforce(rocket, planet, Vector3(0, 0, 1), 0)
	check(warp.rate() == 1, "manual steering cancels coast warp")
	warp.index = 7
	rocket.throttle = 0.1
	warp.enforce(rocket, planet, Vector3.ZERO, 0)
	check(warp.rate() == 1, "throttle cancels coast warp")
	rocket.throttle = 0
	rocket.position = DVec3.new(0, planet.radius + 30000, 0)
	for i in range(20): warp.change(1, rocket, planet)
	check(warp.rate() == 4, "atmosphere caps requests at 4x physics")
	warp.change(-1, rocket, planet)
	check(warp.rate() == 3, "comma-equivalent request decreases rate")
	warp.index = 7
	rocket.position = DVec3.new(0, planet.radius + 70000, 0)
	rocket.velocity = DVec3.new(-1500, -1000, 0)
	warp.enforce(rocket, planet, Vector3.ZERO, 0)
	check(warp.rate() == 1 and rocket.position.length() > planet.radius + planet.atmosphere.height, "high warp drops BEFORE atmospheric crossing")
	var camera := OrbitCamera.new()
	camera.dragging = true
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(10, 0)
	var azimuth: float = camera.azimuth
	camera.handle(mouse)
	check(camera.azimuth > azimuth, "horizontal camera drag uses the inverted direction")
	camera.free()
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

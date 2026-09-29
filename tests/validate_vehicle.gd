extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	var planet: PlanetDefinition = load("res://data/aster.tres")
	var vehicle: VehicleDefinition = load("res://data/orbital_test_vehicle.tres")
	var stage := RocketStage.new(vehicle.stages[0])
	var initial_mass: float = stage.mass()
	var thrust: float = stage.burn(1.0, 1.0, 0.0)
	var consumed: float = initial_mass - stage.mass()
	check(consumed > 0, "burn consumes fuel and oxidizer, reducing mass")
	check(absf(thrust / consumed - stage.definition.engine.vacuum_isp * EngineDefinition.G0) < 1e-6, "thrust / mass flow = Isp * g0")
	var first_accel: float = thrust / stage.mass()
	stage.burn(1.0, 1.0, 0.0)
	check(thrust / stage.mass() > first_accel, "acceleration increases as propellant is consumed")
	stage.burn(100000.0, 1.0, 0.0)
	check(stage.fuel >= 0 and stage.oxidizer >= 0 and stage.burn(1.0, 1.0, 0.0) == 0, "depletion never produces negative propellant or free thrust")
	var sea := RocketStage.new(vehicle.stages[0])
	check(sea.burn(1, 1, 1) < thrust, "sea-level thrust is lower than vacuum thrust")
	var rocket := RocketState.new(vehicle, planet)
	rocket.ignited = true
	rocket.on_pad = false
	var momentum := rocket.velocity.scaled(rocket.mass)
	var dropped := rocket.activate_stage()
	var after := rocket.velocity.scaled(rocket.mass).plus(dropped.velocity.scaled(dropped.mass))
	check(after.minus(momentum).length() < 1e-6, "staging conserves linear momentum")
	check(dropped.position.minus(rocket.position).length() > 10, "stages physically separate")
	var before: float = dropped.position.length()
	dropped.integrate(1.0 / 120, planet, DVec3.new())
	check(dropped.position.length() != before, "detached stage continues through the same physics integrator")
	var target := Quaternion(Vector3.BACK, deg_to_rad(35))
	rocket.controller.target = target
	for i in range(1200):
		rocket.controller.step(rocket, planet, Vector3.ZERO, 1.0 / 120)
	check(rocket.orientation.angle_to(target) < 0.01, "SAS converges on an attitude through torque integration")
	var actual_before := rocket.orientation
	rocket.controller.set_mode(AttitudeController.Mode.OFF, rocket.orientation)
	for i in range(120):
		rocket.controller.step(rocket, planet, Vector3(0, 0, 1), 1.0 / 120)
	check(rocket.orientation.angle_to(actual_before) > 0.05, "manual pitch works with SAS off")
	for input_axis in [Vector3(1, 0, 0), Vector3(0, 1, 0)]:
		var control_body := FlightBody.new()
		var control := AttitudeController.new()
		control.set_mode(AttitudeController.Mode.OFF, control_body.orientation)
		for i in range(120):
			control.step(control_body, planet, input_axis, 1.0 / 120)
		check(control_body.orientation.angle_to(Quaternion.IDENTITY) > 0.05, "manual %s produces integrated rotation" % ("yaw" if input_axis.x > 0 else "roll"))
	check(rocket.activate_stage() == null and rocket.stage_index == 1, "stage command cannot discard the final propulsion stage")
	var idle := RocketStage.new(vehicle.stages[1])
	var idle_mass: float = idle.mass()
	check(idle.burn(100.0, 0.0, 0.0) == 0.0 and idle.mass() == idle_mass, "engine cutoff consumes no propellant")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

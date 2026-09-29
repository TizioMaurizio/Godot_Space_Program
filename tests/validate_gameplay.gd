extends SceneTree
## Run with a rendering device, not --headless. Saves actual viewport captures.
var failures: int = 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition:
		failures += 1

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture(filename: String) -> void:
	game.hud.update_display(game.rocket, game.planet, FlightComputer.read(game.rocket, game.planet), game.menu)
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/" + filename + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	check(game.menu and game.rocket.on_pad, "game starts with vehicle selection and a configured rocket")
	await capture("01_vehicle_selection")
	await key(KEY_ENTER)
	check(not game.menu and game.rocket.on_pad, "ENTER selects vehicle and opens launchpad")
	await capture("02_launchpad")
	await key(KEY_Z)
	await key(KEY_SPACE)
	check(game.rocket.throttle == 1.0 and game.rocket.ignited, "full-throttle and ignition key events reach gameplay")
	for i in range(1200):
		game._physics_process(1.0 / 60)
	check(not game.rocket.on_pad and game.rocket.position.length() > game.planet.radius + 1000, "rocket lifts off through thrust physics")
	var pitch_before: float = FlightComputer.read(game.rocket, game.planet).pitch
	Input.action_press("pitch_down")
	for i in range(150):
		game._physics_process(1.0 / 60)
	Input.action_release("pitch_down")
	check(FlightComputer.read(game.rocket, game.planet).pitch < pitch_before - 10.0, "W input pitches the rocket eastward")
	await key(KEY_H)
	for i in range(900):
		game._physics_process(1.0 / 60)
	await capture("03_ascent")
	await key(KEY_SPACE)
	check(game.rocket.stage_index == 1 and game.debris.size() == 1, "SPACE separates the booster and selects the upper stage")
	for i in range(120):
		game._physics_process(1.0 / 60)
	await capture("04_staging")
	await key(KEY_X)
	await key(KEY_P)
	check(game.rocket.throttle == 0 and game.rocket.controller.mode == AttitudeController.Mode.PROGRADE, "cutoff and prograde hotkeys work")
	await key(KEY_ESCAPE)
	var old_position: DVec3 = game.rocket.position
	game._physics_process(1.0 / 60)
	check(game.rocket.position.minus(old_position).length() == 0.0, "pause prevents simulation stepping")
	await key(KEY_ESCAPE)
	await key(KEY_F1)
	await capture("05_handbook")
	await key(KEY_F1)
	# Seed a separate circular-orbit rendering case; ascent is validated independently.
	game.rocket.position = DVec3.new(0, game.planet.radius + 100000, 0)
	game.rocket.velocity = DVec3.new(-sqrt(game.planet.mu() / game.rocket.position.length()), 0, 0)
	game.rocket.orientation = Quaternion(Vector3.BACK, PI / 2)
	game.rocket.controller.target = game.rocket.orientation
	game.camera.elevation = 0.65
	for i in range(120):
		game._physics_process(1.0 / 60)
	await capture("06_orbit")
	check(FlightComputer.read(game.rocket, game.planet).orbit.stable, "HUD telemetry recognizes a stable orbit")
	await key(KEY_F3)
	await capture("07_debug")
	game.reset_flight(false)
	game.rocket.on_pad = false
	game.rocket.position = DVec3.new(0, game.planet.radius + 15, 0)
	game.rocket.velocity = DVec3.new(0, -100, 0)
	for i in range(20):
		game._physics_process(1.0 / 60)
	check(game.rocket.crashed and game.rocket.throttle == 0, "surface impact ends the flight and cuts thrust")
	game.hud.restart_requested.emit()
	check(game.rocket.on_pad and not game.rocket.crashed and game.debris.is_empty(), "relaunch clears debris and resets the vehicle")
	# Physics warp executes the exact same 120 Hz steps, including fuel and forces.
	game.rocket.on_pad = false
	game.rocket.position = DVec3.new(0, game.planet.radius + 12000, 0)
	game.rocket.velocity = DVec3.new(-500, 300, 0)
	var reference := RocketState.new(game.vehicle, game.planet)
	reference.on_pad = false
	reference.position = game.rocket.position
	reference.velocity = game.rocket.velocity
	for i in range(3): await key(KEY_PERIOD)
	check(game.time_warp.rate() == 4, "period key selects 4x atmospheric physics warp")
	var old_time: float = game.rocket.elapsed
	game._physics_process(1.0 / 60)
	for i in range(8): reference.step(1.0 / 120, game.planet)
	check(absf(game.rocket.elapsed - old_time - 4.0 / 60) < 1e-9 and game.rocket.position.minus(reference.position).length() < 1e-7, "4x warp matches eight ordinary physics substeps")
	await key(KEY_COMMA)
	check(game.time_warp.rate() == 3, "comma key decreases warp")
	game.time_warp.reset()
	# The Q/E swap is tested on the actual input path in vacuum, without aero torque.
	game.rocket.position = DVec3.new(0, game.planet.radius + 100000, 0)
	game.rocket.angular_velocity = Vector3.ZERO
	game.rocket.orientation = Quaternion.IDENTITY
	game.rocket.controller.set_mode(AttitudeController.Mode.OFF, game.rocket.orientation)
	Input.action_press("roll_left")
	game._physics_process(1.0 / 60)
	Input.action_release("roll_left")
	check(game.rocket.angular_velocity.y > 0, "Q roll direction is inverted")
	game.rocket.angular_velocity = Vector3.ZERO
	Input.action_press("roll_right")
	game._physics_process(1.0 / 60)
	Input.action_release("roll_right")
	check(game.rocket.angular_velocity.y < 0, "E roll direction is inverted")
	game.rocket.velocity = DVec3.new(-sqrt(game.planet.mu() / game.rocket.position.length()), 0, 0)
	for i in range(7): await key(KEY_PERIOD)
	old_time = game.rocket.elapsed
	game._physics_process(1.0 / 60)
	check(game.time_warp.rate() == 1000 and absf(game.rocket.elapsed - old_time - 1000.0 / 60) < 1e-8, "1000x coast advances mission time and orbit")
	await capture("08_time_warp")
	await key(KEY_Z)
	check(game.time_warp.rate() == 1 and game.rocket.throttle == 1, "throttle hotkey exits coast warp immediately")
	# Reentry setup: a misaligned upper stage, SAS off, descending through air.
	game.reset_flight(false)
	game.hud.debug = false
	game.rocket.on_pad = false
	game.rocket.ignited = true
	game.stage()
	game.rocket.position = DVec3.new(0, game.planet.radius + 26000, 0)
	game.rocket.velocity = DVec3.new(-2600, -600, 0)
	game.rocket.orientation = Quaternion(Vector3.BACK, deg_to_rad(65))
	game.rocket.controller.set_mode(AttitudeController.Mode.OFF, game.rocket.orientation)
	game.camera.distance = 46
	game.camera.elevation = 0.35
	for i in range(30): game._physics_process(1.0 / 60)
	for i in range(24): await process_frame
	check(game.atmospheric_fx.visible and game.atmospheric_fx.heat > 0.2, "reentry plasma FX activates from actual air density and speed")
	await capture("09_reentry")
	game.rocket.position = DVec3.new(0, game.planet.radius + 5000, 0)
	game.rocket.velocity = DVec3.new(-700, -100, 0)
	game.rocket.orientation = AttitudeController.pointing(game.rocket.velocity.vec(), Quaternion.IDENTITY)
	game.rocket.angular_velocity = Vector3.ZERO
	for i in range(12): game._physics_process(1.0 / 60)
	for i in range(30): await process_frame
	check(game.atmospheric_fx.drag > 0.2, "dense fast airflow activates drag streaks")
	await capture("10_airflow")
	game.rocket.position = DVec3.new(0, game.planet.radius + 100000, 0)
	game.rocket.velocity = DVec3.new(-sqrt(game.planet.mu() / game.rocket.position.length()), 0, 0)
	game.rocket.sample_atmosphere(game.planet)
	game.camera.azimuth = atan2(-0.5, -0.6) + 0.12
	game.camera.elevation = asin(-0.7 / Vector3(-0.5, 0.7, 0.6).length())
	for i in range(30): await process_frame
	await capture("11_white_sun")
	check(game.rocket.heating == 0 and game.rocket.aerodynamic_torque.length() == 0, "reentry effects and torque have no source in vacuum")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

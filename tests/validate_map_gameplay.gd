extends SceneTree

var game: Node
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition: failures += 1

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
	Input.parse_input_event(event)
	await process_frame

func capture(filename: String) -> void:
	game.orbit_map.refresh_path()
	game.orbit_map.fit_view()
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://docs/validation/" + filename + ".png") == OK, "rendered " + filename)

func set_ellipse(ra: float, rp: float) -> void:
	game.rocket.position = DVec3.new(0, rp, 0)
	game.rocket.velocity = DVec3.new(-sqrt(game.planet.mu() * (2 / rp - 2 / (rp + ra))), 0, 0)
	game.rocket.sample_atmosphere(game.planet)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	await key(KEY_M)
	check(not game.map_active, "map is unavailable on vehicle-selection screen")
	await key(KEY_ENTER)
	await key(KEY_M)
	check(game.map_active and game.orbit_map.visible and not game.hud.visible, "M opens map from launchpad")
	await capture("12_map_launchpad")
	game.rocket.on_pad = false
	game.rocket.ignited = true
	game.rocket.launch_time = 0
	var radius: float = game.planet.radius
	set_ellipse(radius + 100000, radius + 100000)
	await capture("13_map_circular")
	set_ellipse(radius + 300000, radius + 80000)
	await capture("14_map_elliptical")
	var start_time: float = game.rocket.elapsed
	for i in range(5): await key(KEY_PERIOD)
	game._physics_process(1.0 / 60)
	check(game.rocket.elapsed > start_time and game.time_warp.rate() == 50, "time warp and simulation continue in map view")
	await key(KEY_Z)
	check(game.rocket.throttle == 1 and game.time_warp.rate() == 1, "throttle control in map exits coast warp")
	var old_velocity: DVec3 = game.rocket.velocity
	game._physics_process(1.0 / 60)
	check(game.rocket.velocity.minus(old_velocity).length() > 0.01, "engine burn advances physics while map is open")
	await key(KEY_X)
	await key(KEY_ESCAPE)
	start_time = game.rocket.elapsed
	game._physics_process(1.0 / 60)
	check(game.rocket.elapsed == start_time, "ESC pauses simulation in map view")
	await key(KEY_M)
	check(not game.map_active and game.hud.visible and game.paused, "M returns to flight without clearing pause")
	await key(KEY_M)
	await key(KEY_ESCAPE)
	var old_yaw: float = game.camera.azimuth
	var old_map_yaw: float = game.orbit_map.yaw
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	game._unhandled_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, 20)
	game._unhandled_input(motion)
	check(game.orbit_map.yaw > old_map_yaw and game.camera.azimuth == old_yaw, "map drag rotates its own camera without changing flight camera")
	mouse.pressed = false
	game._unhandled_input(mouse)
	var zoom_before: float = game.orbit_map.zoom_target
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	mouse.pressed = true
	game._unhandled_input(mouse)
	check(game.orbit_map.zoom_target < zoom_before, "wheel zoom changes map scale")
	await key(KEY_TAB)
	check(game.orbit_map.focus_craft, "TAB focuses spacecraft")
	await key(KEY_F)
	check(not game.orbit_map.focus_craft and game.orbit_map.yaw == 0, "F fits the orbit and restores planet focus")
	var ra: float = radius + 120000
	var rp: float = radius - 80000
	game.rocket.position = DVec3.new(0, ra, 0)
	game.rocket.velocity = DVec3.new(-sqrt(game.planet.mu() * (2 / ra - 2 / (rp + ra))), 0, 0)
	await capture("15_map_suborbital")
	check(game.orbit_map.prediction.impact != null, "map shows a surface intersection for a suborbital arc")
	game.rocket.position = DVec3.new(0, radius + 100000, 0)
	game.rocket.velocity = DVec3.new(-sqrt(game.planet.mu() / game.rocket.position.length()) * 1.6, 0, 0)
	await capture("16_map_escape")
	game.orbit_map.flight_requested.emit()
	check(not game.map_active and not game.orbit_map.dragging, "flight button exits map and releases drag state")
	game.hud.map_requested.emit()
	check(game.map_active, "HUD orbit-map button opens map")
	game.reset_flight(false)
	check(not game.map_active and not game.orbit_map.initialized_view and game.hud.visible, "relaunch resets map state and restores flight UI")
	print("RESULT: %d failures" % failures)
	# Dispose the rendered scene while the renderer is still alive, then quit.
	game.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(1 if failures else 0)

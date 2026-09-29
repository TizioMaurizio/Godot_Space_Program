extends Node3D

const SUBSTEP: float = 1.0 / 120.0
var planet: PlanetDefinition = preload("res://data/aster.tres")
var vehicle: VehicleDefinition = preload("res://data/orbital_test_vehicle.tres")
var rocket: RocketState
var rocket_visual := RocketVisual.new()
var camera := OrbitCamera.new()
var world := WorldVisual.new()
var hud := FlightHUD.new()
var debris: Array[FlightBody] = []
var debris_visuals: Array[Node3D] = []
var menu: bool = true
var paused: bool = false
var ui_clock: float = 0.0
var foreground: SubViewport
var time_warp := TimeWarp.new()
var atmospheric_fx := AtmosphericFX.new()
var orbit_map := OrbitMap.new()
var map_active: bool = false

func _ready() -> void:
	configure_input()
	# Explicit alpha compositing: scaled background, metre-scale foreground, then HUD.
	foreground = SubViewport.new()
	foreground.size = Vector2i(1440, 900)
	foreground.own_world_3d = true
	foreground.transparent_bg = true
	foreground.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(foreground)
	foreground.add_child(world)
	world.setup(planet, self)
	foreground.add_child(rocket_visual)
	foreground.add_child(atmospheric_fx)
	foreground.add_child(camera)
	var foreground_layer := CanvasLayer.new()
	foreground_layer.layer = -5
	add_child(foreground_layer)
	var foreground_texture := TextureRect.new()
	foreground_texture.texture = foreground.get_texture()
	# A transparent 3D viewport contains premultiplied RGB. Preserve luminous
	# translucent effects instead of multiplying their opacity a second time.
	var composite_material := CanvasItemMaterial.new()
	composite_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	foreground_texture.material = composite_material
	foreground_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	foreground_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foreground_layer.add_child(foreground_texture)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 3
	add_child(map_layer)
	map_layer.add_child(orbit_map)
	orbit_map.flight_requested.connect(toggle_map)
	hud.map_requested.connect(toggle_map)
	hud.warp = time_warp
	hud.launch_requested.connect(func(): reset_flight(false))
	hud.restart_requested.connect(func(): reset_flight(false))
	hud.menu_requested.connect(func(): reset_flight(true))
	hud.quit_requested.connect(get_tree().quit)
	hud.sas_requested.connect(func(mode: int):
		if time_warp.is_coasting():
			time_warp.reset("Attitude input: normal speed")
		rocket.controller.set_mode(mode as AttitudeController.Mode, rocket.orientation))
	reset_flight(true)
	# Reproducible smoke-test entrypoints; no flight automation is enabled in normal play.
	if "--flight-smoke" in OS.get_cmdline_user_args():
		reset_flight(false)
	if "--orbit-smoke" in OS.get_cmdline_user_args():
		reset_flight(false)
		rocket.on_pad = false
		rocket.position = DVec3.new(0, planet.radius + 100000, 0)
		rocket.velocity = DVec3.new(-sqrt(planet.mu() / rocket.position.length()), 0, 0)
		rocket.orientation = Quaternion(Vector3.BACK, PI / 2)
		rocket.controller.target = rocket.orientation

func configure_input() -> void:
	var keys := {"pitch_down": KEY_W, "pitch_up": KEY_S, "yaw_left": KEY_A, "yaw_right": KEY_D,
		"roll_left": KEY_Q, "roll_right": KEY_E, "throttle_up": KEY_SHIFT, "throttle_down": KEY_CTRL}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

func reset_flight(to_menu: bool) -> void:
	map_active = false
	if is_instance_valid(orbit_map.viewport):
		orbit_map.close()
	orbit_map.initialized_view = false
	hud.visible = true
	for visual in debris_visuals:
		visual.queue_free()
	debris.clear()
	debris_visuals.clear()
	rocket = RocketState.new(vehicle, planet)
	time_warp.reset()
	atmospheric_fx.heat = 0.0
	atmospheric_fx.drag = 0.0
	atmospheric_fx.visible = false
	rocket_visual.rebuild(rocket)
	menu = to_menu
	paused = false
	hud.paused = false
	hud.help = false
	camera.distance = 62.0
	camera.smooth_distance = 62.0
	camera.smooth_up = Vector3.UP
	camera.azimuth = 0.55
	camera.elevation = 0.18

func stage() -> void:
	var dropped := rocket.activate_stage()
	if dropped:
		debris.append(dropped)
		var visual := Node3D.new()
		RocketVisual.cylinder(visual, dropped.radius, dropped.radius, dropped.length, 0, RocketVisual.material(Color("a3b1b6"), 0.3))
		RocketVisual.cylinder(visual, 0.95, 0.4, 1.0, -dropped.length * 0.5, RocketVisual.material(Color("1b303b")))
		foreground.add_child(visual)
		debris_visuals.append(visual)
		rocket_visual.rebuild(rocket)

func _unhandled_input(event: InputEvent) -> void:
	if map_active:
		orbit_map.handle(event)
	else:
		camera.handle(event)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER and menu:
		reset_flight(false)
	if menu:
		return
	if event.keycode == KEY_M:
		toggle_map()
		return
	match event.keycode:
		KEY_ESCAPE:
			paused = not paused
			hud.paused = paused
		KEY_F1: hud.help = not hud.help
		KEY_F3: hud.debug = not hud.debug
	if paused:
		return
	if time_warp.is_coasting() and event.keycode in [KEY_Z, KEY_X, KEY_SPACE, KEY_T, KEY_H, KEY_P, KEY_R, KEY_1, KEY_2, KEY_3, KEY_4]:
		time_warp.reset("Flight input: normal speed")
	match event.keycode:
		KEY_COMMA: time_warp.change(-1, rocket, planet)
		KEY_PERIOD: time_warp.change(1, rocket, planet)
		KEY_Z: rocket.throttle = 1.0
		KEY_X: rocket.throttle = 0.0
		KEY_SPACE: stage()
		KEY_T: rocket.controller.set_mode(AttitudeController.Mode.OFF, rocket.orientation)
		KEY_H: rocket.controller.set_mode(AttitudeController.Mode.HOLD, rocket.orientation)
		KEY_P: rocket.controller.set_mode(AttitudeController.Mode.PROGRADE, rocket.orientation)
		KEY_R: rocket.controller.set_mode(AttitudeController.Mode.RETROGRADE, rocket.orientation)
		KEY_1: rocket.controller.set_mode(AttitudeController.Mode.RADIAL_OUT, rocket.orientation)
		KEY_2: rocket.controller.set_mode(AttitudeController.Mode.RADIAL_IN, rocket.orientation)
		KEY_3: rocket.controller.set_mode(AttitudeController.Mode.NORMAL, rocket.orientation)
		KEY_4: rocket.controller.set_mode(AttitudeController.Mode.ANTINORMAL, rocket.orientation)

func toggle_map() -> void:
	if menu:
		return
	map_active = not map_active
	hud.visible = not map_active
	camera.dragging = false
	if map_active:
		orbit_map.open(rocket, planet, time_warp)
	else:
		orbit_map.close()

func _physics_process(_delta: float) -> void:
	if menu or paused:
		return
	var manual := Vector3(Input.get_axis("yaw_left", "yaw_right"), Input.get_axis("roll_right", "roll_left"), Input.get_axis("pitch_up", "pitch_down"))
	var throttle_input: float = Input.get_axis("throttle_down", "throttle_up")
	time_warp.enforce(rocket, planet, manual, throttle_input)
	rocket.throttle = clampf(rocket.throttle + throttle_input * 0.5 / 60.0, 0, 1)
	if time_warp.is_coasting():
		var coast_dt: float = time_warp.rate() / 60.0
		if KeplerCoast.advance(rocket, planet, coast_dt):
			rocket.elapsed += coast_dt
			rocket.thrust = 0.0
			advance_debris(coast_dt)
			return
		time_warp.reset("Coast solver fallback: normal speed")
	for substep in range(2 * time_warp.rate()):
		rocket.step(SUBSTEP, planet, manual)
		advance_debris(SUBSTEP)
		if rocket.crashed:
			time_warp.reset()
			break

func advance_debris(duration: float) -> void:
	for body in debris:
		if body.crashed:
			continue
		if duration > SUBSTEP and TimeWarp.vacuum_interval_safe(body, planet, duration):
			if KeplerCoast.advance(body, planet, duration):
				continue
		var remaining: float = duration
		while remaining > 1.0e-9 and not body.crashed:
			var dt: float = minf(SUBSTEP, remaining)
			body.sample_atmosphere(planet)
			body.integrate_attitude(Vector3.ZERO, dt)
			body.integrate(dt, planet, DVec3.new())
			body.crashed = body.position.length() < planet.radius
			remaining -= dt

func _process(delta: float) -> void:
	if rocket == null:
		return
	var render_size := Vector2i(get_viewport().get_visible_rect().size)
	if foreground.size != render_size:
		foreground.size = render_size
	rocket_visual.quaternion = rocket_visual.quaternion.slerp(rocket.orientation, 1.0 - exp(-delta * 28.0))
	rocket_visual.update_exhaust(rocket.thrust, rocket.current_stage().definition.engine.vacuum_thrust, rocket.elapsed)
	atmospheric_fx.update_effects(rocket, delta * mini(time_warp.rate(), 4), not paused and not menu)
	camera.follow(rocket.position.unit().vec(), delta, menu)
	world.update_world(rocket, camera)
	if map_active:
		orbit_map.update_map(delta, paused)
	for i in range(debris.size() - 1, -1, -1):
		debris_visuals[i].position = debris[i].position.minus(rocket.position).vec()
		debris_visuals[i].quaternion = debris[i].orientation
		if debris_visuals[i].position.length() > 200000.0 or debris[i].crashed:
			debris_visuals[i].queue_free()
			debris_visuals.remove_at(i)
			debris.remove_at(i)
	ui_clock += delta
	if ui_clock > 0.05:
		ui_clock = 0.0
		hud.update_display(rocket, planet, FlightComputer.read(rocket, planet), menu)

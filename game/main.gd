extends Node3D

const SUBSTEP: float = 1.0 / 120.0
var planet: PlanetDefinition = preload("res://data/aster.tres")
var vehicle: CraftDesign = CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
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
var session: FlightSession
var visual_revision: int = -1
var inspector := PartInspector.new()
var flight_audio := FlightAudio.new()
var failure_fx := FailureFX.new()
var assembly := AssemblyEditor.new()
var water_fx := WaterFX.new()
var station_ops := StationOperations.new()
var menu_preview: RocketState
var target_camera: int = 0

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
	foreground.add_child(failure_fx)
	foreground.add_child(water_fx)
	add_child(flight_audio)
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
	layer.add_child(inspector)
	var operations_layer := CanvasLayer.new(); operations_layer.layer = 4; add_child(operations_layer); operations_layer.add_child(station_ops)
	station_ops.camera = camera
	station_ops.scenario_requested.connect(load_scenario)
	station_ops.switch_requested.connect(func(uid): if session.switch_vessel(uid): adopt_active())
	station_ops.save_requested.connect(save_flight)
	station_ops.load_requested.connect(load_flight)
	station_ops.assembly_requested.connect(func(): hud.visible = false; assembly.open(vehicle))
	var map_layer := CanvasLayer.new()
	map_layer.layer = 3
	add_child(map_layer)
	map_layer.add_child(orbit_map)
	var assembly_layer := CanvasLayer.new(); assembly_layer.layer = 5; add_child(assembly_layer); assembly_layer.add_child(assembly)
	assembly.launch_requested.connect(func(craft): vehicle = craft; assembly.close(); launch_vehicle())
	assembly.exit_requested.connect(func(): assembly.close(); return_to_menu())
	hud.build_requested.connect(func(): hud.visible = false; assembly.open(vehicle))
	hud.vehicle_selected.connect(func(path):
		vehicle = CraftCodec.load_craft(path)
		if session != null and session.campaign_mode: menu_preview = RocketState.new(vehicle,planet)
		else: reset_flight(true))
	orbit_map.flight_requested.connect(toggle_map)
	hud.map_requested.connect(toggle_map)
	hud.warp = time_warp
	hud.launch_requested.connect(launch_vehicle)
	hud.restart_requested.connect(launch_vehicle)
	hud.menu_requested.connect(return_to_menu)
	hud.quit_requested.connect(get_tree().quit)
	hud.sas_requested.connect(func(mode: int):
		if time_warp.is_coasting():
			time_warp.reset("Attitude input: normal speed")
		rocket.controller.set_mode(mode as AttitudeController.Mode, rocket.orientation))
	reset_flight(true)
	if "--aors-smoke" in OS.get_cmdline_user_args(): load_scenario("res://data/scenarios/aors_complete_orbit.json")
	if "--docking-smoke" in OS.get_cmdline_user_args(): load_scenario("res://data/scenarios/aors_docking_test.json")
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
		"roll_left": KEY_Q, "roll_right": KEY_E, "throttle_up": KEY_SHIFT, "throttle_down": KEY_CTRL,
		"rcs_forward":KEY_I,"rcs_backward":KEY_K,"rcs_left":KEY_J,"rcs_right":KEY_L,"rcs_up":KEY_U,"rcs_down":KEY_O}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

func reset_flight(to_menu: bool) -> void:
	menu_preview = null
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
	session = FlightSession.new(rocket,planet)
	orbit_map.session = session
	inspector.session = session; inspector.camera = camera; inspector.selected_id = ""
	time_warp.reset()
	failure_fx.reset_effects(); water_fx.reset_effects()
	atmospheric_fx.heat = 0.0
	atmospheric_fx.drag = 0.0
	atmospheric_fx.visible = false
	rocket_visual.rebuild(rocket)
	visual_revision = rocket.topology_revision
	menu = to_menu
	paused = false
	hud.paused = false
	hud.help = false
	camera.distance = 62.0
	camera.smooth_distance = 62.0
	camera.smooth_up = Vector3.UP
	camera.azimuth = 0.55
	camera.elevation = 0.18

func return_to_menu() -> void:
	if session != null and session.campaign_mode:
		menu = true; map_active = false; orbit_map.close(); hud.visible = true
		menu_preview = RocketState.new(vehicle,planet)
	else: reset_flight(true)

func launch_vehicle() -> void:
	if session == null or not session.campaign_mode: reset_flight(false); return
	var craft := RocketState.new(vehicle,planet)
	craft.elapsed = session.time
	var angle: float = planet.rotation_rate*craft.elapsed
	craft.orientation = Quaternion(Vector3.BACK,angle)
	craft.position = DVec3.new(-sin(angle)*craft.pad_origin_radius,cos(angle)*craft.pad_origin_radius,0).plus(craft.properties.center.rotated(craft.orientation))
	craft.velocity = PlanetPhysics.air_velocity(craft.position,planet)
	craft.controller.target = craft.orientation
	session.registry.register(craft); session.update_reference(craft); session.active = craft
	menu = false; paused = false; menu_preview = null; hud.visible = true; map_active = false; orbit_map.close()
	adopt_active()

func adopt_active() -> void:
	orbit_map.session = session
	for visual in debris_visuals: visual.queue_free()
	debris.clear(); debris_visuals.clear()
	rocket = session.active; rocket_visual.rebuild(rocket); rocket_visual.quaternion = rocket.orientation; visual_revision = rocket.topology_revision
	inspector.session = session; inspector.selected_id = ""; time_warp.reset()
	camera.distance = maxf(45,(rocket.properties.maximum-rocket.properties.minimum).length()*2.1); camera.smooth_distance = camera.distance
	if map_active: orbit_map.initialized_view = false; orbit_map.open(rocket,rocket.reference_body,time_warp)
	station_ops.signature = ""

func load_scenario(path: String) -> void:
	var loaded := OrbitalScenario.load_session(path,planet)
	if loaded == null: station_ops.message = "Scenario could not be loaded"; return
	session = loaded; menu = false; paused = false; menu_preview = null; map_active = false; orbit_map.close(); hud.visible = true
	adopt_active()
	station_ops.message = "Prebuilt scenario / station is initialized in orbit"

func save_flight() -> void:
	station_ops.message = "Flight saved" if FlightSave.save(session) == OK else "Could not save flight"

func load_flight() -> void:
	var loaded := FlightSave.load_session("user://saves/quicksave.json",planet)
	if loaded == null: station_ops.message = "No valid quicksave; current flight kept"; return
	session = loaded; menu = false; paused = false; menu_preview = null; map_active = false; orbit_map.close(); hud.visible = true
	adopt_active(); station_ops.message = "Flight restored"

func stage() -> void:
	rocket.activate_stage()
	for dropped in session.registry.collect_splits():
		flight_audio.burst = 0.3
		debris.append(dropped)
		var visual := RocketVisual.new()
		foreground.add_child(visual)
		visual.rebuild(dropped)
		debris_visuals.append(visual)
		rocket_visual.rebuild(rocket)

func _unhandled_input(event: InputEvent) -> void:
	if assembly.visible:
		assembly.handle_input(event)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not menu and not map_active:
		inspector.pick(event.position)
	if map_active:
		orbit_map.handle(event)
	else:
		camera.handle(event)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F9: load_flight(); return
	if event.keycode == KEY_F5: save_flight(); return
	if event.keycode == KEY_F6 and not menu:
		session.cycle_vessel(-1 if event.shift_pressed else 1); adopt_active(); return
	if event.keycode == KEY_F7: station_ops.show_list = not station_ops.show_list; return
	if event.keycode == KEY_ENTER and menu:
		launch_vehicle()
	if menu:
		return
	if event.keycode == KEY_M:
		toggle_map()
		return
	match event.keycode:
		KEY_C: target_camera = (target_camera+1)%3
		KEY_V:
			rocket.rcs_enabled = not rocket.rcs_enabled; time_warp.reset()
		KEY_N: rocket.docking_armed = not rocket.docking_armed
		KEY_G:
			session.docking.undock(session,rocket); adopt_active()
		KEY_ESCAPE:
			paused = not paused
			hud.paused = paused
		KEY_F1: hud.help = not hud.help
		KEY_F3: hud.debug = not hud.debug
		KEY_F4: inspector.show_stress = not inspector.show_stress
		KEY_I: inspector.selected_id = ""
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
	if menu or paused or assembly.visible:
		return
	var manual := Vector3(Input.get_axis("yaw_left", "yaw_right"), Input.get_axis("roll_right", "roll_left"), Input.get_axis("pitch_up", "pitch_down"))
	var throttle_input: float = Input.get_axis("throttle_down", "throttle_up")
	rocket.rcs_command = Vector3(Input.get_axis("rcs_left","rcs_right"),Input.get_axis("rcs_backward","rcs_forward"),Input.get_axis("rcs_down","rcs_up"))
	if rocket.rcs_enabled and rocket.rcs_command.length_squared() > 0 and time_warp.is_coasting(): time_warp.reset("RCS input")
	while time_warp.rate() > session.maximum_proximity_warp(): time_warp.change(-1,rocket,rocket.reference_body)
	time_warp.enforce(rocket, planet, manual, throttle_input)
	rocket.throttle = clampf(rocket.throttle + throttle_input * 0.5 / 60.0, 0, 1)
	if time_warp.is_coasting():
		var coast_dt: float = time_warp.rate() / 60.0
		if session.coast(coast_dt):
			return
		time_warp.reset("Coast solver fallback: normal speed")
	for substep in range(2 * time_warp.rate()):
		session.step(SUBSTEP, manual)
		if rocket.crashed:
			time_warp.reset()

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
	session.registry.collect_splits()
	if rocket != session.active: adopt_active()
	for i in range(debris.size()-1,-1,-1):
		if not debris[i] in session.registry.bodies: debris_visuals[i].queue_free(); debris_visuals.remove_at(i); debris.remove_at(i)
	if visual_revision != rocket.topology_revision:
		rocket_visual.rebuild(rocket)
		visual_revision = rocket.topology_revision
	for body: RocketState in session.registry.bodies:
		if body == rocket or body in debris: continue
		debris.append(body)
		var fragment_visual := RocketVisual.new()
		foreground.add_child(fragment_visual)
		fragment_visual.rebuild(body)
		debris_visuals.append(fragment_visual)
	var render_size := Vector2i(get_viewport().get_visible_rect().size)
	if foreground.size != render_size:
		foreground.size = render_size
	rocket_visual.quaternion = rocket_visual.quaternion.slerp(rocket.orientation, 1.0 - exp(-delta * 28.0))
	rocket_visual.update_exhaust(rocket.thrust, rocket.current_stage().definition.engine.vacuum_thrust, rocket.elapsed)
	atmospheric_fx.update_effects(rocket, delta * mini(time_warp.rate(), 4), not paused and not menu)
	camera.focus_offset = Vector3.ZERO
	var target_body := session.vessel(session.target_uid)
	if target_camera > 0 and target_body != null and target_body != rocket and not menu:
		var offset := target_body.position.minus(rocket.position)
		if target_camera == 1:
			camera.focus_offset = offset.scaled(0.5).vec(); camera.distance = maxf(80,offset.length()*0.85+target_body.radius*2)
		elif target_body.graph.parts.has(session.target_port_id):
			camera.focus_offset = DockingSystem.frame(target_body,target_body.graph.parts[session.target_port_id]).position.minus(rocket.position).vec()
	camera.follow(rocket.relative_position().unit().vec(), delta, menu)
	world.update_world(rocket, camera)
	inspector.visible = not menu and not map_active
	inspector.queue_redraw()
	flight_audio.update_audio(rocket,not menu and not paused)
	for body: RocketState in session.registry.bodies:
		for event in body.events:
			failure_fx.emit_event(event)
			flight_audio.burst = maxf(flight_audio.burst,0.2 if event.type == "break" else 0.7)
		body.events.clear()
	failure_fx.update_effects(rocket.position,0.0 if paused else delta*mini(time_warp.rate(),4))
	water_fx.update_water(rocket,rocket.reference_body,0.0 if paused or menu else delta*mini(time_warp.rate(),4))
	if map_active:
		orbit_map.update_map(delta, paused)
	for i in range(debris.size() - 1, -1, -1):
		debris_visuals[i].position = debris[i].position.minus(rocket.position).vec()
		debris_visuals[i].quaternion = debris[i].orientation
		if debris_visuals[i] is RocketVisual:
			if debris_visuals[i].built_revision != debris[i].topology_revision: debris_visuals[i].rebuild(debris[i])
			debris_visuals[i].update_exhaust(debris[i].thrust,1,debris[i].elapsed)
		debris_visuals[i].visible = debris_visuals[i].position.length() < 75000
		if debris_visuals[i].position.length() > 200000.0 and debris[i].lifecycle == "DEBRIS":
			session.registry.bodies.erase(debris[i])
			debris_visuals[i].queue_free()
			debris_visuals.remove_at(i)
			debris.remove_at(i)
	ui_clock += delta
	if ui_clock > 0.05:
		ui_clock = 0.0
		var display := menu_preview if menu and menu_preview != null else rocket
		hud.update_display(display, display.reference_body, FlightComputer.read(display, display.reference_body), menu)
		station_ops.visible = not assembly.visible
		station_ops.update_display(session,menu,map_active)

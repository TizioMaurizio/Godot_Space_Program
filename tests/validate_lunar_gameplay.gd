extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1
func capture(name: String) -> void:
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/"+name+".png")
func run() -> void:
	var game = load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_physics_process(false); game.reset_flight(false)
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	var moon: CelestialBodyDefinition = game.session.celestial.moons[0]
	var frame: Dictionary = game.session.celestial.ephemeris(moon,0)
	game.rocket.on_pad = false; game.rocket.activate_stage(); game.stage()
	game.rocket.position = frame.position.plus(DVec3.new(0,moon.radius+30000,0))
	game.rocket.velocity = frame.velocity.plus(DVec3.new(-sqrt(moon.mu()/(moon.radius+30000)),0,0))
	game.session.update_reference(game.rocket)
	game.camera.elevation = 0.9; game.camera.distance = 45; game.camera.smooth_distance = 45
	await capture("26_neris_orbit_flight")
	check(game.rocket.reference_body == moon and game.world.terrain_renderer.planet == moon,"flight view uses Neris terrain/reference body")
	check(game.world.moon_meshes.size() == 1 and game.world.layers.planet == game.planet,"Neris and Aster coexist in distant rendering")
	game.toggle_map(); await capture("27_neris_map")
	check(game.orbit_map.planet == moon and game.orbit_map.prediction.orbit.stable,"map reports a physical Moon-relative orbit")
	game.toggle_map()
	game.rocket.position = frame.position.plus(DVec3.new(0,moon.radius+SurfaceQuery.height(moon,DVec3.new(0,1,0),0)+30,0))
	game.camera.elevation = 0.15; game.camera.distance = 85
	await capture("28_neris_terrain")
	check(game.world.sky_material.get_shader_parameter("air") == 0.0,"lunar surface has no atmospheric sky")
	# A separate low-altitude landing fixture, using real engine and contact steps.
	game.vehicle = CraftCodec.load_craft("res://data/craft/neris_explorer.json"); game.reset_flight(false)
	game.rocket.on_pad = false; game.stage(); game.stage(); game.stage()
	moon = game.session.celestial.moons[0]; frame = game.session.celestial.ephemeris(moon,0)
	var start := DVec3.new(0,moon.radius+SurfaceQuery.height(moon,DVec3.new(0,1,0),0)+120,0)
	game.rocket.position = frame.position.plus(start)
	game.rocket.velocity = frame.velocity.plus(PlanetPhysics.air_velocity(start,moon)).plus(DVec3.new(0,-3,0))
	game.session.update_reference(game.rocket)
	game.camera.distance = 55; game.camera.smooth_distance = 55; game.camera.elevation = 0.2
	var landed: bool = false
	for i in range(120*180):
		var p: DVec3 = game.rocket.relative_position(); var up := p.unit()
		var height: float = p.length()-moon.radius-SurfaceQuery.height(moon,p,game.rocket.elapsed)-(game.rocket.properties.center.y-game.rocket.properties.minimum.y)
		var vertical: float = game.rocket.relative_velocity().minus(PlanetPhysics.air_velocity(p,moon)).dot(up)
		var accel: float = moon.mu()/p.length_squared()+(-clampf(height*0.12,0.3,8)-vertical)*0.8
		game.rocket.controller.target = AttitudeController.pointing(up.vec(),game.rocket.orientation)
		game.rocket.throttle = clampf(game.rocket.mass*accel/100000,0,1)
		game.session.step(1.0/120,Vector3.ZERO)
		if i%24 == 0: await process_frame
		if game.rocket.contacting: landed = true; break
		if game.rocket.crashed: break
	game.rocket.throttle = 0
	for i in range(120*10):
		game.session.step(1.0/120,Vector3.ZERO)
		if i%24 == 0: await process_frame
	check(landed and not game.rocket.crashed and game.rocket.graph.parts.size() == 8,"rendered powered landing preserves all eight Explorer parts")
	print("RENDER LANDING landed=%s crashed=%s parts=%s t=%.2f h=%.3f speed=%.3f"%[landed,game.rocket.crashed,game.rocket.graph.parts.keys(),game.rocket.elapsed,game.rocket.relative_position().length()-moon.radius,game.rocket.relative_velocity().length()])
	await capture("29_neris_landed")
	print("RESULT: %d failures"%failures)
	game.set_process(false); game.world.background.render_target_update_mode = SubViewport.UPDATE_DISABLED; game.foreground.render_target_update_mode = SubViewport.UPDATE_DISABLED; game.orbit_map.close()
	for i in range(4): await process_frame
	RenderingServer.force_sync()
	game.queue_free()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw; RenderingServer.force_sync()
	call_deferred("quit",1 if failures else 0)

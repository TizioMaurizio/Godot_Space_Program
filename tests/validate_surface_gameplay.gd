extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/"+name+".png")
func run() -> void:
	var game = load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_physics_process(false); game.reset_flight(false)
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	for i in range(60): await process_frame
	check(game.world.terrain_renderer.tiles.size() > 20,"curved terrain LOD builds around launchpad")
	await capture("20_terrain_launchpad")
	var design := CraftDesign.new(); design.display_name = "Splashdown fixture"; design.root_part_id = "capsule"
	design.parts = [{"id":"capsule","definition_id":"command.capsule","position_m":[0,0,0],"rotation_xyzw":[0,0,0,1],"settings":{}}]
	game.vehicle = design; game.reset_flight(false)
	var ocean_up := DVec3.new(-1,1,1).unit()
	game.rocket.on_pad = false; game.rocket.position = ocean_up.scaled(game.planet.radius+5)
	game.rocket.velocity = PlanetPhysics.air_velocity(game.rocket.position,game.planet).minus(ocean_up.scaled(4))
	game.rocket.orientation = AttitudeController.pointing(ocean_up.vec(),Quaternion.IDENTITY); game.rocket.controller.set_mode(AttitudeController.Mode.OFF,game.rocket.orientation)
	game.camera.distance = 18; game.camera.smooth_distance = 18; game.camera.elevation = 0.12
	for i in range(600):
		game._physics_process(1.0/60)
		if i%3 == 0: await process_frame
	check(game.rocket.water_contact and not game.rocket.crashed,"rendered capsule floats on physical planetary water")
	check(game.water_fx.particles.size() > 0,"wet parts produce surface foam and wake particles")
	await capture("21_capsule_splashdown")
	game.camera.elevation = -0.35
	for i in range(45): await process_frame
	check(game.world.underwater,"camera crossing water activates underwater fog")
	await capture("22_underwater")
	print("RESULT: %d failures"%failures)
	game.set_process(false)
	game.world.background.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.foreground.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for i in range(4): await process_frame
	RenderingServer.force_sync()
	game.queue_free()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_sync()
	quit(1 if failures else 0)

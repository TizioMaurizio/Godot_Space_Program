extends SceneTree
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1

func run() -> void:
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var weak := CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
	weak.connections[3].strength = 50.0
	game.vehicle = weak; game.reset_flight(false)
	game.rocket.on_pad = false
	game.rocket.position = DVec3.new(0,game.planet.radius+12000,0)
	game.rocket.velocity = DVec3.new(-500,600,0)
	game.rocket.orientation = Quaternion(Vector3.BACK,0.4)
	game.rocket.controller.target = game.rocket.orientation
	game.rocket.throttle = 1
	game.stage()
	var powered_fragment: bool = false
	var subsequent_collision: bool = false
	for i in range(120):
		game._physics_process(1.0/60)
		for body in game.session.registry.bodies:
			if body != game.rocket and body.thrust > 0: powered_fragment = true
			for event in body.events:
				if powered_fragment and event.type == "impact": subsequent_collision = true
	for i in range(8): await process_frame
	check(game.session.registry.bodies.size() > 1,"measured structural overload splits the live flight graph")
	var count: int = 0
	for body in game.session.registry.bodies:
		count += body.graph.parts.size()
	check(count == 6,"all original parts remain present after structural breakup")
	check(powered_fragment,"detached engine/tank assembly retains active propulsion")
	check(subsequent_collision,"powered debris can subsequently collide with the upper assembly")
	for body in game.session.registry.bodies:
		if body.graph.parts.size() == 1 and body.graph.parts.has("booster_engine"):
			check(body.graph.parts.booster_engine.modules.engine.active and body.thrust == 0,"collision-isolated engine stays ignited but cannot thrust without a connected tank")
	check(game.debris.size() > 0,"nearby structural fragments are rendered and retained")
	game.inspector.show_stress = true
	game.inspector.selected_id = "capsule"
	game.camera.distance = 110
	for i in range(12): await process_frame
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/17_structural_breakup.png")
	print("RESULT: %d failures" % failures)
	game.set_process(false)
	game.world.background.render_target_update_mode = SubViewport.UPDATE_DISABLED; game.foreground.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for i in range(4): await process_frame
	RenderingServer.force_sync()
	game.queue_free()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw; RenderingServer.force_sync()
	call_deferred("quit",1 if failures else 0)

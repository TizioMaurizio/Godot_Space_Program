extends SceneTree
## Short release playtest: real scene, preset, switching, capture, save/load and screenshots.
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func capture(name: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/"+name+".png")
func run() -> void:
	var game = load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	game.load_scenario("res://data/scenarios/aors_complete_orbit.json")
	for i in range(12): game._physics_process(1.0/60)
	game.camera.elevation = 0.3; game.camera.azimuth = 0.4
	check(game.rocket.graph.parts.size() == 44 and not game.menu,"station scenario is playable with 44 physical parts")
	check(game.rocket.power.generation > 140000,"sun-facing eight-wing station generates power")
	await capture("30_aors_station")
	game.load_scenario("res://data/scenarios/aors_docking_test.json"); game.target_camera = 1
	for i in range(12): game._physics_process(1.0/60)
	check(game.session.target_metrics().range > 500 and game.session.registry.bodies.size() == 2,"nearby visitor and relative navigation are available")
	await capture("31_aors_rendezvous")
	game.session.switch_vessel("aors"); game.adopt_active(); game.toggle_map()
	await capture("32_aors_map")
	check(game.orbit_map.session == game.session,"map shares persistent vessel registry")
	game.toggle_map(); game.session.switch_vessel("docking-tug"); game.adopt_active()
	var station: RocketState = game.session.vessel("aors"); var tug: RocketState = game.rocket
	var target: PartInstance = station.graph.parts["dock-aft"]; var source: PartInstance = tug.graph.parts["tug-dock"]
	var f := DockingSystem.frame(station,target)
	tug.orientation = station.orientation; tug.controller.set_mode(AttitudeController.Mode.OFF,tug.orientation)
	tug.position = f.position.plus(f.axis.scaled(0.055)).minus(source.node_position("dock").minus(tug.properties.center).rotated(tug.orientation))
	tug.velocity = station.velocity; tug.angular_velocity = Vector3.ZERO
	# Explicit near-port fixture; subsequent soft/hard capture uses actual forces.
	for i in range(600):
		game._physics_process(1.0/60)
		if i%6 == 0: await process_frame
		if game.session.registry.bodies.size() == 1: break
	check(game.session.registry.bodies.size() == 1 and game.session.active.graph.parts.size() == 50,"physical spring capture joins the station and visiting craft")
	game.save_flight(); game.load_flight()
	check(game.session.registry.bodies.size() == 1 and game.rocket.graph.parts.size() == 50,"quicksave restores actual docked graph")
	game.target_camera = 0; game.camera.distance = 280; game.camera.elevation = 0.2
	await capture("33_aors_docked")
	check(game.session.docking.undock(game.session,game.rocket),"player can undock using the existing graph splitter")
	game.set_process(false); game.world.background.render_target_update_mode = SubViewport.UPDATE_DISABLED; game.foreground.render_target_update_mode = SubViewport.UPDATE_DISABLED; game.orbit_map.close()
	for i in range(4): await process_frame
	RenderingServer.force_sync(); game.queue_free()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw; RenderingServer.force_sync()
	print("RESULT %d failures"%failures); call_deferred("quit",1 if failures else 0)

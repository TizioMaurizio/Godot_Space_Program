extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1
func capture(name: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/"+name+".png")
func run() -> void:
	var game = load("res://game/main.tscn").instantiate(); root.add_child(game)
	await process_frame; game.set_physics_process(false); game.reset_flight(false)
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	var rho: float = PlanetPhysics.density(15000,game.planet.atmosphere)
	game.rocket.on_pad = false; game.rocket.position = DVec3.new(0,game.planet.radius+180000,0)
	game.rocket.velocity = DVec3.new(-sqrt(game.planet.mu()/game.rocket.position.length()),0,0)
	game.toggle_map(); game.orbit_map.yaw = -0.5; game.orbit_map.pitch = 0.25
	await capture("23_aster_clouds_orbit")
	game.orbit_map.yaw = 2.25
	await capture("24_aster_night_lights")
	check(game.world.layers.shells.size() == 3 and game.orbit_map.layers.shells.size() == 3,"surface/orbit views share two cloud layers and atmospheric limb")
	game.toggle_map(); game.rocket.position = DVector.from_vec(Vector3(0.7,0.5,0).normalized()).scaled(game.planet.radius+500)
	game.camera.elevation = 0.06; game.camera.azimuth = -PI/2
	await capture("25_twilight_horizon")
	game.rocket.elapsed = 10000
	for i in range(4): await process_frame
	var material: ShaderMaterial = game.world.layers.shells[0].material_override
	check(absf(material.get_shader_parameter("cloud_phase")-0.15) < 1e-5,"cloud advection follows simulation time")
	check(PlanetPhysics.density(15000,game.planet.atmosphere) == rho,"render updates leave physical atmosphere unchanged")
	print("RESULT: %d failures"%failures)
	game.set_process(false); game.world.background.render_target_update_mode = SubViewport.UPDATE_DISABLED; game.foreground.render_target_update_mode = SubViewport.UPDATE_DISABLED; game.orbit_map.close()
	for i in range(4): await process_frame
	game.queue_free()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	quit(1 if failures else 0)

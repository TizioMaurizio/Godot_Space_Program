extends SceneTree
var failures: int = 0

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1

func single_part(id: String, planet: PlanetDefinition) -> RocketState:
	var design := CraftDesign.new()
	design.root_part_id = "test"
	design.parts = [{"id":"test","definition_id":id,"position_m":[0,0,0],"rotation_xyzw":[0,0,0,1]}]
	var body := RocketState.new(design,planet)
	body.on_pad = false; body.orientation = Quaternion(Vector3.BACK,-PI/2)
	body.controller.set_mode(AttitudeController.Mode.OFF,body.orientation)
	return body

func _initialize() -> void:
	var planet: PlanetDefinition = load("res://data/aster.tres")
	var sample := DVec3.new(1e8,2e8,-3e8)
	check(SurfaceQuery.to_inertial(SurfaceQuery.to_fixed(sample,planet,12345),planet,12345).minus(sample).length() < 1e-6,"body-fixed transform preserves double-precision coordinates")
	check(absf(SurfaceQuery.height_fixed(planet,DVec3.new(0,1,0))-120) < 1e-8,"launchpad site is a defined terrain plateau")
	check(SurfaceQuery.height_fixed(planet,DVec3.new(1,0,0)) < 0,"ocean test location has a submerged seabed")
	var tile := TerrainMesher.tile(planet,DVec3.new(0,1,0),DVec3.new(-1,0,0),DVec3.new(0,0,1),Vector2(-32,-32),64)
	var arrays: Array = tile.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var max_error: float = 0
	for i in range(16*16*6):
		var world: DVec3 = tile.anchor.plus(DVector.from_vec(vertices[i]))
		max_error = maxf(max_error,absf(world.length()-planet.radius-SurfaceQuery.height_fixed(planet,world.unit())))
	check(max_error < 0.01,"rendered terrain vertices match authoritative surface: %.8f m" % max_error)
	var water_world: PlanetDefinition = planet.duplicate(true)
	water_world.rotation_rate = 0
	water_world.terrain.style = "flat"; water_world.terrain.height_scale = -1000; water_world.terrain.launch_plateau = false
	water_world.ocean.wave_amplitude = 0
	var capsule := single_part("command.capsule",water_world)
	capsule.position = DVec3.new(water_world.radius+1.95,0,0); capsule.velocity = DVec3.new()
	capsule.angular_velocity = Vector3(0.03,0,0.02)
	for i in range(120*60): capsule.step(1.0/120,water_world)
	var expected: float = capsule.mass/(water_world.ocean.density*capsule.graph.parts.test.definition.volume())
	var actual: float = capsule.graph.parts.test.submerged
	check(not capsule.crashed and capsule.water_contact,"capsule survives water contact and remains floating")
	check(absf(actual-expected) < 0.02,"buoyant equilibrium matches displaced-volume fraction: %.4f expected %.4f" % [actual,expected])
	check(capsule.velocity.length() < 0.3,"floating craft settles relative to still water")
	var engine := single_part("engine.forge",water_world)
	engine.position = DVec3.new(water_world.radius-4,0,0); engine.velocity = DVec3.new()
	for i in range(120*8): engine.step(1.0/120,water_world)
	check(engine.position.length() < water_world.radius-8,"dense flooded engine section sinks")
	var fast := single_part("command.capsule",water_world)
	fast.position = DVec3.new(water_world.radius+1.99,0,0); fast.velocity = DVec3.new(-100,0,0)
	for i in range(120): fast.step(1.0/120,water_world)
	check(fast.crashed and fast.graph.parts.test.destroyed,"high-speed water impact destroys the capsule")
	check(is_finite(fast.velocity.length()) and fast.velocity.length() < 100,"implicit water drag remains finite and dissipative during hard impact")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

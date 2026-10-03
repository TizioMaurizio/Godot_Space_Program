extends SceneTree
var failures: int = 0
var planet: PlanetDefinition = load("res://data/aster.tres")

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1

func make_craft() -> RocketState:
	var d := CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
	d.aero_model = "parts"
	var craft := RocketState.new(d,planet)
	craft.on_pad = false
	craft.position = DVec3.new(0,planet.radius+100000,0)
	return craft

func _initialize() -> void:
	var craft := make_craft()
	craft.gravity = PlanetPhysics.gravity(craft.position,planet)
	craft.acceleration = craft.gravity
	var failed := craft.structure.evaluate(craft,Vector3.ZERO)
	check(failed.is_empty() and craft.structure.maximum_utilization < 1e-8,"uniform free fall produces zero structural stress")
	craft.acceleration = craft.gravity.plus(DVec3.new(0,20,0))
	failed = craft.structure.evaluate(craft,Vector3.ZERO)
	check(failed.is_empty() and craft.structure.maximum_utilization > 0,"rated joints survive a sub-rated inertial load")
	craft.acceleration = craft.gravity.plus(DVec3.new(10,0,0))
	craft.structure.evaluate(craft,Vector3(0,0.02,0.1))
	var mixed: Dictionary = craft.graph.connections[0].load
	check(mixed.shear > 0 and mixed.bending > 0 and absf(mixed.torsion) > 0,"solver distinguishes shear, bending and torsion")
	craft.acceleration = craft.gravity.plus(DVec3.new(0,20,0))
	craft.graph.connections[0].strength = 100
	failed = craft.structure.evaluate(craft,Vector3.ZERO)
	check("c1" in failed,"known weak axial connection fails above its rating")
	var m: float = craft.mass
	var pieces := craft.split_connections(failed)
	var total: float = craft.mass
	for p in pieces: total += p.mass
	check(pieces.size() >= 1 and absf(total-m) < 1e-6,"structural cut creates persistent mass-conserving bodies")
	var powered := make_craft()
	powered.position = DVec3.new(0,planet.radius+12000,0); powered.throttle = 1; powered.activate_stage()
	var detached: RocketState = powered.split_connections(["c4"])[0]
	var fuel_before: float = detached.graph.parts.booster_tank.modules.tank.resources.fuel
	for i in range(240): detached.step(1.0/120,planet)
	check(detached.thrust > 0 and detached.graph.parts.has("booster_tank") and detached.graph.parts.booster_engine.modules.engine.active and detached.graph.parts.booster_tank.modules.tank.resources.fuel < fuel_before,"isolated detached engine/tank continues real powered flight for two seconds")
	craft = make_craft()
	craft.position = DVec3.new(0,planet.radius+10000,0)
	craft.velocity = PlanetPhysics.air_velocity(craft.position,planet).plus(DVec3.new(0,500,0))
	craft.sample_atmosphere(planet)
	check(craft.graph.parts.upper_tank.shielding < craft.graph.parts.capsule.shielding,"upstream capsule shields downstream tank frontal drag")
	var sum_force := DVec3.new()
	for part: PartInstance in craft.graph.parts.values(): sum_force = sum_force.plus(part.aero_force)
	check(sum_force.rotated(craft.orientation).minus(craft.drag_force).length() < 1e-6,"vehicle aerodynamic force equals individual part forces")
	craft.orientation = Quaternion(Vector3.BACK,0.4)
	craft.sample_atmosphere(planet)
	check(craft.aerodynamic_torque.length() > 1000,"part pressure centres produce a real moment")
	var capsule_design := CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
	capsule_design.parts = [capsule_design.parts[0]]
	capsule_design.connections = []; capsule_design.stages = []
	capsule_design.aero_model = "parts"
	var gentle := RocketState.new(capsule_design,planet)
	gentle.on_pad = false; gentle.position = DVec3.new(0,planet.radius+SurfaceQuery.height(planet,DVec3.new(0,1,0),0)+1.99,0)
	gentle.velocity = PlanetPhysics.air_velocity(gentle.position,planet).plus(DVec3.new(0,-2,0))
	ContactSolver.solve(gentle,planet,1.0/120)
	check(not gentle.crashed and gentle.contacting and gentle.last_contact_part == "capsule","gentle contact survives and identifies the contacted part")
	gentle.position = DVec3.new(0,planet.radius+100000,0)
	gentle.step(1.0/120,planet)
	check(gentle.graph.parts.capsule.force.length_squared() == 0,"contact impulse force is cleared on the following free-flight step")
	var hard := RocketState.new(capsule_design,planet)
	hard.on_pad = false; hard.position = DVec3.new(0,planet.radius+SurfaceQuery.height(planet,DVec3.new(0,1,0),0)+1.99,0)
	hard.velocity = DVec3.new(0,-100,0)
	ContactSolver.solve(hard,planet,1.0/120)
	check(hard.crashed and hard.graph.parts.capsule.destroyed and not hard.events.is_empty(),"high specific impact energy destroys command capability but retains wreck")
	check(hard.graph.parts.size() == 1 and hard.simulation_active,"destroyed part remains a simulated physical entity")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

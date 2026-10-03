extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1
func _initialize() -> void:
	var home: PlanetDefinition = load("res://data/aster.tres")
	var design := CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
	var entries: Array = [design.parts[1].duplicate(true),design.parts[2].duplicate(true),design.parts[2].duplicate(true)]
	entries[2].id = "second_engine"
	var graph := PartGraph.new(entries,[{"id":"a","a":["upper_tank","bottom"],"b":["upper_engine","top"]},{"id":"b","a":["upper_tank","top"],"b":["second_engine","top"]}],"upper_tank")
	graph.parts.upper_tank.modules.tank.resources = {"fuel":0.1,"oxidizer":0.2}
	graph.parts.upper_engine.modules.engine.active = true; graph.parts.second_engine.modules.engine.active = true
	var network := FuelNetwork.new(); var used := network.burn(graph,1,0,1)
	var first: float = graph.parts.upper_engine.modules.engine.thrust; var second: float = graph.parts.second_engine.modules.engine.thrust
	check(absf(first-second) < 1e-9 and absf(used.upper_tank-0.3) < 1e-10,"two engines share a scarce tank without creation or ordering preference")
	check(absf(first*2-0.3*360*EngineDefinition.G0) < 1e-8,"thrust impulse equals actual exhausted propellant momentum")
	graph.parts.upper_tank.modules.tank.resources = {"fuel":10.0,"oxidizer":0.0}
	network.burn(graph,1,0,1)
	check(graph.parts.upper_engine.modules.engine.thrust == 0 and graph.parts.upper_tank.modules.tank.resources.fuel == 10,"missing oxidizer prevents thrust and unilateral fuel consumption")
	var chute_design := CraftDesign.new(); chute_design.root_part_id = "chute"
	chute_design.parts = [{"id":"chute","definition_id":"utility.parachute","position_m":[0,0,0],"rotation_xyzw":[0,0,0,1]}]
	var chute := RocketState.new(chute_design,home); chute.on_pad = false; chute.position = DVec3.new(0,home.radius+3000,0)
	chute.velocity = PlanetPhysics.air_velocity(chute.position,home).plus(DVec3.new(0,-30,0))
	chute.sample_atmosphere(home); var stowed: float = chute.drag_force.length()
	chute.graph.parts.chute.modules.parachute.deployed = true
	for i in range(120): chute.step(1.0/120,home)
	check(chute.graph.parts.chute.modules.parachute.deployment_fraction > 0.49 and not chute.graph.parts.chute.modules.parachute.failed,"safe parachute inflation takes simulated time")
	chute.velocity = PlanetPhysics.air_velocity(chute.position,home).plus(DVec3.new(0,-30,0)); chute.sample_atmosphere(home)
	check(chute.drag_force.length() > stowed*10,"deployed parachute contributes real drag area")
	chute.dynamic_pressure = 20000; chute.step(1.0/120,home)
	check(chute.graph.parts.chute.modules.parachute.failed and not chute.graph.parts.chute.modules.parachute.deployed,"over-pressure deployment tears the chute deterministically")
	var disabled := design.copy(); disabled.parts[0].settings = {"wheel_enabled":false}
	check(RocketState.new(disabled,home).control_torque_limit() == 0,"disabled reaction wheel supplies no control torque")
	var malformed := design.to_data(); malformed.parts[0].rotation_xyzw = "bad"
	check(not CraftCodec.validate(CraftCodec.from_data(malformed)).is_empty(),"malformed transform is rejected without runtime indexing")
	malformed = design.to_data(); malformed.stages = ["bad"]
	check(not CraftCodec.validate(CraftCodec.from_data(malformed)).is_empty(),"malformed stage is rejected without runtime indexing")
	print("RESULT: %d failures"%failures)
	call_deferred("quit",1 if failures else 0)

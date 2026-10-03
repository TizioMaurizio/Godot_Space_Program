extends SceneTree

var failures: int = 0
var planet: PlanetDefinition = load("res://data/aster.tres")
var legacy: VehicleDefinition = load("res://data/orbital_test_vehicle.tres")

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1

func angular_momentum(body: RocketState, origin: DVec3) -> DVec3:
	return body.properties.tensor.multiply(DVector.from_vec(body.angular_velocity)).rotated(body.orientation).plus(body.position.minus(origin).cross(body.velocity.scaled(body.mass)))

func _initialize() -> void:
	var design := CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
	check(design != null and design.parts.size() == 6,"six-part OTV recipe validates")
	var craft := RocketState.new(design,planet)
	check(absf(craft.mass-29000) < 1e-6 and absf(craft.properties.dry-6000) < 1e-6,"actual part masses total 29000 kg wet / 6000 kg dry")
	check(absf(craft.length-26) < 1e-6,"actual part bounds retain 26 m length")
	var tensor := SymmetricTensor.new(10,20,30,2,3,4)
	var vector := DVec3.new(1.5,-2,3)
	check(tensor.solve(tensor.multiply(vector)).minus(vector).length() < 1e-10,"full off-diagonal tensor solve is consistent")
	var centroid: float = (5700*(-5.25)+300*(-9.25)+100*(-10.25)+20500*(-16.25)+900*(-23))/29000.0
	check(absf(craft.properties.center.y-centroid) < 1e-8,"COM agrees with independently weighted part positions")
	var before_com: float = craft.properties.center.y
	var upper_before: float = craft.graph.parts.upper_tank.modules.tank.resource_mass()
	craft.activate_stage(); craft.throttle = 1
	for i in range(120): craft.step(1.0/120,planet)
	check(craft.mass < 29000 and craft.properties.center.y != before_com,"burn reduces mass and changes actual COM")
	check(craft.graph.parts.upper_tank.modules.tank.resource_mass() == upper_before,"closed interstage prevents booster draining upper tank")
	check(craft.thrust > 470000 and craft.thrust < 540000,"part engine retains sea-level pressure-dependent thrust")
	var analysis := CraftAnalysis.analyze(design)
	check(absf(analysis.delta_v-legacy.vacuum_delta_v()) < 1e-6,"action-based delta-v estimate matches original rocket equation")
	craft = RocketState.new(design,planet)
	craft.on_pad = false; craft.position = DVec3.new(1000,2000,3000)
	craft.velocity = DVec3.new(100,200,300)
	craft.angular_velocity = Vector3(0.1,0.2,0.3)
	var original_origin := craft.position
	var p0 := craft.velocity.scaled(craft.mass)
	var l0 := angular_momentum(craft,original_origin)
	var positions: Dictionary = {}
	for part: PartInstance in craft.graph.parts.values(): positions[part.id] = craft.part_world_position(part)
	var pieces := craft.split_connections(["c3"])
	check(pieces.size() == 1 and craft.graph.parts.size() == 3 and pieces[0].graph.parts.size() == 3,"one cut partitions six real parts into the expected components")
	var p1 := craft.velocity.scaled(craft.mass).plus(pieces[0].velocity.scaled(pieces[0].mass))
	var l1 := angular_momentum(craft,original_origin).plus(angular_momentum(pieces[0],original_origin))
	check(p1.minus(p0).length()/p0.length() < 1e-8,"spinning separation conserves linear momentum")
	check(l1.minus(l0).length()/l0.length() < 1e-8,"spinning separation conserves angular momentum about common origin")
	var max_shift: float = 0
	for body in [craft,pieces[0]]:
		for part: PartInstance in body.graph.parts.values(): max_shift = maxf(max_shift,positions[part.id].minus(body.part_world_position(part)).length())
	check(max_shift < 1e-5,"graph split preserves every part's world position")
	check(absf(craft.mass+pieces[0].mass-29000) < 1e-6,"graph split preserves resources and mass")
	var asym := design.copy()
	asym.parts[5].position_m[0] = 2.0
	var offset := RocketState.new(asym,planet)
	offset.on_pad = false; offset.position = DVec3.new(0,planet.radius+100000,0)
	offset.controller.set_mode(AttitudeController.Mode.OFF,offset.orientation)
	offset.activate_stage(); offset.throttle = 1
	offset.step(1.0/120,planet)
	check(offset.applied_torque.z > 100000 and offset.angular_velocity.z > 0,"off-centre engine produces real torque and angular acceleration")
	var gimballed := RocketState.new(design,planet)
	gimballed.position = DVec3.new(0,planet.radius+100000,0); gimballed.on_pad = false
	gimballed.activate_stage(); gimballed.throttle = 1
	gimballed.controller.set_mode(AttitudeController.Mode.OFF,gimballed.orientation)
	gimballed.graph.parts.booster_engine.modules.engine.gimbal_target = Vector2(0.3,0)
	gimballed.step(1.0/120,planet)
	check(gimballed.graph.parts.booster_engine.modules.engine.gimbal.length() <= deg_to_rad(30)/120+1e-8 and absf(gimballed.applied_torque.x) > 1000,"actual nozzle gimbal generates torque with bounded slew")
	var path := "user://validation/parts_roundtrip.json"
	check(CraftCodec.save_craft(design,path) == OK,"versioned craft saves atomically")
	var restored := CraftCodec.load_craft(path)
	check(restored != null and restored.to_data() == design.to_data(),"craft recipe round-trips without flight state")
	var invalid := design.copy(); invalid.schema_version = 99
	check(not CraftCodec.validate(invalid).is_empty(),"unknown schema is rejected")
	invalid = design.copy(); invalid.connections.pop_back()
	check(not CraftCodec.validate(invalid).is_empty(),"disconnected craft is rejected")
	var base := design.copy()
	for count in [10,50,100,300]:
		var instances: Dictionary = {}
		for i in range(count):
			var entry: Dictionary = base.parts[1].duplicate(true)
			entry.id = "tank_%d" % i; entry.position_m = [0,i*7,0]
			instances[entry.id] = PartInstance.new(entry)
		var properties := MassProperties.new()
		var begin: int = Time.get_ticks_usec()
		for repeat in range(100): properties.update(instances)
		print("PROFILE mass aggregation %d parts: %.3f ms/update" % [count,(Time.get_ticks_usec()-begin)/100000.0])
		var reference_mass: float = properties.total
		begin = Time.get_ticks_usec()
		for repeat in range(1000): properties.consume({"tank_0":0.01})
		check(absf(properties.total-(reference_mass-10.0)) < 1e-6,"cached mass updates remain accurate for %d parts" % count)
		print("PROFILE cached burn %d parts: %.4f ms/update" % [count,(Time.get_ticks_usec()-begin)/1000000.0])
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)

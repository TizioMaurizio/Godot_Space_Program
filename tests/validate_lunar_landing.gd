extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1
func _initialize() -> void:
	var home: PlanetDefinition = load("res://data/aster.tres")
	var design := CraftCodec.load_craft("res://data/craft/neris_explorer.json")
	check(design != null,"Neris Explorer prebuilt validates attachment geometry and staging")
	if design == null: call_deferred("quit",1); return
	var craft := RocketState.new(design,home); craft.on_pad = false
	craft.activate_stage(); craft.activate_stage(); craft.activate_stage()
	craft.pending_bodies.clear()
	var session := FlightSession.new(craft,home); var moon := session.celestial.moons[0]
	var frame := session.celestial.ephemeris(moon,0)
	var ground: float = SurfaceQuery.height(moon,DVec3.new(0,1,0),0)
	var local := DVec3.new(0,moon.radius+ground+120,0)
	craft.position = frame.position.plus(local); craft.velocity = frame.velocity.plus(PlanetPhysics.air_velocity(local,moon)).plus(DVec3.new(0,-3,0))
	session.update_reference(craft)
	var landed: bool = false
	for i in range(120*180):
		var p := craft.relative_position(); var up := p.unit()
		var altitude: float = p.length()-moon.radius-SurfaceQuery.height(moon,p,craft.elapsed)-(craft.properties.center.y-craft.properties.minimum.y)
		var vertical: float = craft.relative_velocity().minus(PlanetPhysics.air_velocity(p,moon)).dot(up)
		var target: float = -clampf(altitude*0.12,0.3,8)
		var accel: float = moon.mu()/p.length_squared()+(target-vertical)*0.8
		craft.controller.target = AttitudeController.pointing(up.vec(),craft.orientation)
		craft.throttle = clampf(craft.mass*accel/100000,0,1)
		session.step(1.0/120,Vector3.ZERO)
		if craft.contacting: landed = true; break
		if craft.crashed: break
	craft.throttle = 0
	for i in range(120*10): session.step(1.0/120,Vector3.ZERO)
	check(landed and not craft.crashed,"finite-thrust descent lands Explorer on cratered lunar terrain")
	check(craft.relative_velocity().minus(PlanetPhysics.air_velocity(craft.relative_position(),moon)).length() < 0.5,"lunar contact settles without deleting the craft")
	check(craft.graph.parts.size() == 8,"capsule, tank, engine, parachute and four landing legs survive")
	print("LANDING time %.2fs fuel %.1f%% ground altitude %.3fm"%[craft.elapsed,craft.current_stage().fraction()*100,craft.relative_position().length()-moon.radius-SurfaceQuery.height(moon,craft.relative_position(),craft.elapsed)])
	print("RESULT: %d failures"%failures)
	call_deferred("quit",1 if failures else 0)

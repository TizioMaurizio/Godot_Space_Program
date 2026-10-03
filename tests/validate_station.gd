extends SceneTree
## Essential release gate only: loading, orbit, fuel, docking conservation and save.
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func run() -> void:
	var home: PlanetDefinition = load("res://data/aster.tres")
	for path in ["res://data/craft/aors_complete.json","res://data/craft/docking_tug.json","res://data/craft/module_launcher.json"]:
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path)); var design := CraftCodec.from_data(raw)
		var errors := CraftCodec.validate(design)
		check(errors.is_empty(),path+" "+str(errors))
	if failures: call_deferred("quit",1); return
	var session := OrbitalScenario.load_session("res://data/scenarios/aors_docking_test.json",home)
	check(session != null,"initialized AORS scenario loads")
	var station: RocketState = session.vessel("aors"); var tug: RocketState = session.active
	check(absf(station.mass-193850) < 1e-6,"44-part AORS mass is 193,850 kg")
	var before := station.position; var elements := OrbitalMechanics.elements(station.position,station.velocity,home)
	for i in range(12): session.coast_body(station,elements.period/12)
	check(station.position.minus(before).length() < 0.01,"station completes a Kepler orbit without altitude correction")
	# Restore common epoch for this separate close-docking fixture.
	station.elapsed = tug.elapsed; station.position = before
	var target: PartInstance = station.graph.parts["dock-aft"]
	var source: PartInstance = tug.graph.parts["tug-dock"]
	tug.orientation = station.orientation
	var target_frame := DockingSystem.frame(station,target)
	tug.position = target_frame.position.plus(target_frame.axis.scaled(0.04)).minus(source.node_position("dock").minus(tug.properties.center).rotated(tug.orientation))
	tug.velocity = station.velocity
	check(DockingSystem.eligible(tug,source,station,target),"valid low-speed geometry admits capture")
	tug.velocity = station.velocity.plus(target_frame.axis.scaled(2))
	check(not DockingSystem.eligible(tug,source,station,target),"fast docking is rejected")
	tug.velocity = station.velocity.plus(DVec3.new(0.02,-0.01,0.01))
	var initial_mass: float = station.mass+tug.mass
	var momentum := station.velocity.scaled(station.mass).plus(tug.velocity.scaled(tug.mass))
	station.angular_velocity = Vector3(-0.001,0.002,0.003); tug.angular_velocity = Vector3(0.01,-0.02,0.015)
	var origin := station.position
	var angular := station.properties.tensor.multiply(DVector.from_vec(station.angular_velocity)).rotated(station.orientation).plus(tug.properties.tensor.multiply(DVector.from_vec(tug.angular_velocity)).rotated(tug.orientation)).plus(tug.position.minus(origin).cross(tug.velocity.scaled(tug.mass)))
	var merged := session.docking.merge(session,station,target,tug,source)
	check(absf(merged.mass-initial_mass) < 1e-6 and merged.velocity.scaled(merged.mass).minus(momentum).length() < 1e-6,"hard docking conserves mass and linear momentum")
	var after_angular := merged.properties.tensor.multiply(DVector.from_vec(merged.angular_velocity)).rotated(merged.orientation).plus(merged.position.minus(origin).cross(merged.velocity.scaled(merged.mass)))
	check(after_angular.minus(angular).length()/maxf(angular.length(),1) < 1e-6,"hard docking conserves angular momentum")
	check(session.registry.bodies.size() == 1 and merged.graph.parts.size() == 50,"dock creates one real 50-part graph")
	session.active = merged
	var encoded := FlightSave.encode(session); var restored := FlightSave.restore(encoded,home)
	check(restored != null and restored.active.graph.parts.size() == 50,"docked graph/resources restore from separate flight save")
	if restored != null:
		check(restored.active.position.minus(merged.position).length() == 0,"flight restore preserves double position")
		check(restored.docking.undock(restored,restored.active) and restored.registry.bodies.size() == 2,"undocking splits and retains two persistent vessels")
		var vehicle: RocketState = restored.vessel("docking-tug")
		if vehicle != null:
			var m: float = vehicle.mass; vehicle.rcs_enabled = true; vehicle.rcs_command = Vector3.UP
			restored.step_body(vehicle,1.0/120)
			check(vehicle.mass < m and vehicle.rcs_force.length() > 0,"RCS consumes real propellant and applies force")
	station.power.step(station,session.celestial,1)
	check(station.power.generation > 0 and station.power.capacity == 362000000,"solar incidence and combined 360+2 MJ batteries are functional")
	check(ElectricPower.in_shadow(DVector.from_vec(ElectricPower.SUN).scaled(-720000),session.celestial,0),"Aster eclipse blocks sunlight")
	print("RESULT %d failures"%failures)
	call_deferred("quit",1 if failures else 0)

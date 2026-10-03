class_name OrbitalScenario
extends RefCounted

static func load_session(path: String, planet: PlanetDefinition) -> FlightSession:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("type","") != "initialized_orbital_scenario": return null
	var design := CraftCodec.load_craft(data.station)
	if design == null: return null
	var station := RocketState.new(design,planet); station.on_pad = false
	var radius: float = planet.radius+data.altitude_m
	var raan: float = deg_to_rad(data.raan_deg); var inc: float = deg_to_rad(data.inclination_deg)
	var argument: float = deg_to_rad(data.argument_of_latitude_deg)
	var plane := Quaternion(Vector3.BACK,raan)*Quaternion(Vector3.RIGHT,inc)
	station.position = DVec3.new(cos(argument),sin(argument),0).rotated(plane).scaled(radius)
	station.velocity = DVec3.new(-sin(argument),cos(argument),0).rotated(plane).scaled(sqrt(planet.mu()/radius))
	# Fixed inertial starting attitude: solar face toward the projected Sun; no orbital lock.
	var normal: Vector3 = ElectricPower.SUN
	var forward: Vector3 = station.velocity.unit().vec().slide(normal).normalized()
	station.orientation = Basis(forward.cross(normal).normalized(),forward,normal).get_rotation_quaternion()
	station.controller.set_mode(AttitudeController.Mode.OFF,station.orientation)
	station.vessel_uid = "aors"; station.lifecycle = "PERSISTENT"
	var session := FlightSession.new(station,planet)
	session.scenario_label = data.label
	session.campaign_mode = true
	if not str(data.get("visitor","")).is_empty():
		var visitor := RocketState.new(CraftCodec.load_craft(data.visitor),planet); visitor.on_pad = false
		visitor.vessel_uid = "docking-tug"; visitor.rcs_enabled = true
		visitor.orientation = (station.orientation*Quaternion(Vector3.BACK,deg_to_rad(10))).normalized()
		visitor.position = station.position.plus(DVec3.new(25,-data.visitor_distance_m,20).rotated(station.orientation))
		visitor.velocity = station.velocity.plus(DVec3.new(0.04,0.03,0.02).rotated(station.orientation))
		visitor.controller.set_mode(AttitudeController.Mode.OFF,visitor.orientation)
		session.registry.register(visitor); session.update_reference(visitor)
		session.active = visitor; session.target_uid = station.vessel_uid; session.target_port_id = "dock-aft"; session.source_port_id = "tug-dock"
	return session

class_name FlightSave
extends RefCounted
## Separate versioned, atomic live-flight saves; construction JSON stays design-only.
static func encode(session: FlightSession) -> Dictionary:
	var vessels: Array = []
	for body: RocketState in session.registry.bodies:
		var runtime: Dictionary = {}
		for part: PartInstance in body.graph.parts.values():
			var modules: Dictionary = {}
			for kind in part.modules:
				var m: PartModuleState = part.modules[kind]
				modules[kind] = {"config":m.config,"resources":m.resources,"active":m.active,"deployed":m.deployed,"failed":m.failed,"fraction":m.deployment_fraction,"gimbal":[m.gimbal.x,m.gimbal.y],"gimbal_target":[m.gimbal_target.x,m.gimbal_target.y],"deflection":m.deflection,"state":m.state,"connection_id":m.connection_id,"cooldown":m.cooldown}
			runtime[part.id] = {"damage":part.damage,"destroyed":part.destroyed,"modules":modules}
		vessels.append({"uid":body.vessel_uid,"id":body.body_id,"name":body.vessel_name,"lifecycle":body.lifecycle,"design":body.live_design().to_data(),"parts":runtime,"position":body.position.array(),"velocity":body.velocity.array(),"orientation":[body.orientation.x,body.orientation.y,body.orientation.z,body.orientation.w],"omega":[body.angular_velocity.x,body.angular_velocity.y,body.angular_velocity.z],"elapsed":body.elapsed,"on_pad":body.on_pad,"pad_origin_radius":body.pad_origin_radius,"pad_anchor_id":body.pad_anchor_id,"crashed":body.crashed,"throttle":body.throttle,"ignited":body.ignited,"stage_index":body.stage_index,"next_stage":body.next_stage,"rcs_enabled":body.rcs_enabled,"docking_armed":body.docking_armed,"mode":body.controller.mode,"attitude_target":[body.controller.target.x,body.controller.target.y,body.controller.target.z,body.controller.target.w]})
	var captures: Array = []
	for c in session.docking.captures: captures.append({"a":c.a.vessel_uid,"b":c.b.vessel_uid,"pa":c.pa,"pb":c.pb,"age":c.age,"stable":c.stable})
	return {"schema_version":1,"catalog_version":1,"epoch":session.time,"vessels":vessels,"active":session.active.vessel_uid,"target":session.target_uid,"target_port":session.target_port_id,"source_port":session.source_port_id,"captures":captures,"scenario_label":session.scenario_label,"campaign_mode":session.campaign_mode}

static func save(session: FlightSession, path: String = "user://saves/quicksave.json") -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(encode(session),"\t",true,true)); file.close()
	return DirAccess.rename_absolute(path+".tmp",path)

static func valid_vector(value, count: int) -> bool:
	return value is Array and value.size() == count and value.all(func(n): return (n is float or n is int) and is_finite(float(n)))

static func restore(data: Dictionary, planet: PlanetDefinition) -> FlightSession:
	if data.get("schema_version",0) != 1 or not data.get("vessels") is Array or data.vessels.is_empty(): return null
	var result: FlightSession
	for row in data.vessels:
		if not row is Dictionary or not row.get("design") is Dictionary or not row.get("parts") is Dictionary: return null
		if not valid_vector(row.get("position"),3) or not valid_vector(row.get("velocity"),3) or not valid_vector(row.get("orientation"),4) or not valid_vector(row.get("omega"),3): return null
		var design := CraftCodec.from_data(row.design)
		if not CraftCodec.validate(design,false).is_empty(): return null
		var body := RocketState.new(design,planet)
		for id in row.parts:
			if not body.graph.parts.has(id): return null
			var part: PartInstance = body.graph.parts[id]; var state: Dictionary = row.parts[id]
			part.damage = state.damage; part.destroyed = state.destroyed
			for kind in state.modules:
				var stored: Dictionary = state.modules[kind]; var module := PartModuleState.new(kind,stored.config)
				module.resources = stored.resources.duplicate(); module.active = stored.active; module.deployed = stored.deployed
				module.failed = stored.failed; module.deployment_fraction = stored.fraction
				module.gimbal = Vector2(stored.gimbal[0],stored.gimbal[1]); module.gimbal_target = Vector2(stored.gimbal_target[0],stored.gimbal_target[1])
				module.deflection = stored.deflection; module.state = stored.state; module.connection_id = stored.connection_id; module.cooldown = stored.cooldown
				part.modules[kind] = module
		body.refresh_structure(false); body.build_stage_views()
		body.position = DVector.from_array(row.position); body.velocity = DVector.from_array(row.velocity)
		body.orientation = Quaternion(row.orientation[0],row.orientation[1],row.orientation[2],row.orientation[3]); body.angular_velocity = Vector3(row.omega[0],row.omega[1],row.omega[2])
		body.elapsed = row.elapsed; body.on_pad = row.on_pad; body.pad_origin_radius = row.get("pad_origin_radius",body.pad_origin_radius); body.pad_anchor_id = row.get("pad_anchor_id",body.pad_anchor_id)
		body.crashed = row.crashed; body.throttle = row.throttle; body.ignited = row.ignited; body.stage_index = row.stage_index; body.next_stage = row.next_stage
		body.rcs_enabled = row.rcs_enabled; body.docking_armed = row.docking_armed
		body.lifecycle = row.lifecycle; body.vessel_uid = row.uid; body.vessel_name = row.name
		body.controller.mode = row.mode as AttitudeController.Mode
		body.controller.target = Quaternion(row.attitude_target[0],row.attitude_target[1],row.attitude_target[2],row.attitude_target[3])
		if result == null: result = FlightSession.new(body,planet)
		else: result.registry.register(body)
		body.body_id = int(row.id); result.update_reference(body)
		result.registry.next_id = maxi(result.registry.next_id,body.body_id+1)
	if result.vessel(data.get("active","")) == null: return null
	result.active = result.vessel(data.active); result.time = data.epoch; result.celestial.time = data.epoch
	result.target_uid = data.get("target",""); result.target_port_id = data.get("target_port",""); result.source_port_id = data.get("source_port","")
	result.scenario_label = data.get("scenario_label","SAVED FLIGHT")
	result.campaign_mode = data.get("campaign_mode",false)
	for row in data.get("captures",[]):
		var a := result.vessel(row.a); var b := result.vessel(row.b)
		if a != null and b != null: result.docking.captures.append({"a":a,"b":b,"pa":row.pa,"pb":row.pb,"age":row.age,"stable":row.stable})
	return result

static func load_session(path: String, planet: PlanetDefinition) -> FlightSession:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return null
	return restore(parser.data,planet)

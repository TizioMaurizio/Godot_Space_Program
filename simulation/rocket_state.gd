class_name RocketState
extends FlightBody
## One integrated body per connected graph. No visual-owned physics.

var definition: CraftDesign
var graph: PartGraph
var properties := MassProperties.new()
var fuel_network := FuelNetwork.new()
var stages: Array[StageView] = []
var stage_index: int = 0
var next_stage: int = 0
var throttle: float = 0.0
var ignited: bool = false
var on_pad: bool = true
var elapsed: float = 0.0
var launch_time: float = -1.0
var controller := AttitudeController.new()
var peak_q: float = 0.0
var thrust: float = 0.0
var pending_bodies: Array = []
var last_consumed: Dictionary = {}
var planet_definition: PlanetDefinition
var control_available: bool = true
var body_id: int = 0
var topology_revision: int = 0
var design_analysis: Dictionary = {}
var part_aero := PartAerodynamics.new()
var structure := StructuralSolver.new()
var structural_failure_enabled: bool = true
var contacting: bool = false
var last_contact_part: String = ""
var was_commanded: bool = false
var events: Array = []
var peak_stress: float = 0
var pad_origin_radius: float = 0
var pad_anchor_id: String = ""
var water_contact: bool = false
var pending_water_cuts: Array = []
var force_time: float = 0
var damage_dirty: bool = false
var celestial: CelestialSystem
var reference_body: PlanetDefinition
var integrating_relative: bool = false
var actuated_parts: Array[PartInstance] = []
var wheel_parts: Array[PartInstance] = []
var lifecycle: String = "PERSISTENT"
var vessel_uid: String = ""
var vessel_name: String = ""
var rcs_enabled: bool = false
var rcs_command := Vector3.ZERO
var rcs_force := DVec3.new()
var rcs_torque := DVec3.new()
var docking_armed: bool = true
var power := ElectricPower.new()

func live_design() -> CraftDesign:
	var result := definition.copy(); result.root_part_id = graph.root_id; result.parts.clear()
	for part: PartInstance in graph.parts.values():
		result.parts.append({"id":part.id,"definition_id":part.definition.id,"position_m":part.position.array(),"rotation_xyzw":[part.orientation.x,part.orientation.y,part.orientation.z,part.orientation.w],"origin_vessel":part.origin_vessel,"origin_name":part.origin_name})
	result.connections = graph.connections.duplicate(true)
	for edge in result.connections: edge.erase("load")
	for stage in result.stages: stage.actions = stage.actions.filter(func(a): return graph.parts.has(a.part_id))
	return result

func relative_position() -> DVec3:
	if celestial == null or integrating_relative: return position
	return position.minus(celestial.ephemeris(reference_body,elapsed).position)

func relative_velocity() -> DVec3:
	if celestial == null or integrating_relative: return velocity
	return velocity.minus(celestial.ephemeris(reference_body,elapsed).velocity)

func _init(input_config, planet: PlanetDefinition) -> void:
	var config: CraftDesign = input_config.copy() if input_config is CraftDesign else LegacyVehicleConverter.convert(input_config)
	definition = config
	vessel_name = config.display_name
	design_analysis = CraftAnalysis.analyze(config)
	planet_definition = planet
	reference_body = planet
	graph = PartGraph.new(config.parts,config.connections,config.root_part_id)
	refresh_structure(false)
	build_stage_views()
	was_commanded = control_available
	var clearance: float = properties.center.y-properties.minimum.y+1.0
	var terrain_height: float = SurfaceQuery.height_fixed(planet,DVec3.new(0,1,0))
	pad_origin_radius = planet.radius+terrain_height-properties.minimum.y+1.0
	var lowest: float = INF
	for part: PartInstance in graph.parts.values():
		var bottom: float = part.position.y-part.definition.length*0.5
		if bottom < lowest: lowest = bottom; pad_anchor_id = part.id
	position = DVec3.new(properties.center.x,planet.radius+terrain_height+clearance,properties.center.z)
	velocity = PlanetPhysics.air_velocity(position,planet)

func refresh_structure(preserve_world: bool = true, consumed: Dictionary = {}) -> void:
	var old_center := properties.center
	if consumed.is_empty(): properties.update(graph.parts)
	else: properties.consume(consumed)
	if preserve_world and not on_pad:
		var shift := properties.center.minus(old_center).rotated(orientation)
		position = position.plus(shift)
		velocity = velocity.plus(DVector.from_vec(orientation*angular_velocity).cross(shift))
	mass = properties.total
	length = properties.maximum.y-properties.minimum.y
	radius = maxf(properties.maximum.x-properties.minimum.x,properties.maximum.z-properties.minimum.z)*0.5
	area = PI*radius*radius
	if consumed.is_empty():
		control_available = false
		actuated_parts.clear(); wheel_parts.clear()
		for part: PartInstance in graph.parts.values():
			if part.has_module("command"): control_available = true
			if part.modules.has("engine") or part.modules.has("parachute") or part.modules.has("fin") or part.modules.has("rcs"): actuated_parts.append(part)
			if part.modules.has("wheel"): wheel_parts.append(part)

func inertia() -> Vector3:
	return Vector3(properties.tensor.xx,properties.tensor.yy,properties.tensor.zz)*(mass/maxf(properties.total,1e-12))

func inertia_tensor() -> SymmetricTensor:
	return properties.tensor.scaled(mass/maxf(properties.total,1e-12))

func control_torque_limit() -> float:
	if not control_available: return 0.0
	var available: float = 0
	for part: PartInstance in wheel_parts:
		if part.has_module("wheel") and part.modules.wheel.config.get("enabled",true): available += part.modules.wheel.config.torque
	return available*(power.critical_fraction if power.enabled else 1.0)

func build_stage_views() -> void:
	stages.clear()
	fuel_network.rebuild(graph)
	var engine_ids: Array = []
	for stage in definition.stages:
		var view := StageView.new()
		var visited: Dictionary = {}
		for action in stage.actions:
			if action.action == "shutdown": engine_ids.erase(action.part_id)
			if action.action == "ignite" and graph.parts.has(action.part_id) and not action.part_id in engine_ids: engine_ids.append(action.part_id)
		for engine_id in engine_ids:
			var engine_part: PartInstance = graph.parts[engine_id]
			view.definition.engine = engine_part.modules.engine.engine
			for id in graph.reachable(engine_id,true):
				if visited.has(id): continue
				visited[id] = true
				var part: PartInstance = graph.parts[id]
				view.members.append(part)
				if part.has_module("tank"): view.tanks.append(part)
		view.definition.fuel_mass = 0
		view.definition.oxidizer_mass = 0
		for tank_part in view.tanks:
			view.definition.fuel_mass += tank_part.modules.tank.config.fuel
			view.definition.oxidizer_mass += tank_part.modules.tank.config.oxidizer
		if view.definition.engine == null:
			view.definition.engine = EngineDefinition.new(); view.definition.engine.vacuum_thrust = 0
		stages.append(view)
	if stages.is_empty():
		var view := StageView.new()
		view.definition.engine = EngineDefinition.new(); view.definition.engine.vacuum_thrust = 0
		stages.append(view)

func current_stage() -> StageView:
	return stages[mini(stage_index,stages.size()-1)]

func part_world_position(part: PartInstance) -> DVec3:
	return position.plus(part.position.minus(properties.center).rotated(orientation))

func activate_stage() -> RocketState:
	if crashed: return null
	if ignited and next_stage == 0: next_stage = 1
	if next_stage >= definition.stages.size(): return null
	var actions: Array = definition.stages[next_stage].actions
	if on_pad and ignited and actions.any(func(a): return a.action == "decouple"): return null
	var stage_targets: Dictionary = graph.parts.duplicate()
	next_stage += 1; ignited = true
	stage_index = next_stage-1
	var first: RocketState
	for action in actions:
		if not stage_targets.has(action.part_id): continue
		var part: PartInstance = stage_targets[action.part_id]
		match action.action:
			"ignite":
				if part.has_module("engine"): part.modules.engine.active = true
			"shutdown":
				if part.modules.has("engine"): part.modules.engine.active = false
			"decouple":
				if not part.has_module("decoupler"): continue
				if not graph.parts.has(part.id): continue
				var cuts: Array = []
				for edge: Dictionary in graph.adjacency[part.id]:
					var end: Array = edge.a if edge.a[0] == part.id else edge.b
					if end[1] == part.modules.decoupler.config.get("node","top"): cuts.append(edge.id)
				var spawned := split_connections(cuts,float(part.modules.decoupler.config.get("separation_speed",2)))
				if not spawned.is_empty() and first == null: first = spawned[0]
			"deploy":
				for kind in ["parachute","leg"]:
					if part.has_module(kind) and not part.modules[kind].failed: part.modules[kind].deployed = true
	return first

func split_connections(cuts: Array, separation_speed: float = 0.0) -> Array:
	var created: Array = []
	if cuts.is_empty(): return created
	var old_center := properties.center
	var old_position := position
	var old_velocity := velocity
	var held_by_pad: bool = on_pad
	var anchor_id: String = pad_anchor_id
	var anchor_radius: float = pad_origin_radius
	var omega_world := DVector.from_vec(angular_velocity).rotated(orientation)
	var original_parts: Dictionary = graph.parts.duplicate()
	var separation_point := DVec3.new()
	var separation_axis := DVec3.new(0,1,0)
	for edge in graph.connections:
		if edge.id in cuts:
			var socket: PartInstance = original_parts[edge.b[0]]
			separation_point = socket.node_position(edge.b[1])
			separation_axis = DVector.from_array(socket.definition.nodes[edge.b[1]].normal).rotated(socket.orientation).unit()
			break
	graph.cut(cuts)
	var groups: Array = graph.components()
	if groups.size() < 2: return created
	var edges: Array = graph.connections.duplicate(true)
	var retained: Array = []
	for group in groups:
		if graph.root_id in group: retained = group
	if retained.is_empty(): retained = groups[0]
	var assemblies: Array = [self]
	for group in groups:
		if group == retained: continue
		var subset := live_design()
		subset.parts = subset.parts.filter(func(p): return p.id in group)
		subset.connections = edges.filter(func(c): return c.a[0] in group and c.b[0] in group)
		subset.root_part_id = group[0]
		var component := RocketState.new(subset,planet_definition)
		component.graph.parts.clear()
		for id in group: component.graph.parts[id] = original_parts[id]
		component.graph.rebuild()
		component.on_pad = false
		component.elapsed = elapsed; component.launch_time = launch_time
		component.throttle = throttle; component.ignited = ignited
		component.next_stage = next_stage; component.stage_index = stage_index
		component.orientation = orientation; component.angular_velocity = angular_velocity
		component.controller.set_mode(AttitudeController.Mode.OFF,orientation)
		component.refresh_structure(false)
		component.rcs_enabled = rcs_enabled; component.docking_armed = docking_armed
		component.lifecycle = "PERSISTENT" if component.control_available else "DEBRIS"
		for part: PartInstance in component.graph.parts.values():
			if part.has_module("command"):
				component.vessel_uid = part.origin_vessel; component.vessel_name = part.origin_name
				component.graph.root_id = part.id
				break
		component.build_stage_views()
		assemblies.append(component); created.append(component)
	graph.parts.clear()
	for id in retained: graph.parts[id] = original_parts[id]
	graph.connections = []
	for edge in edges:
		if edge.a[0] in retained and edge.b[0] in retained: graph.connections.append(edge)
	graph.rebuild()
	refresh_structure(false)
	fuel_network.graph_version = -1
	build_stage_views()
	for component in assemblies:
		var offset: DVec3 = component.properties.center.minus(old_center).rotated(orientation)
		component.position = old_position.plus(offset)
		component.velocity = old_velocity.plus(omega_world.cross(offset))
		component.fuel_network.graph_version = -1
		component.on_pad = held_by_pad and component.graph.parts.has(anchor_id)
		component.pad_anchor_id = anchor_id; component.pad_origin_radius = anchor_radius
	if separation_speed > 0 and created.size() == 1:
		var other: RocketState = created[0]
		if properties.center.minus(other.properties.center).dot(separation_axis) < 0: separation_axis = separation_axis.scaled(-1)
		var axis := separation_axis.rotated(orientation)
		var arm_a := separation_point.minus(properties.center)
		var arm_b := separation_point.minus(other.properties.center)
		var local_axis := separation_axis
		var cross_a := arm_a.cross(local_axis); var cross_b := arm_b.cross(local_axis)
		var k: float = 1.0/mass+1.0/other.mass+cross_a.dot(properties.tensor.solve(cross_a))+cross_b.dot(other.properties.tensor.solve(cross_b))
		var impulse: float = separation_speed/k
		velocity = velocity.plus(axis.scaled(impulse/mass))
		other.velocity = other.velocity.minus(axis.scaled(impulse/other.mass))
		angular_velocity += properties.tensor.solve(cross_a.scaled(impulse)).vec()
		other.angular_velocity -= other.properties.tensor.solve(cross_b.scaled(impulse)).vec()
	pending_bodies.append_array(created)
	topology_revision += 1
	return created

func record_failure(cuts: Array) -> void:
	var loads: Array = []
	for edge in graph.connections:
		if edge.id in cuts: loads.append({"id":edge.id,"load":edge.load.duplicate()})
	events.append({"type":"break","position":position,"energy":0.0,"time":elapsed,"connections":cuts.duplicate(),"loads":loads})

func step(dt: float, planet: PlanetDefinition, manual: Vector3 = Vector3.ZERO) -> void:
	if not simulation_active: return
	if crashed: throttle = 0
	contacting = false
	force_time = elapsed
	elapsed += dt
	var pressure: float = PlanetPhysics.pressure(position.length()-planet.radius,planet.atmosphere)
	var old_mass: float = mass
	last_consumed = fuel_network.burn(graph,throttle if ignited else 0.0,pressure/101325.0,dt)
	var rcs := RCSSystem.burn(self,dt)
	for id in rcs.consumed: last_consumed[id] = last_consumed.get(id,0.0)+rcs.consumed[id]
	if not last_consumed.is_empty(): refresh_structure(true,last_consumed)
	var final_mass: float = mass
	mass = (old_mass+final_mass)*0.5
	var total_thrust := DVec3.new()
	var torque := DVec3.new()
	thrust = 0
	for part: PartInstance in graph.parts.values():
		if part.transient_contact_force:
			part.force = DVec3.new(); part.moment = DVec3.new(); part.transient_contact_force = false
	for part: PartInstance in actuated_parts:
		part.force = DVec3.new(); part.moment = DVec3.new()
		if rcs.forces.has(part.id):
			part.force = rcs.forces[part.id]
			total_thrust = total_thrust.plus(part.force)
			torque = torque.plus(part.position.minus(properties.center).cross(part.force))
		if part.has_module("fin") and part.modules.fin.config.get("control",false):
			var normal := DVec3.new(1,0,0).rotated(part.orientation)
			var axis := part.position.minus(properties.center).cross(normal).unit().vec()
			var target: float = manual.dot(axis)*deg_to_rad(float(part.modules.fin.config.get("deflection_deg",12)))
			part.modules.fin.deflection = move_toward(part.modules.fin.deflection,target,deg_to_rad(30)*dt)
		if part.has_module("parachute") and part.modules.parachute.deployed:
			var chute: PartModuleState = part.modules.parachute
			if dynamic_pressure > chute.config.get("maximum_q",10000):
				chute.failed = true; chute.deployed = false; part.damage = maxf(part.damage,0.25)
				events.append({"type":"break","position":part_world_position(part),"energy":0.0})
			else: chute.deployment_fraction = minf(1,chute.deployment_fraction+dt*0.5)
		if not part.has_module("engine"): continue
		var engine: PartModuleState = part.modules.engine
		var limit: float = deg_to_rad(float(engine.config.get("gimbal_deg",0)))
		if engine.config.get("gimbal_enabled",false): engine.gimbal_target = Vector2(manual.x,manual.z)*limit
		engine.gimbal = engine.gimbal.move_toward(engine.gimbal_target.limit_length(limit),deg_to_rad(30)*dt)
		var gimbal := Quaternion(Vector3.RIGHT,clampf(engine.gimbal.x,-limit,limit))*Quaternion(Vector3.BACK,clampf(engine.gimbal.y,-limit,limit))
		var force := DVec3.new(0,engine.thrust,0).rotated(part.orientation*gimbal)
		part.force = force
		part.moment = DVec3.new(0,-part.definition.length*0.5,0).rotated(part.orientation).cross(force)
		total_thrust = total_thrust.plus(force)
		torque = torque.plus(part.position.minus(properties.center).cross(force)).plus(part.moment)
		thrust += engine.thrust
	applied_torque = torque.vec()
	if on_pad:
		var angle: float = planet.rotation_rate*elapsed
		orientation = Quaternion(Vector3.BACK,angle)
		position = DVec3.new(-sin(angle)*pad_origin_radius,cos(angle)*pad_origin_radius,0).plus(properties.center.rotated(orientation))
		velocity = PlanetPhysics.air_velocity(position,planet)
		controller.target = orientation
		if total_thrust.y > mass*PlanetPhysics.gravity(position,planet).length():
			on_pad = false; launch_time = elapsed
	else:
		sample_atmosphere(planet)
		var fluid := WaterSystem.evaluate(self,position,velocity,planet,force_time,dt,true)
		water_contact = fluid.wet
		applied_torque += fluid.torque.vec()
		damping_coefficient += fluid.damping
		var omega_before: Vector3 = angular_velocity
		controller.step(self,planet,manual if control_available else Vector3.ZERO,dt)
		last_angular_acceleration = (angular_velocity-omega_before)/dt
	if not on_pad:
		integrate(dt,planet,total_thrust.rotated(orientation))
		peak_q = maxf(peak_q,dynamic_pressure)
	mass = final_mass
	if not on_pad:
		if not pending_water_cuts.is_empty():
			split_connections(pending_water_cuts); pending_water_cuts.clear()
			damage_dirty = true
		if damage_dirty:
			refresh_structure(false)
			if not control_available and was_commanded: crashed = true; throttle = 0
			damage_dirty = false
		ContactSolver.solve(self,planet,dt)
		if definition.aero_model != "legacy_envelope":
			var failed := structure.evaluate(self,last_angular_acceleration)
			peak_stress = maxf(peak_stress,structure.maximum_utilization)
			if structural_failure_enabled and not failed.is_empty():
				record_failure(failed)
				split_connections(failed)

var last_angular_acceleration := Vector3.ZERO

func sample_atmosphere(planet: PlanetDefinition) -> void:
	if definition == null or definition.aero_model == "legacy_envelope":
		super(planet)
		return
	atmosphere_velocity = PlanetPhysics.air_velocity(position,planet)
	air_velocity = velocity.minus(atmosphere_velocity)
	density = PlanetPhysics.density(position.length()-planet.radius,planet.atmosphere)
	dynamic_pressure = Aerodynamics.dynamic_pressure(air_velocity,density)
	var aero := part_aero.evaluate(self,position,velocity,planet,true)
	drag_force = aero.force; aerodynamic_torque = aero.torque.vec(); damping_coefficient = aero.damping
	heating = clampf(sqrt(density)*pow(air_velocity.length()/2200.0,3.0)/0.2,0,1)

func endpoint_drag(p: DVec3, v: DVec3, planet: PlanetDefinition, rho: float, air: DVec3) -> DVec3:
	if definition.aero_model == "legacy_envelope": return super(p,v,planet,rho,air)
	return part_aero.evaluate(self,p,v,planet,false).force

func additional_force(p: DVec3, v: DVec3, planet: PlanetDefinition, dt: float, sample_dt: float) -> DVec3:
	return WaterSystem.evaluate(self,p,v,planet,force_time+sample_dt,dt,false).force

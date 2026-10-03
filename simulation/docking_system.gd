class_name DockingSystem
extends RefCounted
## Geometric admission, equal/opposite capture impulses, conservative rigid merge.
var captures: Array = []
var last_message: String = ""

static func ports(body: RocketState) -> Array:
	return body.graph.parts.values().filter(func(p): return p.has_module("docking"))

static func frame(body: RocketState, part: PartInstance) -> Dictionary:
	var q: Quaternion = body.orientation*part.orientation
	var offset := DVector.from_array(part.definition.nodes.dock.position).rotated(part.orientation).plus(part.position).minus(body.properties.center).rotated(body.orientation)
	var point := body.position.plus(offset)
	return {"position":point,"axis":DVec3.new(0,1,0).rotated(q),"velocity":body.velocity.plus(DVector.from_vec(body.angular_velocity).rotated(body.orientation).cross(offset))}

static func metrics(source: RocketState, source_port: PartInstance, target: RocketState, target_port: PartInstance) -> Dictionary:
	var a := frame(source,source_port); var b := frame(target,target_port)
	var offset: DVec3 = a.position.minus(b.position); var relative: DVec3 = a.velocity.minus(b.velocity)
	var axial: float = offset.dot(b.axis)
	var lateral := offset.minus(b.axis.scaled(axial))
	var angular: float = acos(clampf(-a.axis.dot(b.axis),-1,1))
	var closing: float = -relative.dot(b.axis)
	return {"range":offset.length(),"plane":axial,"lateral":lateral.length(),"alignment":rad_to_deg(angular),"relative_speed":relative.length(),"range_rate":relative.dot(offset.unit()),"closing":closing,"lateral_speed":relative.minus(b.axis.scaled(relative.dot(b.axis))).length(),"relative":relative,"direction":offset.scaled(-1).unit(),"lateral_vector":lateral,"target_axis":b.axis}

static func eligible(a: RocketState, pa: PartInstance, b: RocketState, pb: PartInstance) -> bool:
	var ma: PartModuleState = pa.modules.docking; var mb: PartModuleState = pb.modules.docking
	if ma.state not in ["AVAILABLE","TARGETED"] or mb.state not in ["AVAILABLE","TARGETED"] or ma.cooldown > 0 or mb.cooldown > 0: return false
	if ma.config.type != mb.config.type or not a.docking_armed or not b.docking_armed: return false
	if (a.power.enabled and a.power.critical_fraction < 0.9) or (b.power.enabled and b.power.critical_fraction < 0.9): return false
	var m := metrics(a,pa,b,pb)
	var angular_speed: float = (a.orientation*a.angular_velocity-b.orientation*b.angular_velocity).length()
	return absf(m.plane) <= minf(ma.config.distance,mb.config.distance) and m.lateral <= minf(ma.config.lateral,mb.config.lateral) and m.relative_speed <= minf(ma.config.speed,mb.config.speed) and m.alignment <= minf(ma.config.angle_deg,mb.config.angle_deg) and angular_speed < deg_to_rad(5)

static func impulse(body: RocketState, part: PartInstance, point: DVec3, linear: DVec3, couple: DVec3, dt: float) -> void:
	var local := linear.rotated(body.orientation.inverse())
	var arm := point.minus(body.position).rotated(body.orientation.inverse())
	var torque := arm.cross(local).plus(couple.rotated(body.orientation.inverse()))
	var dw := body.properties.tensor.solve(torque)
	body.velocity = body.velocity.plus(linear.scaled(1/body.mass)); body.angular_velocity += dw.vec()
	body.acceleration = body.acceleration.plus(linear.scaled(1/body.mass/maxf(dt,1e-9))); body.last_angular_acceleration += dw.vec()/maxf(dt,1e-9)
	part.force = part.force.plus(local.scaled(1/maxf(dt,1e-9)))
	part.moment = part.moment.plus(point.minus(body.part_world_position(part)).rotated(body.orientation.inverse()).cross(local).plus(couple.rotated(body.orientation.inverse())).scaled(1/maxf(dt,1e-9)))
	part.transient_contact_force = true

func step(session: FlightSession, dt: float) -> void:
	for body: RocketState in session.registry.bodies:
		for port: PartInstance in ports(body):
			var module: PartModuleState = port.modules.docking
			module.cooldown = maxf(0,module.cooldown-dt)
			if not module.connection_id.is_empty() and not body.graph.connections.any(func(c): return c.id == module.connection_id):
				module.connection_id = ""; module.state = "AVAILABLE"; module.cooldown = 2
	for i in range(captures.size()-1,-1,-1):
		var c: Dictionary = captures[i]; var a: RocketState = c.a; var b: RocketState = c.b
		if not a in session.registry.bodies or not b in session.registry.bodies or not a.graph.parts.has(c.pa) or not b.graph.parts.has(c.pb): captures.remove_at(i); continue
		var pa: PartInstance = a.graph.parts[c.pa]; var pb: PartInstance = b.graph.parts[c.pb]
		var m := metrics(a,pa,b,pb)
		if pa.destroyed or pb.destroyed or m.range > 1 or m.relative_speed > 2 or not a.docking_armed or not b.docking_armed:
			pa.modules.docking.state = "AVAILABLE"; pb.modules.docking.state = "AVAILABLE"; captures.remove_at(i); continue
		var fa := frame(a,pa); var fb := frame(b,pb)
		var reduced: float = a.mass*b.mass/(a.mass+b.mass)
		var spring: float = 1800; var damping: float = 2*sqrt(spring*reduced)
		var force: DVec3 = fb.position.minus(fa.position).scaled(spring).minus(fa.velocity.minus(fb.velocity).scaled(damping))
		var wa := DVector.from_vec(a.angular_velocity).rotated(a.orientation); var wb := DVector.from_vec(b.angular_velocity).rotated(b.orientation)
		var couple: DVec3 = fa.axis.cross(fb.axis.scaled(-1)).scaled(1500).minus(wa.minus(wb).scaled(1600))
		var capture_point: DVec3 = fa.position.plus(fb.position).scaled(0.5)
		impulse(a,pa,capture_point,force.scaled(dt),couple.scaled(dt),dt)
		impulse(b,pb,capture_point,force.scaled(-dt),couple.scaled(-dt),dt)
		c.age += dt
		if m.range < 0.035 and m.relative_speed < 0.035 and m.alignment < 0.8: c.stable += dt
		else: c.stable = 0
		if c.stable >= 0.4:
			merge(session,a,pa,b,pb); captures.remove_at(i)
	var bodies: Array = session.registry.bodies.duplicate()
	for i in range(bodies.size()):
		for j in range(i+1,bodies.size()):
			var a: RocketState = bodies[i]; var b: RocketState = bodies[j]
			if a.position.minus(b.position).length() > a.length+b.length+a.radius+b.radius+5: continue
			for pa: PartInstance in ports(a):
				for pb: PartInstance in ports(b):
					if eligible(a,pa,b,pb):
						pa.modules.docking.state = "SOFT_CAPTURE"; pb.modules.docking.state = "SOFT_CAPTURE"
						captures.append({"a":a,"pa":pa.id,"b":b,"pb":pb.id,"age":0.0,"stable":0.0})
						last_message = "Soft capture: release RCS and SAS for alignment"

func merge(session: FlightSession, a: RocketState, pa: PartInstance, b: RocketState, pb: PartInstance) -> RocketState:
	# Keep the station/larger assembly's construction frame and stable identity.
	if b.mass > a.mass: return merge(session,b,pb,a,pa)
	var ma: float = a.mass; var mb: float = b.mass; var total: float = ma+mb
	var qa: Quaternion = a.orientation; var qb: Quaternion = b.orientation
	var ca := a.properties.center; var center := a.position.plus(b.position.minus(a.position).scaled(mb/total))
	var velocity := a.velocity.scaled(ma/total).plus(b.velocity.scaled(mb/total))
	var momentum := a.properties.tensor.multiply(DVector.from_vec(a.angular_velocity)).rotated(qa).plus(b.properties.tensor.multiply(DVector.from_vec(b.angular_velocity)).rotated(qb))
	momentum = momentum.plus(a.position.minus(center).cross(a.velocity.minus(velocity).scaled(ma))).plus(b.position.minus(center).cross(b.velocity.minus(velocity).scaled(mb)))
	var mapping: Dictionary = {}
	for part: PartInstance in b.graph.parts.values():
		var id: String = part.id
		if a.graph.parts.has(id): id = b.vessel_uid+"__"+id
		while a.graph.parts.has(id): id += "_"
		mapping[part.id] = id
		part.position = b.part_world_position(part).minus(a.position).rotated(qa.inverse()).plus(ca)
		part.orientation = (qa.inverse()*qb*part.orientation).normalized(); part.refresh_pose_cache()
		part.id = id; a.graph.parts[id] = part
	for edge in b.graph.connections:
		var copy: Dictionary = edge.duplicate(true); copy.id = b.vessel_uid+"__"+copy.id
		copy.a[0] = mapping[copy.a[0]]; copy.b[0] = mapping[copy.b[0]]; a.graph.connections.append(copy)
	var connection: String = "dock_%s_%s"%[a.vessel_uid,b.vessel_uid]
	var pb_id: String = mapping[pb.id] if mapping.has(pb.id) else pb.id
	# pb.id may already have been remapped in place; lookup through mapped values.
	var visitor_stages: Array = b.definition.stages.duplicate(true)
	for stage in visitor_stages:
		for action in stage.actions:
			if mapping.has(action.part_id): action.part_id = mapping[action.part_id]
	a.graph.connections.append({"id":connection,"a":[pa.id,"dock"],"b":[pb_id,"dock"],"kind":"docking","crossfeed":false,"electric_crossfeed":true,"strength":150000.0,"shear_strength":80000.0,"bending_strength":250000.0,"torsion_strength":120000.0,"visitor_uid":b.vessel_uid,"visitor_stages":visitor_stages,"visitor_next_stage":b.next_stage,"visitor_stage_index":b.stage_index,"visitor_rcs":b.rcs_enabled,"visitor_throttle":b.throttle,"visitor_ignited":b.ignited})
	pa.modules.docking.state = "HARD_DOCKED"; pb.modules.docking.state = "HARD_DOCKED"
	pa.modules.docking.connection_id = connection; pb.modules.docking.connection_id = connection
	a.graph.rebuild(); a.refresh_structure(false)
	a.position = center; a.velocity = velocity; a.angular_velocity = a.properties.tensor.solve(momentum.rotated(qa.inverse())).vec()
	a.definition = a.live_design(); a.definition.display_name = a.vessel_name
	a.fuel_network.graph_version = -1; a.build_stage_views(); a.topology_revision += 1
	session.registry.bodies.erase(b)
	if session.active == b: session.active = a
	session.target_uid = ""; session.target_port_id = ""
	last_message = "Hard dock / combined assembly"
	return a

func undock(session: FlightSession, body: RocketState) -> bool:
	var cuts: Array = []
	var saved: Dictionary = {}
	for edge in body.graph.connections:
		if edge.get("kind","") == "docking": cuts = [edge.id]; saved = edge.duplicate(true); break
	if cuts.is_empty(): last_message = "No docking connection on this vessel"; return false
	for port: PartInstance in ports(body):
		if port.modules.docking.connection_id in cuts:
			port.modules.docking.connection_id = ""; port.modules.docking.state = "UNDOCKING"; port.modules.docking.cooldown = 5
	var children := body.split_connections(cuts,0.18)
	for component in [body]+children:
		component.definition = component.live_design()
		if component.vessel_uid == saved.visitor_uid:
			component.definition.stages = saved.get("visitor_stages",[])
			component.next_stage = saved.get("visitor_next_stage",0); component.stage_index = saved.get("visitor_stage_index",0)
			component.rcs_enabled = saved.get("visitor_rcs",false); component.throttle = saved.get("visitor_throttle",0); component.ignited = saved.get("visitor_ignited",false)
			component.build_stage_views()
		for port: PartInstance in ports(component):
			if port.modules.docking.state == "UNDOCKING": port.modules.docking.state = "AVAILABLE"
	session.registry.collect_splits()
	last_message = "Undocked / separation impulse 0.18 m/s"
	return true

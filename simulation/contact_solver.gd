class_name ContactSolver
extends RefCounted
## Part-identified contacts against the authoritative spherical terrain field.

static func support(part: PartInstance, normal_local: DVec3) -> float:
	if not part.definition.box_size.is_empty():
		var direction := normal_local.rotated(part.orientation.inverse())
		var half := part.definition.half_extents()
		return absf(direction.x)*half.x+absf(direction.y)*half.y+absf(direction.z)*half.z
	var axis := DVec3.new(0,1,0).rotated(part.orientation)
	var along: float = absf(axis.dot(normal_local))
	return along*part.definition.length*0.5+sqrt(maxf(0,1-along*along))*part.definition.radius

static func solve(craft: RocketState, planet: PlanetDefinition, dt: float) -> void:
	var maximum_height: float = planet.terrain.maximum_height if planet.terrain != null else 0.0
	if craft.position.length()-planet.radius > (craft.properties.maximum-craft.properties.minimum).length()+maximum_height+2: return
	var contacts: Array = []
	var cuts: Array = []
	for part: PartInstance in craft.graph.parts.values():
		var world := craft.part_world_position(part)
		var ground_height: float = SurfaceQuery.height(planet,world,craft.elapsed)
		if world.length()-planet.radius-ground_height > part.definition.length*0.5+part.definition.radius: continue
		var up := SurfaceQuery.normal(planet,world,craft.elapsed)
		var normal_local := up.rotated(craft.orientation.inverse())
		var extent: float = support(part,normal_local)
		var penetration: float = planet.radius+ground_height+extent-world.length()
		if penetration < 0: continue
		var arm := part.position.minus(craft.properties.center).minus(normal_local.scaled(extent))
		var point_velocity := craft.velocity.plus(DVector.from_vec(craft.angular_velocity).cross(arm).rotated(craft.orientation)).minus(PlanetPhysics.air_velocity(world,planet))
		var speed: float = maxf(0,-point_velocity.dot(up))
		var tolerance: float = part.definition.crash_speed
		if part.has_module("leg") and part.modules.leg.deployed: tolerance *= 1.8
		var damaged: bool = speed > tolerance
		if damaged and not part.destroyed:
			part.destroyed = true; part.damage = 1
			for edge: Dictionary in craft.graph.adjacency[part.id]:
				if not edge.id in cuts: cuts.append(edge.id)
			for kind in ["engine","wheel","command"]:
				if part.modules.has(kind): part.modules[kind].active = false
			craft.events.append({"type":"impact","part_id":part.id,"position":world,"energy":0.5*part.mass()*speed*speed,"fuelled":part.modules.has("tank")})
		contacts.append({"part":part,"normal":up,"extent":extent,"penetration":penetration})
	if contacts.is_empty(): return
	var bodies: Array = [craft]
	if not cuts.is_empty(): bodies.append_array(craft.split_connections(cuts))
	var owners: Dictionary = {}
	for body in bodies:
		for id in body.graph.parts: owners[id] = body
	for contact in contacts:
		var part: PartInstance = contact.part
		var body: RocketState = owners[part.id]
		var up: DVec3 = contact.normal
		var local_normal := up.rotated(body.orientation.inverse())
		var arm := part.position.minus(body.properties.center).minus(local_normal.scaled(contact.extent))
		var point_velocity := body.velocity.plus(DVector.from_vec(body.angular_velocity).cross(arm).rotated(body.orientation)).minus(PlanetPhysics.air_velocity(body.part_world_position(part),planet))
		var vn: float = point_velocity.dot(up)
		var cross := arm.cross(local_normal)
		var effective: float = 1.0/body.mass+cross.dot(body.properties.tensor.solve(cross))
		var impulse: float = maxf(0,-vn*1.05)/maxf(effective,1e-12)
		body.velocity = body.velocity.plus(up.scaled(impulse/body.mass))
		var dw := body.properties.tensor.solve(cross.scaled(impulse)).vec()
		body.angular_velocity += dw
		body.acceleration = body.acceleration.plus(up.scaled(impulse/body.mass/dt))
		body.last_angular_acceleration += dw/dt
		var local_impulse := local_normal.scaled(impulse)
		part.force = part.force.plus(local_impulse.scaled(1/dt))
		part.transient_contact_force = true
		part.moment = part.moment.plus(local_normal.scaled(-contact.extent).cross(local_impulse).scaled(1/dt))
		point_velocity = body.velocity.plus(DVector.from_vec(body.angular_velocity).cross(arm).rotated(body.orientation)).minus(PlanetPhysics.air_velocity(body.part_world_position(part),planet))
		var tangent := point_velocity.minus(up.scaled(point_velocity.dot(up)))
		if tangent.length() > 0.001:
			var tangent_local := tangent.unit().rotated(body.orientation.inverse())
			var tangent_arm := arm.cross(tangent_local)
			var effective_t: float = 1/body.mass+tangent_arm.dot(body.properties.tensor.solve(tangent_arm))
			var friction := tangent.unit().scaled(-minf(impulse*0.6,tangent.length()/effective_t))
			body.velocity = body.velocity.plus(friction.scaled(1/body.mass))
			var friction_local := friction.rotated(body.orientation.inverse())
			var friction_dw := body.properties.tensor.solve(arm.cross(friction_local)).vec()
			body.angular_velocity += friction_dw
			body.acceleration = body.acceleration.plus(friction.scaled(1/body.mass/dt))
			body.last_angular_acceleration += friction_dw/dt
			part.force = part.force.plus(friction_local.scaled(1/dt))
			part.moment = part.moment.plus(local_normal.scaled(-contact.extent).cross(friction_local).scaled(1/dt))
		body.position = body.position.plus(up.scaled(minf(contact.penetration*0.6,2.0)))
		body.contacting = true
		body.last_contact_part = part.id
	for body in bodies:
		body.refresh_structure(false)
		if not body.control_available and body.was_commanded:
			body.crashed = true; body.throttle = 0; body.thrust = 0

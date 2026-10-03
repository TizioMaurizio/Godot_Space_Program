class_name AssemblyCollisions
extends RefCounted
## Spatial-hash broad phase and oriented-box part contacts between components.
static func solve(bodies: Array, dt: float) -> void:
	if bodies.size() < 2: return
	var cell_size: float = 8.0
	for body in bodies:
		for part: PartInstance in body.graph.parts.values():
			cell_size = maxf(cell_size,maxf(part.definition.length,part.definition.radius*2)*2)
	var buckets: Dictionary = {}; var touched: Dictionary = {}; var damage_cuts: Dictionary = {}
	for body in bodies.duplicate():
		for part: PartInstance in body.graph.parts.values():
			var p: DVec3 = body.part_world_position(part)
			var cell := Vector3i(floori(p.x/cell_size),floori(p.y/cell_size),floori(p.z/cell_size))
			var entry := {"body":body,"part":part,"position":p,"basis":Basis(body.orientation*part.orientation),"half":part.definition.half_extents(),"box":not part.definition.box_size.is_empty()}
			for dx in range(-1,2):
				for dy in range(-1,2):
					for dz in range(-1,2):
						for other in buckets.get(cell+Vector3i(dx,dy,dz),[]):
							if other.body == body: continue
							var collision := overlap(other,entry)
							if collision.is_empty(): continue
							resolve(other,entry,collision,dt,damage_cuts)
							touched[other.body] = true; touched[body] = true
			if not buckets.has(cell): buckets[cell] = []
			buckets[cell].append(entry)
	for body in touched:
		var cuts: Array = damage_cuts.get(body,[])
		if body.structural_failure_enabled:
			for edge_id in body.structure.evaluate(body,body.last_angular_acceleration):
				if not edge_id in cuts: cuts.append(edge_id)
		if not cuts.is_empty(): body.record_failure(cuts); body.split_connections(cuts)
		body.refresh_structure(false)
		if not body.control_available and body.was_commanded:
			body.crashed = true; body.throttle = 0

static func overlap(a: Dictionary, b: Dictionary) -> Dictionary:
	var delta: Vector3 = b.position.minus(a.position).vec()
	var axes: Array[Vector3] = [a.basis.x,a.basis.y,a.basis.z,b.basis.x,b.basis.y,b.basis.z]
	for up: Vector3 in [a.basis.y,b.basis.y]:
		var radial: Vector3 = delta.slide(up)
		if radial.length_squared() > 1e-8: axes.append(radial.normalized())
	for x: Vector3 in [a.basis.x,a.basis.y,a.basis.z]:
		for y: Vector3 in [b.basis.x,b.basis.y,b.basis.z]:
			if x.cross(y).length_squared() > 1e-8: axes.append(x.cross(y).normalized())
	var depth: float = INF; var normal := Vector3.ZERO
	for axis in axes:
		var ay: float = clampf(absf(axis.dot(a.basis.y)),0,1)
		var by: float = clampf(absf(axis.dot(b.basis.y)),0,1)
		# Cylindrical supports avoid treating empty corners as radial collisions.
		var ra: float = absf(axis.dot(a.basis.x))*a.half.x+ay*a.half.y+absf(axis.dot(a.basis.z))*a.half.z if a.get("box",false) else ay*a.half.y+sqrt(maxf(0,1-ay*ay))*a.half.x
		var rb: float = absf(axis.dot(b.basis.x))*b.half.x+by*b.half.y+absf(axis.dot(b.basis.z))*b.half.z if b.get("box",false) else by*b.half.y+sqrt(maxf(0,1-by*by))*b.half.x
		var separation: float = delta.dot(axis)
		var penetration: float = ra+rb-absf(separation)
		if penetration <= 0.0001: return {}
		if penetration < depth:
			depth = penetration; normal = axis*(1.0 if separation >= 0 else -1.0)
	return {"normal":DVector.from_vec(normal),"depth":depth,"point":a.position.plus(b.position).scaled(0.5)}

static func resolve(a: Dictionary, b: Dictionary, hit: Dictionary, dt: float, cuts: Dictionary) -> void:
	var normal: DVec3 = hit.normal
	var arm_a: DVec3 = hit.point.minus(a.body.position).rotated(a.body.orientation.inverse())
	var arm_b: DVec3 = hit.point.minus(b.body.position).rotated(b.body.orientation.inverse())
	var va: DVec3 = a.body.velocity.plus(DVector.from_vec(a.body.angular_velocity).cross(arm_a).rotated(a.body.orientation))
	var vb: DVec3 = b.body.velocity.plus(DVector.from_vec(b.body.angular_velocity).cross(arm_b).rotated(b.body.orientation))
	var closing: float = vb.minus(va).dot(normal)
	var na := normal.rotated(a.body.orientation.inverse()); var nb := normal.rotated(b.body.orientation.inverse())
	var ca := arm_a.cross(na); var cb := arm_b.cross(nb)
	var k: float = 1/a.body.mass+1/b.body.mass+ca.dot(a.body.properties.tensor.solve(ca))+cb.dot(b.body.properties.tensor.solve(cb))
	var magnitude: float = maxf(0,-closing*1.05/k)
	for entry in [a,b]:
		var sign_value: float = -1 if entry == a else 1
		var impulse := normal.scaled(magnitude*sign_value)
		var local_impulse := impulse.rotated(entry.body.orientation.inverse())
		var arm: DVec3 = arm_a if entry == a else arm_b
		var dw: DVec3 = entry.body.properties.tensor.solve(arm.cross(local_impulse))
		entry.body.velocity = entry.body.velocity.plus(impulse.scaled(1/entry.body.mass))
		entry.body.angular_velocity += dw.vec()
		entry.body.acceleration = entry.body.acceleration.plus(impulse.scaled(1/entry.body.mass/dt))
		entry.body.last_angular_acceleration += dw.vec()/dt
		entry.part.force = entry.part.force.plus(local_impulse.scaled(1/dt))
		entry.part.transient_contact_force = true
		var part_arm: DVec3 = hit.point.minus(entry.body.part_world_position(entry.part)).rotated(entry.body.orientation.inverse())
		entry.part.moment = entry.part.moment.plus(part_arm.cross(local_impulse).scaled(1/dt))
		if -closing > entry.part.definition.crash_speed and not entry.part.destroyed:
			entry.part.destroyed = true; entry.part.damage = 1
			if not cuts.has(entry.body): cuts[entry.body] = []
			for edge in entry.body.graph.adjacency[entry.part.id]:
				if not edge.id in cuts[entry.body]: cuts[entry.body].append(edge.id)
			entry.body.events.append({"type":"impact","position":hit.point,"energy":0.5*entry.part.mass()*closing*closing,"fuelled":entry.part.modules.has("tank")})
	var correction: float = minf(hit.depth*0.5,1.0)/(1/a.body.mass+1/b.body.mass)
	a.body.position = a.body.position.minus(normal.scaled(correction/a.body.mass))
	b.body.position = b.body.position.plus(normal.scaled(correction/b.body.mass))

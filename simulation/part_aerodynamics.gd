class_name PartAerodynamics
extends RefCounted
## Direction-binned upstream shielding. One sort + spatial cells on cache invalidation.
var graph_version: int = -1
var flow_direction := Vector3.ZERO
var exposures: Dictionary = {}
var was_in_air: bool = false

func rebuild(graph: PartGraph, flow: Vector3) -> void:
	if graph_version == graph.version and flow.dot(flow_direction) > 0.995: return
	graph_version = graph.version; flow_direction = flow
	var reference := Vector3.RIGHT if absf(flow.x) < 0.8 else Vector3.UP
	var u: Vector3 = flow.cross(reference).normalized()
	var v: Vector3 = flow.cross(u).normalized()
	var ordered: Array = graph.parts.values()
	ordered.sort_custom(func(a,b): return a.position.vec().dot(flow) > b.position.vec().dot(flow))
	var cells: Dictionary = {}
	exposures.clear()
	for part: PartInstance in ordered:
		var p: Vector3 = part.position.vec()
		var key := Vector2i(roundi(p.dot(u)/3.0),roundi(p.dot(v)/3.0))
		var exposed: float = 1.0
		for dx in range(-1,2):
			for dy in range(-1,2):
				var candidate = cells.get(key+Vector2i(dx,dy))
				if candidate == null: continue
				var delta: Vector3 = p-candidate.position.vec()
				if delta.slide(flow).length() < candidate.definition.radius*0.95:
					exposed = minf(exposed,maxf(0.05,1.0-pow(candidate.definition.radius/part.definition.radius,2)))
		exposures[part.id] = exposed
		if not cells.has(key): cells[key] = part

func evaluate(craft: RocketState, position: DVec3, velocity: DVec3, planet: PlanetDefinition, record: bool) -> Dictionary:
	var air := velocity.minus(PlanetPhysics.air_velocity(position,planet))
	var local_air := air.rotated(craft.orientation.inverse())
	var rho: float = PlanetPhysics.density(position.length()-planet.radius,planet.atmosphere)
	var force := DVec3.new(); var torque := DVec3.new(); var damping := Vector3.ZERO
	if rho <= 0:
		if record and was_in_air:
			for part: PartInstance in craft.graph.parts.values():
				part.aero_force = DVec3.new(); part.aero_moment = DVec3.new(); part.air_damping = Vector3.ZERO
		if record: was_in_air = false
		return {"force":force,"torque":torque,"damping":damping}
	if record: was_in_air = true
	var flow: Vector3 = local_air.unit().vec()
	if flow.length_squared() < 0.1: flow = Vector3.UP
	rebuild(craft.graph,flow)
	var omega := DVector.from_vec(craft.angular_velocity)
	for part: PartInstance in craft.graph.parts.values():
		var d: PartDefinition = part.definition
		var ax: float = part.position.x-craft.properties.center.x
		var ay: float = part.position.y-craft.properties.center.y
		var az: float = part.position.z-craft.properties.center.z
		var vx: float = local_air.x+omega.y*az-omega.z*ay
		var vy: float = local_air.y+omega.z*ax-omega.x*az
		var vz: float = local_air.z+omega.x*ay-omega.y*ax
		var speed: float = sqrt(vx*vx+vy*vy+vz*vz)
		var alignment: float = (part.axis.x*vx+part.axis.y*vy+part.axis.z*vz)/maxf(speed,1e-30)
		var effective_area: float = d.drag_coefficient*PI*d.radius*d.radius*exposures.get(part.id,1.0)*alignment*alignment+d.side_drag_coefficient*2*d.radius*d.length*(1-alignment*alignment)
		if part.has_module("parachute") and part.modules.parachute.deployed:
			effective_area += part.modules.parachute.config.get("area",100.0)*1.4*part.modules.parachute.deployment_fraction
		var exposed_air: float = 1.0-part.submerged
		var factor: float = -0.5*rho*maxf(0,effective_area)*exposed_air*speed
		var drag := DVec3.new(vx*factor,vy*factor,vz*factor)
		var cp := part.pressure_center
		var transverse: float = 0.5*rho*speed*d.side_drag_coefficient*(2*d.radius*d.length)*d.length*d.length/12.0
		var roll: float = 0.5*rho*speed*d.drag_coefficient*PI*pow(d.radius,4)
		var damp := Vector3(transverse,roll,transverse)*exposed_air
		if part.has_module("fin"):
			var normal := DVec3.new(1,0,0).rotated(part.orientation)
			var direction := DVec3.new(vx,vy,vz).unit()
			var cl: float = clampf(2.0*(sin(part.modules.fin.deflection)-direction.dot(normal)),-1.2,1.2)
			var lift_direction := normal.minus(direction.scaled(direction.dot(normal))).unit()
			var q_area: float = 0.5*rho*speed*speed*part.modules.fin.config.get("area",1.0)*exposed_air
			var lift := lift_direction.scaled(q_area*cl)
			drag = drag.plus(lift).minus(direction.scaled(q_area*0.12*cl*cl))
		var moment := cp.cross(drag)
		force.x += drag.x; force.y += drag.y; force.z += drag.z
		torque.x += ay*drag.z-az*drag.y+moment.x
		torque.y += az*drag.x-ax*drag.z+moment.y
		torque.z += ax*drag.y-ay*drag.x+moment.z
		damping += damp
		if record:
			part.aero_force = drag; part.aero_moment = moment; part.air_damping = damp
			part.shielding = exposures.get(part.id,1.0)
	return {"force":force.rotated(craft.orientation),"torque":torque,"damping":damping}

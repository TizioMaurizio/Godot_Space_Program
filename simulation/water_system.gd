class_name WaterSystem
extends RefCounted
## Buoyancy integrates clipped sample volumes; drag uses a dissipative implicit step.

static func ensure_samples(part: PartInstance) -> void:
	if not part.volume_samples.is_empty(): return
	var d: PartDefinition = part.definition
	var total: float = 0
	for slice in range(8):
		var fraction: float = (slice+0.5)/8.0
		var radius: float = d.radius
		if d.visual == "capsule": radius = lerpf(d.radius,0.5 if d.modules.has("command") else 0.05,fraction)
		var weight: float = radius*radius
		for ring in range(7):
			var angle: float = (ring-1)*TAU/6.0
			var radial: float = radius*sqrt(7.0/12.0) if ring > 0 else 0.0
			part.volume_samples.append({"point":DVec3.new(cos(angle)*radial,(fraction-0.5)*d.length,sin(angle)*radial).rotated(part.orientation),"weight":weight})
			total += weight
	for sample in part.volume_samples: sample.weight /= total

static func evaluate(craft: RocketState, position: DVec3, velocity: DVec3, planet: PlanetDefinition, time: float, dt: float, record: bool) -> Dictionary:
	var force := DVec3.new(); var torque := DVec3.new(); var damping := Vector3.ZERO
	var result := {"force":force,"torque":torque,"damping":damping,"wet":false}
	if planet.ocean == null or position.length()-planet.radius > (craft.properties.maximum-craft.properties.minimum).length()+planet.ocean.sea_level+2:
		if record and craft.water_contact:
			for part: PartInstance in craft.graph.parts.values():
				part.submerged = 0; part.fluid_force = DVec3.new(); part.fluid_moment = DVec3.new(); part.fluid_damping = Vector3.ZERO
		return result
	var omega := DVector.from_vec(craft.angular_velocity)
	for part: PartInstance in craft.graph.parts.values():
		var arm := part.position.minus(craft.properties.center)
		var point := position.plus(arm.rotated(craft.orientation))
		var ground: float = SurfaceQuery.height(planet,point,time)
		if ground >= planet.ocean.sea_level:
			if record: part.submerged = 0; part.fluid_force = DVec3.new(); part.fluid_moment = DVec3.new(); part.fluid_damping = Vector3.ZERO
			continue
		var up := point.unit(); var local_up := up.rotated(craft.orientation.inverse())
		var surface: float = SurfaceQuery.water_radius(planet,point,time)
		var center_depth: float = surface-point.length()
		var support: float = ContactSolver.support(part,local_up)
		if center_depth < -support-0.5:
			if record: part.submerged = 0; part.fluid_force = DVec3.new(); part.fluid_moment = DVec3.new(); part.fluid_damping = Vector3.ZERO
			continue
		ensure_samples(part)
		var fraction: float = 0; var centroid := DVec3.new()
		var axis := DVec3.new(0,1,0).rotated(part.orientation)
		var cell_half: float = maxf(0.05,absf(axis.dot(local_up))*part.definition.length/16.0+sqrt(maxf(0,1-pow(axis.dot(local_up),2)))*part.definition.radius*0.35)
		for sample in part.volume_samples:
			var depth: float = center_depth-sample.point.dot(local_up)
			var filled: float = clampf(0.5+depth/(2*cell_half),0,1)
			var weight: float = sample.weight*filled
			fraction += weight
			centroid = centroid.plus(sample.point.minus(local_up.scaled(cell_half*(1-filled)*0.5)).scaled(weight))
		if fraction <= 0:
			if record: part.submerged = 0; part.fluid_force = DVec3.new(); part.fluid_moment = DVec3.new(); part.fluid_damping = Vector3.ZERO
			continue
		result.wet = true
		centroid = centroid.scaled(1/fraction)
		var volume: float = part.definition.volume()
		if part.destroyed: volume = part.definition.dry_mass/7800.0+(part.mass()-part.definition.dry_mass)/1000.0
		var g: float = PlanetPhysics.gravity(point,planet).length()
		var buoyancy := local_up.scaled(planet.ocean.density*volume*fraction*g)
		var wave_speed: float = SurfaceQuery.wave_velocity(planet,SurfaceQuery.to_fixed(point,planet,time),time)
		var fluid_velocity := PlanetPhysics.air_velocity(point,planet).plus(up.scaled(wave_speed))
		var relative := velocity.minus(fluid_velocity).rotated(craft.orientation.inverse()).plus(omega.cross(arm))
		var speed: float = relative.length()
		var alignment: float = absf(axis.dot(relative.unit()))
		var area: float = (PI*part.definition.radius*part.definition.radius*alignment+2*part.definition.radius*part.definition.length*sqrt(maxf(0,1-alignment*alignment)))*pow(fraction,2.0/3.0)
		var coefficient: float = 0.5*planet.ocean.density*planet.ocean.drag_coefficient*area
		var drag := relative.scaled(-coefficient*speed/(1+coefficient*speed*dt/maxf(part.mass(),1)))
		var f := buoyancy.plus(drag)
		var moment := centroid.cross(buoyancy)
		var rotational: float = planet.ocean.density*volume*fraction*(0.3+0.1*speed)
		var angular_damp := Vector3.ONE*rotational*maxf(0.2,part.definition.radius*part.definition.radius)
		force = force.plus(f)
		torque = torque.plus(arm.cross(f)).plus(moment)
		damping += angular_damp
		if record:
			var entry_speed: float = maxf(0,-relative.dot(local_up))
			if part.submerged < 0.001 and fraction >= 0.001:
				craft.events.append({"type":"water","position":point.unit().scaled(surface),"normal":up,"energy":0.5*part.mass()*entry_speed*entry_speed,"speed":entry_speed})
				if entry_speed > part.definition.crash_speed and not part.destroyed:
					part.destroyed = true; part.damage = 1
					craft.damage_dirty = true
					for edge in craft.graph.adjacency[part.id]:
						if not edge.id in craft.pending_water_cuts: craft.pending_water_cuts.append(edge.id)
			part.submerged = fraction; part.fluid_force = f; part.fluid_moment = moment; part.fluid_damping = angular_damp
	result.force = force.rotated(craft.orientation); result.torque = torque; result.damping = damping
	return result

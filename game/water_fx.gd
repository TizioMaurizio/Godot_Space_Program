class_name WaterFX
extends Node3D
## Short-lived world-anchored foam and ballistic spray; driven by wet part state.
var particles: Array = []
var timer: float = 0
var seed_index: int = 0

func reset_effects() -> void:
	for p in particles: p.node.queue_free()
	particles.clear(); timer = 0

func emit(position: DVec3, velocity: DVec3, up: DVec3, size: float, spray: bool) -> void:
	if particles.size() >= 180: return
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new(); sphere.radius = 0.5; sphere.height = 1; sphere.radial_segments = 8; sphere.rings = 4
	node.mesh = sphere
	var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color = Color(0.68,0.88,0.91,0.6)
	node.material_override = material; add_child(node)
	node.quaternion = AttitudeController.pointing(up.vec(),Quaternion.IDENTITY)
	particles.append({"node":node,"position":position,"velocity":velocity,"up":up,"size":size,"age":0.0,"spray":spray})

func update_water(craft: RocketState, planet: PlanetDefinition, dt: float) -> void:
	timer += dt
	if planet.ocean != null and timer >= 0.08:
		timer = 0
		for part: PartInstance in craft.graph.parts.values():
			if part.submerged <= 0 or part.submerged >= 0.99: continue
			var point := craft.part_world_position(part); var up := point.unit()
			var sea: float = SurfaceQuery.water_radius(planet,point,craft.elapsed)
			var relative := craft.velocity.minus(PlanetPhysics.air_velocity(point,planet))
			var tangent := DVec3.new(0,0,1).cross(up).unit()
			if tangent.length_squared() < 0.1: tangent = DVec3.new(1,0,0).cross(up).unit()
			var side := up.cross(tangent)
			seed_index += 1; var angle: float = seed_index*2.399963
			var radial := tangent.scaled(cos(angle)).plus(side.scaled(sin(angle)))
			var source := up.scaled(sea+0.08).plus(radial.scaled(part.definition.radius*0.7))
			emit(source,PlanetPhysics.air_velocity(source,planet).plus(relative.scaled(0.12)),up,0.5+relative.length()*0.025,false)
			if relative.length() > 2:
				emit(source,PlanetPhysics.air_velocity(source,planet).plus(radial.scaled(minf(relative.length()*0.2,5))).plus(up.scaled(minf(relative.length()*0.3,8))),up,0.12,true)
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]; p.age += dt
		if p.spray: p.velocity = p.velocity.minus(p.up.scaled(planet.surface_gravity*dt))
		p.position = p.position.plus(p.velocity.scaled(dt))
		p.node.position = p.position.minus(craft.position).vec()
		p.node.scale = (Vector3.ONE if p.spray else Vector3(1,0.035,1))*p.size*(1+p.age)
		p.node.material_override.albedo_color.a = maxf(0,0.6-p.age*0.22)
		if p.age > (1.5 if p.spray else 2.7): p.node.queue_free(); particles.remove_at(i)

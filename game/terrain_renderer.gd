class_name TerrainRenderer
extends Node3D
## Curved spherical clipmap tiles. Near geometry/collision share SurfaceQuery.

var planet: PlanetDefinition
var tiles: Array = []
var queue: Array = []
var focus := DVec3.new(0,1,0)
var east := DVec3.new(-1,0,0)
var north := DVec3.new(0,0,1)
var terrain_material: ShaderMaterial
var anchor_epoch: float = 0
var last_focus_position := DVec3.new()

func setup(config: PlanetDefinition) -> void:
	planet = config
	terrain_material = ShaderMaterial.new(); terrain_material.shader = load("res://shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("lunar",planet.terrain != null and planet.terrain.style == "lunar")
	request_tiles(DVec3.new(0,planet.radius,0),0)
	for i in range(4): create_next()

func request_tiles(position: DVec3, time: float) -> void:
	focus = SurfaceQuery.to_fixed(position.unit(),planet,time)
	east = DVec3.new(0,0,1).cross(focus).unit()
	if east.length_squared() < 0.1: east = DVec3.new(1,0,0).cross(focus).unit()
	north = focus.cross(east).unit()
	last_focus_position = focus.scaled(planet.radius)
	queue.clear()
	# Nested rings, no overlapping interiors. Finest cells are four metres.
	for level in range(8):
		var size: float = 64.0*pow(2,level)
		for y in range(-2,2):
			for x in range(-2,2):
				if level > 0 and x in [-1,0] and y in [-1,0]: continue
				queue.append({"origin":Vector2(x*size,y*size),"size":size,"level":level})
	queue.sort_custom(func(a,b):
		if a.level != b.level: return a.level < b.level
		return (a.origin+Vector2.ONE*a.size*0.5).length_squared() < (b.origin+Vector2.ONE*b.size*0.5).length_squared())
	for item in tiles: item.node.queue_free()
	tiles.clear()

func create_next() -> void:
	if queue.is_empty(): return
	var item: Dictionary = queue.pop_front()
	for water in [false,true] if planet.ocean != null else [false]:
		var built := TerrainMesher.tile(planet,focus,east,north,item.origin,item.size,water)
		var mesh := MeshInstance3D.new(); mesh.mesh = built.mesh
		if water:
			var material := ShaderMaterial.new(); material.shader = load("res://shaders/ocean.gdshader")
			mesh.material_override = material
		else: mesh.material_override = terrain_material
		add_child(mesh)
		tiles.append({"node":mesh,"anchor":built.anchor,"water":water,"level":item.level})

func update_terrain(position: DVec3, time: float, underwater: bool) -> void:
	PlanetLayers.update_surface(terrain_material,planet,time)
	var altitude: float = position.length()-planet.radius
	visible = altitude < 70000
	if not visible: return
	var fixed := SurfaceQuery.to_fixed(position.unit(),planet,time).scaled(planet.radius)
	if fixed.minus(last_focus_position).length() > maxf(96,altitude*0.2): request_tiles(position,time)
	for i in range(2): create_next()
	var q := SurfaceQuery.rotation(planet,time)
	for item in tiles:
		item.node.position = SurfaceQuery.to_inertial(item.anchor,planet,time).minus(position).vec()
		item.node.quaternion = q
		if item.water:
			var k: float = TAU/planet.ocean.wavelength
			item.node.material_override.set_shader_parameter("wave_phase",Vector3(fposmod(item.anchor.x*k+time*0.9,TAU),fposmod(item.anchor.z*k*1.43-time*1.3,TAU),fposmod(item.anchor.y*k*0.71+time*0.6,TAU)))
			item.node.material_override.set_shader_parameter("amplitude",planet.ocean.wave_amplitude)
			item.node.material_override.set_shader_parameter("wave_number",k)
			item.node.material_override.set_shader_parameter("underwater",underwater)
			item.node.material_override.set_shader_parameter("sun_local",SurfaceQuery.to_fixed(DVector.from_vec(PlanetLayers.SUN),planet,time).vec())

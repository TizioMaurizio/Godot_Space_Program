class_name WorldVisual
extends Node3D
## Two depth ranges: distant scaled planet in a background viewport, local craft in metres.

var background: SubViewport
var background_camera: Camera3D
var sky_material: ShaderMaterial
var pad := Node3D.new()
var local_ground: MeshInstance3D
var planet_mesh: MeshInstance3D
var planet: PlanetDefinition
var terrain_renderer := TerrainRenderer.new()
var ocean_mesh: MeshInstance3D
var ocean_material: ShaderMaterial
var local_environment: Environment
var underwater: bool = false
var layers := PlanetLayers.new()
var moon_meshes: Dictionary = {}
var local_sun: DirectionalLight3D

func setup(config: PlanetDefinition, compositor: Node) -> void:
	planet = config
	get_viewport().transparent_bg = true
	background = SubViewport.new()
	background.size = Vector2i(1440, 900)
	background.own_world_3d = true
	background.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	compositor.add_child(background)
	var backdrop := CanvasLayer.new()
	backdrop.layer = -10
	compositor.add_child(backdrop)
	var texture := TextureRect.new()
	texture.texture = background.get_texture()
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(texture)
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8eaec3")
	env.ambient_light_energy = 0.65
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	background.add_child(world_env)
	var local_env := WorldEnvironment.new()
	local_env.environment = Environment.new()
	local_env.environment.background_mode = Environment.BG_COLOR
	local_env.environment.background_color = Color(0, 0, 0, 0)
	local_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	local_env.environment.ambient_light_color = Color("a5c5d5")
	local_env.environment.ambient_light_energy = 0.6
	local_environment = local_env.environment
	add_child(local_env)
	for parent in [self, background]:
		var light := DirectionalLight3D.new()
		light.light_energy = 1.5
		parent.add_child(light)
		if parent == self: local_sun = light
		light.look_at(-Vector3(-0.5, 0.7, 0.6).normalized(), Vector3.UP)
	planet_mesh = MeshInstance3D.new()
	planet_mesh.mesh = TerrainMesher.globe(planet,48,0.001)
	var planet_mat := ShaderMaterial.new()
	planet_mat.shader = load("res://shaders/terrain.gdshader")
	planet_mesh.material_override = planet_mat
	background.add_child(planet_mesh)
	background.add_child(layers); layers.setup(planet,0.001)
	if planet.ocean != null:
		ocean_mesh = MeshInstance3D.new()
		var sea := SphereMesh.new(); sea.radius = (planet.radius+planet.ocean.sea_level)*0.001; sea.height = sea.radius*2
		sea.radial_segments = 512; sea.rings = 256; ocean_mesh.mesh = sea
		ocean_material = ShaderMaterial.new(); ocean_material.shader = load("res://shaders/ocean.gdshader")
		ocean_material.set_shader_parameter("render_scale",0.001)
		ocean_mesh.material_override = ocean_material; background.add_child(ocean_mesh)
	background_camera = Camera3D.new()
	background_camera.near = 0.001
	background_camera.far = 20000.0
	background.add_child(background_camera)
	add_child(pad)
	add_child(terrain_renderer)
	terrain_renderer.setup(planet)
	var foundation := RocketVisual.cylinder(pad, 18.0, 18.0, 0.6, 0.3, RocketVisual.material(Color("253440")))
	foundation.name = "LaunchDeck"
	RocketVisual.cylinder(pad, 8.0, 8.0, 0.15, 0.68, RocketVisual.material(Color("71858a")))
	RocketVisual.cylinder(pad, 3.8, 3.8, 0.17, 0.78, RocketVisual.material(Color("b18e5c")))
	for n in range(8):
		var beacon := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.2, 2.0)
		beacon.mesh = box
		beacon.material_override = RocketVisual.material(Color("f8c279"))
		beacon.position = Vector3(sin(n * TAU / 8.0) * 15, 0.65, cos(n * TAU / 8.0) * 15)
		beacon.rotation.y = n * TAU / 8.0
		pad.add_child(beacon)

func update_world(rocket: RocketState, camera: OrbitCamera) -> void:
	var local_planet: PlanetDefinition = rocket.reference_body
	var local_position := rocket.relative_position()
	var projection: float = local_position.dot(DVector.from_vec(PlanetLayers.SUN))
	var lit: bool = projection >= 0 or local_position.length_squared()-projection*projection > local_planet.radius*local_planet.radius
	local_sun.light_energy = 1.5 if lit else 0.0
	local_environment.ambient_light_energy = 0.6 if lit else 0.12
	var altitude: float = local_position.length() - local_planet.radius
	var camera_world := local_position.plus(DVector.from_vec(camera.position))
	var ground_radius: float = local_planet.radius+SurfaceQuery.height(local_planet,camera_world,rocket.elapsed)
	if camera_world.length() < ground_radius+0.5:
		camera.position += camera_world.unit().vec()*(ground_radius+0.5-camera_world.length())
		camera.look_at(Vector3.ZERO,local_position.unit().vec())
		camera_world = local_position.plus(DVector.from_vec(camera.position))
	underwater = local_planet.ocean != null and camera_world.length() < SurfaceQuery.water_radius(local_planet,camera_world,rocket.elapsed)
	local_environment.fog_enabled = underwater
	local_environment.fog_light_color = Color("126c80")
	local_environment.fog_density = 0.055 if underwater else 0
	sky_material.set_shader_parameter("underwater",underwater)
	sky_material.set_shader_parameter("local_up",camera_world.unit().vec())
	layers.update_layers(rocket.elapsed)
	PlanetLayers.update_surface(planet_mesh.material_override,planet,rocket.elapsed)
	if terrain_renderer.planet != local_planet: terrain_renderer.setup(local_planet)
	terrain_renderer.update_terrain(local_position,rocket.elapsed,underwater)
	sky_material.set_shader_parameter("air", exp(-maxf(altitude, 0.0) / 14000.0) if local_planet.atmosphere.height > 0 else 0.0)
	if rocket.celestial != null:
		for moon in rocket.celestial.moons:
			if not moon_meshes.has(moon.body_id):
				var mesh := MeshInstance3D.new(); mesh.mesh = TerrainMesher.globe(moon,48,0.001)
				var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/terrain.gdshader"); mat.set_shader_parameter("lunar",true)
				mesh.material_override = mat; background.add_child(mesh); moon_meshes[moon.body_id] = mesh
			var mesh: MeshInstance3D = moon_meshes[moon.body_id]
			mesh.position = rocket.celestial.ephemeris(moon,rocket.elapsed).position.scaled(0.001).vec()
			mesh.quaternion = SurfaceQuery.rotation(moon,rocket.elapsed)
			PlanetLayers.update_surface(mesh.material_override,moon,rocket.elapsed)
	background_camera.position = rocket.position.scaled(0.001).vec() + camera.position * 0.001
	background_camera.basis = camera.basis
	background_camera.h_offset = camera.h_offset * 0.001
	background_camera.fov = camera.fov
	# Keep the distant depth range proportional to altitude; a millimetre near
	# plane in orbit otherwise wastes nearly all precision in standard OpenGL.
	background_camera.near = maxf(0.001, altitude * 0.0001)
	background_camera.far = maxf(2000.0, rocket.position.length() * 0.002)
	var viewport_size: Vector2i = Vector2i(get_viewport().get_visible_rect().size)
	if background.size != viewport_size:
		background.size = viewport_size
	var angle: float = planet.rotation_rate * rocket.elapsed
	var launch_radius: float = planet.radius+SurfaceQuery.height_fixed(planet,DVec3.new(0,1,0))
	var launch_position := SurfaceQuery.to_inertial(DVec3.new(0,launch_radius,0),planet,rocket.elapsed)
	pad.position = launch_position.minus(rocket.position).vec()
	pad.basis = Basis(SurfaceQuery.rotation(planet,rocket.elapsed))
	pad.visible = pad.position.length() < 60000.0
	planet_mesh.quaternion = SurfaceQuery.rotation(planet,rocket.elapsed)
	if ocean_mesh != null:
		ocean_mesh.quaternion = planet_mesh.quaternion
		ocean_material.set_shader_parameter("wave_phase",Vector3(fposmod(rocket.elapsed*0.9,TAU),fposmod(-rocket.elapsed*1.3,TAU),fposmod(rocket.elapsed*0.6,TAU)))
		ocean_material.set_shader_parameter("amplitude",planet.ocean.wave_amplitude)
		ocean_material.set_shader_parameter("wave_number",TAU/planet.ocean.wavelength)
		ocean_material.set_shader_parameter("underwater",underwater)
		ocean_material.set_shader_parameter("sun_local",SurfaceQuery.to_fixed(DVector.from_vec(PlanetLayers.SUN),planet,rocket.elapsed).vec())

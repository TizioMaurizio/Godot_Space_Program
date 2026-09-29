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
	add_child(local_env)
	for parent in [self, background]:
		var light := DirectionalLight3D.new()
		light.light_energy = 1.5
		parent.add_child(light)
		light.look_at(-Vector3(-0.5, 0.7, 0.6).normalized(), Vector3.UP)
	planet_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = planet.radius * 0.001
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 512
	sphere.rings = 256
	planet_mesh.mesh = sphere
	var planet_mat := ShaderMaterial.new()
	planet_mat.shader = load("res://shaders/planet.gdshader")
	planet_mesh.material_override = planet_mat
	background.add_child(planet_mesh)
	background_camera = Camera3D.new()
	background_camera.near = 0.001
	background_camera.far = 20000.0
	background.add_child(background_camera)
	add_child(pad)
	local_ground = MeshInstance3D.new()
	# Local tangent surface is visual only; collision is evaluated against planet radius.
	var ground := PlaneMesh.new()
	ground.size = Vector2(20000, 20000)
	local_ground.mesh = ground
	local_ground.material_override = RocketVisual.material(Color("34494a"))
	pad.add_child(local_ground)
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
	var altitude: float = rocket.position.length() - planet.radius
	sky_material.set_shader_parameter("air", exp(-maxf(altitude, 0.0) / 14000.0))
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
	var launch_position := DVec3.new(-sin(angle) * planet.radius, cos(angle) * planet.radius, 0)
	pad.position = launch_position.minus(rocket.position).vec()
	pad.basis = Basis(Quaternion(Vector3.BACK, angle))
	pad.visible = pad.position.length() < 60000.0
	local_ground.visible = altitude < 2500.0
	planet_mesh.rotation.z = angle

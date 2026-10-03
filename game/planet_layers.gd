class_name PlanetLayers
extends Node3D
const SUN := ElectricPower.SUN
var planet: PlanetDefinition
var shells: Array[MeshInstance3D] = []

func setup(config: PlanetDefinition, scale_factor: float) -> void:
	planet = config
	if planet.atmosphere == null or planet.atmosphere.height <= 0: return
	for layer in range(3):
		var mesh := MeshInstance3D.new(); var sphere := SphereMesh.new()
		var height: float = [4500.0,8500.0,14000.0][layer]
		sphere.radius = (planet.radius+height)*scale_factor; sphere.height = sphere.radius*2
		sphere.radial_segments = 128; sphere.rings = 64; mesh.mesh = sphere
		var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/atmosphere.gdshader" if layer == 2 else "res://shaders/clouds.gdshader")
		if layer < 2: mat.set_shader_parameter("coverage",0.8 if layer == 0 else 0.3)
		mesh.material_override = mat; add_child(mesh); shells.append(mesh)

func update_layers(time: float) -> void:
	quaternion = SurfaceQuery.rotation(planet,time)
	var sun := SurfaceQuery.to_fixed(DVector.from_vec(SUN),planet,time).vec()
	for i in range(shells.size()):
		shells[i].material_override.set_shader_parameter("sun_local",sun)
		if i < 2: shells[i].material_override.set_shader_parameter("cloud_phase",fposmod(time*0.000015,TAU)+i*0.08)

static func update_surface(material: ShaderMaterial, config: PlanetDefinition, time: float) -> void:
	material.set_shader_parameter("sun_local",SurfaceQuery.to_fixed(DVector.from_vec(SUN),config,time).vec())
	material.set_shader_parameter("cloud_phase",fposmod(time*0.000015,TAU))

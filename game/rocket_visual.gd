class_name RocketVisual
extends Node3D

var exhaust: MeshInstance3D
var stage_index: int = -1
var body_length: float = 26.0

static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.6
	return mat

static func cylinder(parent: Node3D, bottom: float, top: float, height: float, y: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 48
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position.y = y
	parent.add_child(node)
	return node

func rebuild(rocket: RocketState) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	stage_index = rocket.stage_index
	body_length = rocket.length
	var white := material(Color("e2e8e9"), 0.25)
	var dark := material(Color("182c39"), 0.65)
	var orange := material(Color("ed9157"), 0.25)
	var y: float = -body_length * 0.5
	for i in range(rocket.stage_index, rocket.stages.size()):
		var stage: StageDefinition = rocket.stages[i].definition
		cylinder(self, stage.radius, stage.radius, stage.length - 0.8, y + stage.length * 0.5 + 0.4, white)
		cylinder(self, stage.radius * 1.025, stage.radius * 1.025, 0.45, y + stage.length - 0.3, orange)
		cylinder(self, 0.95, 0.45, 1.0, y + 0.4, dark)
		cylinder(self, stage.radius * 1.015, stage.radius * 1.015, 0.75, y + 1.4, dark)
		for n in range(4):
			var strip := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.12, stage.length * 0.6, 0.12)
			strip.mesh = box
			strip.material_override = dark
			strip.position = Vector3(sin(n * PI / 2) * stage.radius, y + stage.length * 0.52, cos(n * PI / 2) * stage.radius)
			add_child(strip)
		y += stage.length
	cylinder(self, 1.5, 0.5, rocket.definition.payload_length - 0.7, y + 1.65, white)
	cylinder(self, 0.5, 0.05, 0.7, y + rocket.definition.payload_length - 0.35, dark)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.4, 0.8, 1.0, 0.85)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.65, 1.0)
	exhaust = cylinder(self, 0.08, 0.8, 9.0, -body_length * 0.5 - 4.5, glow)
	exhaust.visible = false

func update_exhaust(thrust: float, maximum: float, time: float) -> void:
	if not is_instance_valid(exhaust):
		return
	exhaust.visible = thrust > 1.0
	var power: float = thrust / maximum
	exhaust.scale = Vector3(0.7 + power * 0.3, power * (1.0 + 0.06 * sin(time * 47.0)), 0.7 + power * 0.3)
	exhaust.position.y = -body_length * 0.5 - 4.5 * exhaust.scale.y

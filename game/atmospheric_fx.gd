class_name AtmosphericFX
extends Node3D
## Air-relative shock glow and animated slipstream streaks. No forces live here.

var shock: MeshInstance3D
var wake: MeshInstance3D
var shock_material: ShaderMaterial
var wake_material: ShaderMaterial
var streaks: Array[MeshInstance3D] = []
var streak_material: StandardMaterial3D
var clock: float = 0.0
var heat: float = 0.0
var drag: float = 0.0

func _ready() -> void:
	shock_material = ShaderMaterial.new()
	shock_material.shader = load("res://shaders/reentry.gdshader")
	shock_material.set_shader_parameter("shock", true)
	wake_material = ShaderMaterial.new()
	wake_material.shader = shock_material.shader
	shock = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	shock.mesh = sphere
	shock.material_override = shock_material
	add_child(shock)
	wake = RocketVisual.cylinder(self, 2.8, 1.0, 1.0, 0, wake_material)
	var wake_mesh := wake.mesh as CylinderMesh
	wake_mesh.cap_top = false
	wake_mesh.cap_bottom = false
	streak_material = StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.7, 0.9, 1.0, 0.0)
	for i in range(16):
		var streak := RocketVisual.cylinder(self, 0.015, 0.075, 1.0, 0, streak_material)
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streaks.append(streak)
	visible = false

func update_effects(rocket: RocketState, delta: float, running: bool) -> void:
	var heat_target: float = rocket.heating if running and not rocket.crashed else 0.0
	var drag_target: float = smoothstep(800.0, 18000.0, rocket.dynamic_pressure) * smoothstep(180.0, 600.0, rocket.air_velocity.length())
	if rocket.crashed or rocket.on_pad or rocket.density <= 0.0:
		drag_target = 0.0
		heat_target = 0.0
	if running:
		clock += delta
		heat = lerpf(heat, heat_target, 1.0 - exp(-delta * 6.0))
		drag = lerpf(drag, drag_target, 1.0 - exp(-delta * 6.0))
	visible = heat > 0.005 or drag > 0.005
	if not visible:
		return
	var flow: Vector3 = rocket.air_velocity.unit().vec()
	quaternion = AttitudeController.pointing(flow, quaternion)
	var alignment: float = absf(flow.dot(rocket.orientation * Vector3.UP))
	var transverse: float = sqrt(maxf(0.0, 1.0 - alignment * alignment))
	var front: float = alignment * rocket.length * 0.5 + transverse * rocket.radius
	var width: float = rocket.radius * 1.15 + transverse * rocket.length * 0.36
	shock.position.y = front + 0.5
	shock.scale = Vector3(width * 1.25, maxf(0.5, width * 0.35), width * 1.25)
	var trail_length: float = rocket.length + 8.0 + heat * 22.0
	wake.scale = Vector3(width, trail_length, width)
	wake.position.y = front - trail_length * 0.5
	shock_material.set_shader_parameter("strength", heat)
	wake_material.set_shader_parameter("strength", heat * 0.6)
	shock_material.set_shader_parameter("clock", clock)
	wake_material.set_shader_parameter("clock", clock)
	streak_material.albedo_color = Color(0.7, 0.88, 1.0, drag * (1.0 - heat * 0.6) * 0.42)
	for i in range(streaks.size()):
		var angle: float = i * TAU / streaks.size()
		var phase: float = fposmod(clock * (0.8 + i * 0.037) + i * 0.618, 1.0)
		streaks[i].position = Vector3(sin(angle) * width * (1.2 + phase * 0.7), front - phase * trail_length, cos(angle) * width * (1.2 + phase * 0.7))
		streaks[i].scale = Vector3.ONE * sin(phase * PI)
		streaks[i].scale.y *= 3.0 + drag * 8.0

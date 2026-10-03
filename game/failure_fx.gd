class_name FailureFX
extends Node3D
var bursts: Array = []

func reset_effects() -> void:
	for burst in bursts: burst.node.queue_free()
	bursts.clear()

func emit_event(event: Dictionary) -> void:
	if event.type == "break": return
	var node := MeshInstance3D.new()
	var water: bool = event.type == "water"
	if water:
		var ring := TorusMesh.new(); ring.inner_radius = 0.8; ring.outer_radius = 1.0; node.mesh = ring
		node.quaternion = AttitudeController.pointing(event.normal.vec(),Quaternion.IDENTITY)
	else:
		var sphere := SphereMesh.new(); sphere.radius = 1; sphere.height = 2; node.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1,0.5,0.12,0.7) if event.get("fuelled",false) else Color(0.6,0.6,0.62,0.5)
	if water: material.albedo_color = Color(0.8,0.95,1,0.65)
	node.material_override = material
	add_child(node)
	bursts.append({"node":node,"position":event.position,"age":0.0,"size":clampf(sqrt(event.get("energy",0.0)/1000000.0),0.7,8.0),"water":water})

func update_effects(origin: DVec3, dt: float) -> void:
	for i in range(bursts.size()-1,-1,-1):
		var burst: Dictionary = bursts[i]
		burst.age += dt
		burst.node.position = burst.position.minus(origin).vec()
		burst.node.scale = (Vector3(1,0.04,1) if burst.water else Vector3.ONE)*burst.size*(0.3+burst.age)
		burst.node.material_override.albedo_color.a = maxf(0,0.6-burst.age*0.3)
		if burst.age > 2:
			burst.node.queue_free(); bursts.remove_at(i)

class_name RocketVisual
extends Node3D

var exhaust: MeshInstance3D
var stage_index: int = -1
var body_length: float = 26.0
var part_nodes: Dictionary = {}
var engine_plumes: Dictionary = {}
var craft: RocketState
var built_revision: int = -1

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
	craft = rocket
	built_revision = rocket.topology_revision
	part_nodes.clear(); engine_plumes.clear()
	stage_index = rocket.stage_index
	body_length = rocket.length
	var white := material(Color("e2e8e9"), 0.25)
	var dark := material(Color("182c39"), 0.65)
	var orange := material(Color("ed9157"), 0.25)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.4, 0.8, 1.0, 0.85)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.65, 1.0)
	for part: PartInstance in rocket.graph.parts.values():
		var node := Node3D.new()
		node.name = part.id
		node.set_meta("part_id",part.id)
		add_child(node)
		part_nodes[part.id] = node
		var d := part.definition
		if StationPartVisual.build(node,part,white,dark): continue
		match d.visual:
			"capsule": cylinder(node,d.radius,0.5 if part.has_module("command") else 0.05,d.length,0,white)
			"adapter": cylinder(node,0.6,1.5,d.length,0,dark)
			"fin":
				var mesh := MeshInstance3D.new(); var box := BoxMesh.new()
				box.size = Vector3(d.radius*2,d.length,0.12); mesh.mesh = box; mesh.material_override = orange; mesh.name = "Surface"; node.add_child(mesh)
			"leg":
				cylinder(node,0.1,0.1,d.length,0,dark)
				cylinder(node,d.radius,d.radius,0.15,-d.length*0.5+0.075,orange)
			"parachute":
				cylinder(node,d.radius,d.radius,d.length,0,orange)
				var canopy := MeshInstance3D.new(); var dome := SphereMesh.new()
				dome.radius = 4.5; dome.height = 2.0; canopy.mesh = dome; canopy.material_override = orange
				canopy.position.y = 8; canopy.name = "Canopy"; canopy.visible = false; node.add_child(canopy)
			"engine":
				cylinder(node,d.radius*0.65,d.radius*0.4,d.length,0,dark)
				var plume := cylinder(node,0.03,d.radius*0.55,9,-d.length*0.5-4.5,glow)
				plume.visible = false
				engine_plumes[part.id] = plume
			"decoupler": cylinder(node,d.radius*1.02,d.radius*1.02,d.length,0,orange)
			_:
				cylinder(node,d.radius,d.radius,d.length,0,white)
				cylinder(node,d.radius*1.01,d.radius*1.01,minf(0.25,d.length*0.1),d.length*0.35,orange)
	update_parts()

func update_parts() -> void:
	if craft == null: return
	for id in part_nodes:
		if not craft.graph.parts.has(id): continue
		var part: PartInstance = craft.graph.parts[id]
		part_nodes[id].position = part.position.minus(craft.properties.center).vec()
		part_nodes[id].quaternion = part.orientation
		if part.modules.has("parachute") and part_nodes[id].has_node("Canopy"):
			part_nodes[id].get_node("Canopy").visible = part.modules.parachute.deployed and not part.destroyed
			part_nodes[id].get_node("Canopy").scale = Vector3.ONE*maxf(0.1,part.modules.parachute.deployment_fraction)
		if part.modules.has("fin") and part_nodes[id].has_node("Surface"):
			part_nodes[id].get_node("Surface").rotation.z = part.modules.fin.deflection
		if part.destroyed and not part_nodes[id].has_meta("wreck"):
			var wreck := material(Color("484b4c"))
			for mesh in part_nodes[id].get_children():
				if mesh is MeshInstance3D and not mesh in engine_plumes.values(): mesh.material_override = wreck
			part_nodes[id].set_meta("wreck",true)

func update_exhaust(_thrust: float, _maximum: float, time: float) -> void:
	update_parts()
	for id in engine_plumes:
		var part: PartInstance = craft.graph.parts[id]
		var engine: PartModuleState = part.modules.engine
		var plume: MeshInstance3D = engine_plumes[id]
		plume.visible = engine.thrust > 1 and not part.destroyed
		var power: float = engine.thrust/maxf(engine.engine.vacuum_thrust,1)
		plume.scale.y = power*(1+0.06*sin(time*47))
		plume.position.y = -part.definition.length*0.5-4.5*plume.scale.y

class_name StationPartVisual
extends RefCounted
## Original modular geometry, using a small shared vocabulary rather than ISS assets.
static func box(parent: Node3D, size: Vector3, position: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new(); var shape := BoxMesh.new(); shape.size = size
	mesh.mesh = shape; mesh.position = position; mesh.material_override = mat; parent.add_child(mesh)
	return mesh

static func beam(parent: Node3D, from: Vector3, to: Vector3, width: float, mat: Material) -> void:
	var node := box(parent,Vector3(width,width,from.distance_to(to)),(from+to)*0.5,mat)
	node.quaternion = Quaternion(Vector3.BACK,(to-from).normalized())

static func build(parent: Node3D, part: PartInstance, white: Material, dark: Material) -> bool:
	var d := part.definition
	var metal := RocketVisual.material(Color("87969f"),0.75)
	var glass := RocketVisual.material(Color("153541"),0.35)
	if d.visual in ["habitat","node"]:
		RocketVisual.cylinder(parent,d.radius,d.radius,d.length,0,white)
		for y in [-d.length*0.5+0.12,d.length*0.5-0.12]: RocketVisual.cylinder(parent,d.radius*1.02,d.radius*1.02,0.22,y,metal)
		for i in range(4):
			var angle: float = i*TAU/4
			var window := box(parent,Vector3(0.12,0.7,0.65),Vector3(cos(angle)*(d.radius+0.02),0,sin(angle)*(d.radius+0.02)),glass)
			window.rotation.y = -angle
			beam(parent,Vector3(cos(angle)*(d.radius+0.08),-d.length*0.3,sin(angle)*(d.radius+0.08)),Vector3(cos(angle)*(d.radius+0.08),d.length*0.3,sin(angle)*(d.radius+0.08)),0.055,metal)
		return true
	if d.visual == "truss":
		for x in [-1.3,1.3]:
			for z in [-1.3,1.3]: beam(parent,Vector3(x,-6,z),Vector3(x,6,z),0.14,metal)
		for i in range(5):
			var y: float = -6+i*3
			for z in [-1.3,1.3]: beam(parent,Vector3(-1.3,y,z),Vector3(1.3,y,z),0.1,metal)
			for x in [-1.3,1.3]: beam(parent,Vector3(x,y,-1.3),Vector3(x,y,1.3),0.1,metal)
			if i < 4:
				for z in [-1.3,1.3]: beam(parent,Vector3(-1.3,y,z),Vector3(1.3,y+3,z),0.09,metal)
		box(parent,Vector3(1.3,2,1.3),Vector3.ZERO,dark)
		return true
	if d.visual in ["solar","radiator"]:
		var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/station_panel.gdshader")
		mat.set_shader_parameter("solar",d.visual == "solar")
		box(parent,Vector3(float(d.box_size[0]),d.length,float(d.box_size[2])),Vector3.ZERO,mat)
		beam(parent,Vector3(0,-d.length/2,-0.22),Vector3(0,d.length/2,-0.22),0.15,metal)
		return true
	if d.visual == "docking":
		RocketVisual.cylinder(parent,d.radius,d.radius,d.length,0,dark)
		var ring := MeshInstance3D.new(); var torus := TorusMesh.new(); torus.inner_radius = d.radius*0.7; torus.outer_radius = d.radius
		ring.mesh = torus; ring.position.y = d.length/2; ring.material_override = metal; parent.add_child(ring)
		var light_mat := RocketVisual.material(Color("79e0ce")); light_mat.emission_enabled = true; light_mat.emission = Color("306e65")
		for i in range(4): box(parent,Vector3(0.06,0.06,0.06),Vector3(cos(i*TAU/4)*0.5,d.length/2+0.02,sin(i*TAU/4)*0.5),light_mat)
		return true
	if d.visual == "rcs":
		box(parent,Vector3(0.65,0.65,0.65),Vector3.ZERO,metal)
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
			for sign_value in [-1,1]:
				var nozzle := RocketVisual.cylinder(parent,0.08,0.13,0.2,0,dark)
				nozzle.position = axis*sign_value*0.38; nozzle.quaternion = Quaternion(Vector3.UP,axis*sign_value)
		return true
	return false

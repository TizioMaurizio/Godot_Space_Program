class_name PartDefinition
extends Resource

@export var id: String
@export var display_name: String
@export var category: String
@export var manufacturer: String = "Aster Engineering"
@export var description: String
@export var dry_mass: float
@export var length: float
@export var radius: float
@export var drag_coefficient: float = 0.3
@export var side_drag_coefficient: float = 0.8
@export var pressure_center_fraction: float = -0.12
@export var crash_speed: float = 12.0
@export var strength: float = 2000000.0
@export var bending_strength: float = 1500000.0
@export var stiffness: float = 1.0e8
@export var maximum_temperature: float = 1500.0
@export var visual: String = "tank"
@export var modules: Dictionary = {}
@export var nodes: Dictionary = {}
@export var size_class: String = ""
@export var box_size: Array = []

func half_extents() -> Vector3:
	return Vector3(float(box_size[0]),float(box_size[1]),float(box_size[2]))*0.5 if box_size.size() == 3 else Vector3(radius,length*0.5,radius)

func unit_inertia(q: Quaternion) -> SymmetricTensor:
	return SymmetricTensor.box(1.0,half_extents()*2.0,q) if box_size.size() == 3 else SymmetricTensor.cylinder(1.0,radius,length,q)

static func from_data(data: Dictionary) -> PartDefinition:
	var p := PartDefinition.new()
	for key in data:
		p.set(key, data[key])
	if p.size_class.is_empty():
		for diameter in {0.6:"S",1.0:"M",1.5:"X",2.0:"XL"}:
			if absf(p.radius-float(diameter)) < 0.01: p.size_class = {0.6:"S",1.0:"M",1.5:"X",2.0:"XL"}[diameter]; break
	if p.nodes.is_empty():
		p.nodes = {"top": {"position":[0,p.length/2,0],"normal":[0,1,0],"size":p.radius},
			"bottom":{"position":[0,-p.length/2,0],"normal":[0,-1,0],"size":p.radius},
			"radial":{"position":[p.radius,0,0],"normal":[1,0,0],"size":0,"capacity":8},
			"surface":{"position":[-p.radius,0,0],"normal":[-1,0,0],"size":0}}
		p.nodes["radial_low"] = {"position":[p.radius,-p.length*0.35,0],"normal":[1,0,0],"size":0,"capacity":8}
		p.nodes["radial_high"] = {"position":[p.radius,p.length*0.35,0],"normal":[1,0,0],"size":0,"capacity":8}
		if p.visual == "capsule" and p.modules.has("command"): p.nodes.top.size = 0.5
	return p

func volume() -> float:
	if visual in ["truss","solar","radiator","rcs"]: return dry_mass/7800.0
	if box_size.size() == 3: return float(box_size[0])*float(box_size[1])*float(box_size[2])
	if visual in ["engine","leg","fin"]: return dry_mass/7800.0
	if visual == "capsule":
		var top: float = 0.5 if modules.has("command") else 0.05
		return PI*length*(radius*radius+radius*top+top*top)/3.0
	return PI*radius*radius*length

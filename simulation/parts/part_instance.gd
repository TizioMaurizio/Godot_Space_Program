class_name PartInstance
extends RefCounted

var id: String
var definition: PartDefinition
var position: DVec3
var orientation: Quaternion
var modules: Dictionary = {}
var symmetry_group: String = ""
var destroyed: bool = false
var damage: float = 0
var force := DVec3.new()
var moment := DVec3.new()
var submerged: float = 0
var shielding: float = 1
var aero_force := DVec3.new()
var aero_moment := DVec3.new()
var air_damping := Vector3.ZERO
var fluid_force := DVec3.new()
var fluid_moment := DVec3.new()
var fluid_damping := Vector3.ZERO
var volume_samples: Array = []
var axis: DVec3
var pressure_center: DVec3
var inertia_per_kg: SymmetricTensor
var transient_contact_force: bool = false
var origin_vessel: String = ""
var origin_name: String = ""

func _init(entry: Dictionary) -> void:
	id = entry.id
	origin_vessel = entry.get("origin_vessel",""); origin_name = entry.get("origin_name","")
	definition = PartCatalog.get_part(entry.definition_id)
	position = DVector.from_array(entry.get("position_m",[0,0,0]))
	var q: Array = entry.get("rotation_xyzw",[0,0,0,1])
	orientation = Quaternion(q[0],q[1],q[2],q[3]).normalized()
	refresh_pose_cache()
	symmetry_group = entry.get("symmetry_group","")
	for kind in definition.modules:
		modules[kind] = PartModuleState.new(kind,definition.modules[kind])
	var settings: Dictionary = entry.get("settings",{})
	if modules.has("tank"):
		modules.tank.resources.fuel *= settings.get("fuel_fill",1.0)
		modules.tank.resources.oxidizer *= settings.get("oxidizer_fill",1.0)
	if modules.has("engine"):
		modules.engine.config["thrust_limit"] = settings.get("thrust_limit",1.0)
		modules.engine.config["gimbal_enabled"] = settings.get("gimbal_enabled",false)
	if modules.has("wheel"): modules.wheel.config["enabled"] = settings.get("wheel_enabled",true)
	if modules.has("leg"): modules.leg.deployed = settings.get("leg_deployed",false)
	if modules.has("battery") and settings.has("battery_capacity_j"):
		modules.battery.config.capacity_j = settings.battery_capacity_j
		modules.battery.resources.electricity = float(settings.battery_capacity_j)
	if settings.has("electric_load_w"):
		modules["electric_load"] = PartModuleState.new("electric_load",{"critical_w":float(settings.electric_load_w)})

func refresh_pose_cache() -> void:
	axis = DVec3.new(0,1,0).rotated(orientation)
	pressure_center = axis.scaled(definition.pressure_center_fraction*definition.length)
	inertia_per_kg = definition.unit_inertia(orientation)

func mass() -> float:
	var total: float = definition.dry_mass
	if modules.has("tank"): total += modules.tank.resources.fuel+modules.tank.resources.oxidizer
	if modules.has("rcs"): total += modules.rcs.resources.get("monopropellant",0.0)
	return total

func has_module(kind: String) -> bool:
	return not destroyed and modules.has(kind)

func node_position(node: String) -> DVec3:
	return position.plus(DVector.from_array(definition.nodes[node].position).rotated(orientation))

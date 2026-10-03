class_name PartModuleState
extends RefCounted

var kind: String
var config: Dictionary
var active: bool = false
var deployed: bool = false
var resources: Dictionary = {}
var thrust: float = 0.0
var gimbal := Vector2.ZERO
var gimbal_target := Vector2.ZERO
var engine: EngineDefinition
var failed: bool = false
var deployment_fraction: float = 0
var deflection: float = 0
var state: String = "AVAILABLE"
var connection_id: String = ""
var cooldown: float = 0
var force_output := Vector3.ZERO

func _init(module_kind: String, settings: Dictionary) -> void:
	kind = module_kind
	config = settings.duplicate(true)
	if kind == "tank": resources = {"fuel":float(config.fuel), "oxidizer":float(config.oxidizer)}
	if kind == "battery": resources = {"electricity":float(config.get("capacity_j",config.get("capacity",0)))}
	if kind == "rcs": resources = {"monopropellant":float(config.get("propellant",100))}
	if kind == "solar": deployed = true
	if kind == "engine":
		engine = EngineDefinition.new()
		engine.vacuum_thrust = config.thrust
		engine.sea_level_isp = config.isp_sl
		engine.vacuum_isp = config.isp_vac
		engine.oxidizer_fuel_ratio = config.get("mixture",2.0)

func resource_mass() -> float:
	return resources.get("fuel",0.0)+resources.get("oxidizer",0.0)+resources.get("monopropellant",0.0)

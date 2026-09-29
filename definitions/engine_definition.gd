class_name EngineDefinition
extends Resource

const G0: float = 9.80665
@export var display_name: String = "Engine"
@export var vacuum_thrust: float = 500000.0
@export var sea_level_isp: float = 285.0
@export var vacuum_isp: float = 320.0
@export var throttle_capable: bool = true
@export var minimum_throttle: float = 0.0
@export var oxidizer_fuel_ratio: float = 2.0

func isp(pressure_ratio: float) -> float:
	return lerpf(vacuum_isp, sea_level_isp, clampf(pressure_ratio, 0.0, 1.0))

func mass_flow(throttle: float) -> float:
	var setting: float = clampf(throttle, minimum_throttle, 1.0) if throttle > 0 else 0.0
	if not throttle_capable and setting > 0:
		setting = 1.0
	return vacuum_thrust / (vacuum_isp * G0) * setting

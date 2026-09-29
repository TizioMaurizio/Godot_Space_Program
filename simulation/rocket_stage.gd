class_name RocketStage
extends RefCounted

var definition: StageDefinition
var fuel: float
var oxidizer: float

func _init(config: StageDefinition) -> void:
	definition = config
	fuel = config.fuel_mass
	oxidizer = config.oxidizer_mass

func mass() -> float:
	return definition.dry_mass + fuel + oxidizer

func fraction() -> float:
	return (fuel + oxidizer) / maxf(definition.fuel_mass + definition.oxidizer_mass, 0.001)

func burn(dt: float, throttle: float, pressure_ratio: float) -> float:
	var engine := definition.engine
	var requested: float = engine.mass_flow(throttle) * dt
	var ratio: float = engine.oxidizer_fuel_ratio
	var available: float = minf(fuel * (1.0 + ratio), oxidizer * (1.0 + ratio) / ratio)
	var consumed: float = minf(requested, available)
	fuel = maxf(0.0, fuel - consumed / (1.0 + ratio))
	oxidizer = maxf(0.0, oxidizer - consumed * ratio / (1.0 + ratio))
	if fuel < 1.0e-9:
		fuel = 0.0
	if oxidizer < 1.0e-9:
		oxidizer = 0.0
	return consumed / dt * engine.isp(pressure_ratio) * EngineDefinition.G0

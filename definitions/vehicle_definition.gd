class_name VehicleDefinition
extends Resource

@export var display_name: String = "Orbital Test Vehicle"
@export_multiline var description: String = "Two stages. One destination: orbit."
@export var payload_mass: float = 1500.0
@export var payload_length: float = 4.0
@export var stages: Array[StageDefinition] = []

func wet_mass() -> float:
	var total: float = payload_mass
	for stage in stages:
		total += stage.dry_mass + stage.fuel_mass + stage.oxidizer_mass
	return total

func vacuum_delta_v() -> float:
	var total: float = wet_mass()
	var dv: float = 0.0
	for stage in stages:
		var propellant: float = stage.fuel_mass + stage.oxidizer_mass
		dv += stage.engine.vacuum_isp * EngineDefinition.G0 * log(total / (total - propellant))
		total -= propellant + stage.dry_mass
	return dv

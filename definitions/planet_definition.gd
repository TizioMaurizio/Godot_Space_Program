class_name PlanetDefinition
extends Resource

@export var display_name: String = "Aster"
@export var radius: float = 600000.0
@export var surface_gravity: float = 9.81
## Zero derives mu from g * R²; positive values override it.
@export var gravitational_parameter: float = 0.0
@export var rotation_rate: float = TAU / 21600.0
@export var atmosphere: AtmosphereDefinition

func mu() -> float:
	return gravitational_parameter if gravitational_parameter > 0.0 else surface_gravity * radius * radius

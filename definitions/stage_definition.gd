class_name StageDefinition
extends Resource

@export var display_name: String = "Stage"
@export var dry_mass: float = 3500.0
@export var fuel_mass: float = 6000.0
@export var oxidizer_mass: float = 12000.0
@export var length: float = 14.0
@export var radius: float = 1.5
@export var drag_coefficient: float = 0.3
@export var side_drag_coefficient: float = 0.8
## Centre of pressure relative to COM, as a fraction of current vehicle length.
## Negative places pressure aft, producing a nose-first stable direction.
@export_range(-0.5, 0.5) var pressure_center_fraction: float = -0.12
@export var aerodynamic_damping: float = 0.5
@export var engine: EngineDefinition

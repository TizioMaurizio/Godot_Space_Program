class_name CelestialBodyDefinition
extends PlanetDefinition
@export var body_id: String = "neris"
@export var parent_id: String = "aster"
@export var orbit_radius: float = 3000000.0
@export var orbit_phase: float = 1.2
@export var orbit_inclination: float = 0.0
@export var soi_radius: float = 0.0

func sphere_of_influence(parent: PlanetDefinition) -> float:
	return soi_radius if soi_radius > 0 else orbit_radius*pow(mu()/parent.mu(),0.4)

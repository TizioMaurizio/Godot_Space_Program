class_name TerrainDefinition
extends Resource

@export var style: String = "temperate"
@export var seed: int = 417
@export var height_scale: float = 1500.0
@export var maximum_height: float = 6000.0
@export var launch_plateau_height: float = 120.0
@export var launch_plateau: bool = true
var craters: Array = []

func ensure_craters() -> void:
	if not craters.is_empty(): return
	var random := RandomNumberGenerator.new(); random.seed = seed
	for i in range(48):
		var z: float = random.randf_range(-1,1); var angle: float = random.randf()*TAU
		var center := DVec3.new(sqrt(1-z*z)*cos(angle),sqrt(1-z*z)*sin(angle),z)
		craters.append({"center":center,"direction":center.vec(),"radius":random.randf_range(0.025,0.15),"depth":random.randf_range(180,1200)})

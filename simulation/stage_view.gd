class_name StageView
extends RefCounted
## Compatibility telemetry only; propellant remains in actual part modules.
var tanks: Array[PartInstance] = []
var members: Array[PartInstance] = []
var definition := StageDefinition.new()
var fuel: float:
	get:
		var n: float = 0
		for p in tanks: n += p.modules.tank.resources.fuel
		return n
var oxidizer: float:
	get:
		var n: float = 0
		for p in tanks: n += p.modules.tank.resources.oxidizer
		return n

func fraction() -> float:
	return (fuel+oxidizer)/maxf(definition.fuel_mass+definition.oxidizer_mass,1e-12)

func mass() -> float:
	var n: float = 0
	for p in members: n += p.mass()
	return n

class_name MassProperties
extends RefCounted

var total: float = 0
var dry: float = 0
var center := DVec3.new()
var tensor := SymmetricTensor.new()
var minimum := Vector3.ZERO
var maximum := Vector3.ZERO
var revision: int = 0
var weighted := DVec3.new()
var origin_tensor := SymmetricTensor.new()
var unit_tensors: Dictionary = {}
var centroids: Dictionary = {}

func update(parts: Dictionary) -> void:
	total = 0; dry = 0; center = DVec3.new(); tensor = SymmetricTensor.new()
	weighted = DVec3.new(); origin_tensor = SymmetricTensor.new()
	unit_tensors.clear(); centroids.clear()
	minimum = Vector3(INF,INF,INF); maximum = -minimum
	for part: PartInstance in parts.values():
		var m: float = part.mass()
		total += m; dry += part.definition.dry_mass
		weighted = weighted.plus(part.position.scaled(m))
		centroids[part.id] = part.position
		var unit := part.inertia_per_kg.plus(SymmetricTensor.parallel_axis(1,part.position))
		unit_tensors[part.id] = unit
		origin_tensor = origin_tensor.plus(unit.scaled(m))
		var basis := Basis(part.orientation)
		var half := part.definition.half_extents()
		var extent := basis.x.abs()*half.x+basis.y.abs()*half.y+basis.z.abs()*half.z
		minimum = minimum.min(part.position.vec()-extent)
		maximum = maximum.max(part.position.vec()+extent)
	center = weighted.scaled(1.0/maxf(total,1e-12))
	tensor = origin_tensor.plus(SymmetricTensor.parallel_axis(total,center).scaled(-1))
	revision += 1

func consume(changes: Dictionary) -> void:
	for id in changes:
		var dm: float = changes[id]
		total -= dm
		weighted = weighted.minus(centroids[id].scaled(dm))
		origin_tensor = origin_tensor.plus(unit_tensors[id].scaled(-dm))
	center = weighted.scaled(1.0/maxf(total,1e-12))
	tensor = origin_tensor.plus(SymmetricTensor.parallel_axis(total,center).scaled(-1))
	revision += 1

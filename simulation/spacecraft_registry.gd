class_name SpacecraftRegistry
extends RefCounted

var bodies: Array = []
var next_id: int = 1

func register(body: RocketState) -> void:
	if body in bodies: return
	body.body_id = next_id; next_id += 1
	if body.vessel_uid.is_empty() or bodies.any(func(b): return b.vessel_uid == body.vessel_uid): body.vessel_uid = "vessel-%08d"%body.body_id
	for part: PartInstance in body.graph.parts.values():
		if part.origin_vessel.is_empty(): part.origin_vessel = body.vessel_uid; part.origin_name = body.vessel_name
	bodies.append(body)

func collect_splits() -> Array:
	var spawned: Array = []
	for body in bodies.duplicate():
		for piece in body.pending_bodies:
			register(piece); spawned.append(piece)
		body.pending_bodies.clear()
	return spawned

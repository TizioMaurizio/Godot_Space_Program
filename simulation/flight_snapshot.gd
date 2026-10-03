class_name FlightSnapshot
extends RefCounted

static func read(craft: RocketState) -> Dictionary:
	var fuel: float = 0; var oxidizer: float = 0
	var engine_on: bool = false
	for part: PartInstance in craft.graph.parts.values():
		if part.has_module("tank"):
			fuel += part.modules.tank.resources.fuel
			oxidizer += part.modules.tank.resources.oxidizer
		if part.has_module("engine") and part.modules.engine.active: engine_on = true
	return {"part_count":craft.graph.parts.size(),"mass":craft.mass,"com":craft.properties.center,
		"fuel":fuel,"oxidizer":oxidizer,"engine_on":engine_on,"stage":craft.stage_index,
		"actions":craft.definition.stages,"control":craft.control_available}

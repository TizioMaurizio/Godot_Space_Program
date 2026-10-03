class_name CraftAnalysis
extends RefCounted

static func analyze(design: CraftDesign) -> Dictionary:
	var graph := PartGraph.new(design.parts,design.connections,design.root_part_id)
	var props := MassProperties.new(); props.update(graph.parts)
	var result := {"mass":props.total,"dry_mass":props.dry,"propellant":props.total-props.dry,"thrust":0.0,"sea_thrust":0.0,"delta_v":0.0,"stages":[],"com":props.center,"thrust_center":DVec3.new(),"pressure_center":DVec3.new(),"misalignment":0.0}
	var active: Dictionary = {}
	var fuel := FuelNetwork.new()
	for stage in design.stages:
		for action in stage.get("actions",[]):
			if not graph.parts.has(action.part_id): continue
			var part: PartInstance = graph.parts[action.part_id]
			match action.action:
				"ignite": active[action.part_id] = true
				"shutdown": active.erase(action.part_id)
				"decouple":
					var cuts: Array = []
					for edge: Dictionary in graph.adjacency[part.id]:
						var endpoint: Array = edge.a if edge.a[0] == part.id else edge.b
						if endpoint[1] == part.modules.decoupler.config.get("node","top"): cuts.append(edge.id)
					graph.cut(cuts)
					var retain := graph.reachable(design.root_part_id)
					for id in graph.parts.keys():
						if not id in retain: graph.parts.erase(id); active.erase(id)
					graph.connections = graph.connections.filter(func(c): return c.a[0] in retain and c.b[0] in retain)
					graph.rebuild()
		props.update(graph.parts); fuel.rebuild(graph)
		var tanks: Dictionary = {}; var f: float = 0; var flow: float = 0; var sl: float = 0
		var thrust_vector := DVec3.new(); var sea_vector := DVec3.new()
		for id in active:
			var part: PartInstance = graph.parts[id]
			if not part.has_module("engine"): continue
			var engine: EngineDefinition = part.modules.engine.engine
			var limit: float = part.modules.engine.config.get("thrust_limit",1.0)
			thrust_vector = thrust_vector.plus(DVec3.new(0,engine.vacuum_thrust*limit,0).rotated(part.orientation))
			sea_vector = sea_vector.plus(DVec3.new(0,engine.mass_flow(limit)*engine.sea_level_isp*EngineDefinition.G0,0).rotated(part.orientation))
			flow += engine.mass_flow(limit)
			for tank_id in fuel.routes.get(id,[]): tanks[tank_id] = true
		f = thrust_vector.length(); sl = sea_vector.length()
		var propellant: float = 0
		for id in tanks: propellant += graph.parts[id].modules.tank.resource_mass()
		var dv: float = f/maxf(flow,1e-12)*log(props.total/maxf(props.total-propellant,1e-12)) if f > 0 else 0.0
		result.stages.append({"mass":props.total,"thrust":f,"sea_thrust":sl,"delta_v":dv,"burn_time":propellant/maxf(flow,1e-12)})
		result.delta_v += dv
		if result.stages.size() == 1:
			result.thrust = f; result.sea_thrust = sl
			result["thrust_vector"] = thrust_vector; result["sea_vector"] = sea_vector
			result["first_engine_ids"] = active.keys()
		for id in tanks: graph.parts[id].modules.tank.resources = {"fuel":0.0,"oxidizer":0.0}
	return result

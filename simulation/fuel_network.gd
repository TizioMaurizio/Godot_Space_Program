class_name FuelNetwork
extends RefCounted

var graph_version: int = -1
var routes: Dictionary = {}

func rebuild(graph: PartGraph) -> void:
	if graph_version == graph.version: return
	routes.clear()
	for part: PartInstance in graph.parts.values():
		if part.has_module("engine"):
			var tanks: Array[String] = []
			for id in graph.reachable(part.id,true):
				if graph.parts[id].has_module("tank"): tanks.append(id)
			routes[part.id] = tanks
	graph_version = graph.version

func burn(graph: PartGraph, throttle: float, pressure_ratio: float, dt: float) -> Dictionary:
	rebuild(graph)
	var requests: Dictionary = {}
	var totals: Dictionary = {}
	for id in routes:
		var part: PartInstance = graph.parts[id]
		var engine: PartModuleState = part.modules.engine
		engine.thrust = 0
		if not engine.active or part.destroyed: continue
		var demand: float = engine.engine.mass_flow(throttle*float(engine.config.get("thrust_limit",1.0)))*dt
		if demand <= 0: continue
		var available_fuel: float = 0; var available_ox: float = 0
		for tank_id in routes[id]:
			var tank: PartModuleState = graph.parts[tank_id].modules.tank
			available_fuel += tank.resources.fuel; available_ox += tank.resources.oxidizer
		var ratio: float = engine.engine.oxidizer_fuel_ratio
		demand = minf(demand,minf(available_fuel*(1+ratio),available_ox*(1+ratio)/ratio))
		var plan: Dictionary = {}
		for tank_id in routes[id]:
			var tank: PartModuleState = graph.parts[tank_id].modules.tank
			var f: float = demand/(1+ratio)*tank.resources.fuel/maxf(available_fuel,1e-12)
			var o: float = demand*ratio/(1+ratio)*tank.resources.oxidizer/maxf(available_ox,1e-12)
			plan[tank_id] = [f,o]
			if not totals.has(tank_id): totals[tank_id] = [0.0,0.0]
			totals[tank_id][0] += f; totals[tank_id][1] += o
		requests[id] = plan
	# Scale all shared requests together, before mutating a tank: ordering-independent.
	var limits: Dictionary = {}
	for tank_id in totals:
		var tank: PartModuleState = graph.parts[tank_id].modules.tank
		var scale: float = 1
		if totals[tank_id][0] > 0: scale = minf(scale,tank.resources.fuel/totals[tank_id][0])
		if totals[tank_id][1] > 0: scale = minf(scale,tank.resources.oxidizer/totals[tank_id][1])
		limits[tank_id] = scale
	var consumed: Dictionary = {}
	for id in requests:
		var scale: float = 1
		for tank_id in requests[id]: scale = minf(scale,limits[tank_id])
		var amount: float = 0
		for tank_id in requests[id]:
			var tank: PartModuleState = graph.parts[tank_id].modules.tank
			var f: float = requests[id][tank_id][0]*scale
			var o: float = requests[id][tank_id][1]*scale
			tank.resources.fuel = maxf(0,tank.resources.fuel-f)
			tank.resources.oxidizer = maxf(0,tank.resources.oxidizer-o)
			amount += f+o
			consumed[tank_id] = consumed.get(tank_id,0.0)+f+o
		var engine: PartModuleState = graph.parts[id].modules.engine
		engine.thrust = amount/dt*engine.engine.isp(pressure_ratio)*EngineDefinition.G0
	return consumed

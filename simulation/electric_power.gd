class_name ElectricPower
extends RefCounted
## Joules/watts. Connected electrical buses, priority shedding, geometric eclipse.
const SUN := Vector3(-0.4767312946,0.6674238125,0.5720775535)
var enabled: bool = false
var generation: float = 0
var demand: float = 0
var supplied: float = 0
var energy: float = 0
var capacity: float = 0
var critical_fraction: float = 1
var optional_fraction: float = 1
var eclipse: bool = false

static func in_shadow(position: DVec3, system: CelestialSystem, epoch: float) -> bool:
	var bodies: Array = [system.primary]; bodies.append_array(system.moons)
	for body in bodies:
		var p := position.minus(system.ephemeris(body,epoch).position)
		var projection: float = p.dot(DVector.from_vec(SUN))
		if projection < 0 and p.length_squared()-projection*projection < body.radius*body.radius: return true
	return false

func step(craft: RocketState, system: CelestialSystem, dt: float, sample_position: DVec3 = null, epoch: float = -1) -> void:
	generation = 0; demand = 0; supplied = 0; energy = 0; capacity = 0
	critical_fraction = 1; optional_fraction = 1; enabled = false
	eclipse = in_shadow(craft.position if sample_position == null else sample_position,system,craft.elapsed if epoch < 0 else epoch)
	var seen: Dictionary = {}
	for root_id in craft.graph.parts:
		if seen.has(root_id): continue
		var bus: Array = []; var stack: Array = [root_id]
		while not stack.is_empty():
			var id: String = stack.pop_back()
			if seen.has(id): continue
			seen[id] = true; bus.append(craft.graph.parts[id])
			for edge in craft.graph.adjacency[id]:
				if edge.get("electric_crossfeed",true): stack.append(edge.b[0] if edge.a[0] == id else edge.a[0])
		var batteries: Array = []; var production: float = 0; var critical: float = 0; var optional: float = 0
		var joules: float = 0; var maximum: float = 0
		for part: PartInstance in bus:
			if part.destroyed: continue
			if part.has_module("battery") and part.modules.battery.config.has("capacity_j"):
				batteries.append(part.modules.battery); joules += part.modules.battery.resources.electricity; maximum += part.modules.battery.config.capacity_j
			if part.has_module("solar") and part.modules.solar.deployed and not eclipse:
				var normal := DVector.from_array(part.modules.solar.config.normal).rotated(part.orientation).rotated(craft.orientation)
				production += part.modules.solar.config.power_w*maxf(0,normal.dot(DVector.from_vec(SUN)))
			if part.has_module("electric_load"):
				critical += part.modules.electric_load.config.get("critical_w",0)
				optional += part.modules.electric_load.config.get("optional_w",0)
			if part.has_module("docking"): critical += 100
			if part.has_module("wheel"):
				critical += 2000*clampf(craft.controller.last_torque.length()/maxf(craft.control_torque_limit(),1),0,1)
		if batteries.is_empty() and production == 0: continue
		enabled = true
		var available: float = production+joules/maxf(dt,1e-9)
		var critical_used: float = minf(critical,available)
		var optional_used: float = minf(optional,maxf(0,available-critical_used))
		var remaining: float = clampf(joules+(production-critical_used-optional_used)*dt,0,maximum)
		for battery: PartModuleState in batteries: battery.resources.electricity = remaining*battery.config.capacity_j/maxf(maximum,1e-9)
		critical_fraction = minf(critical_fraction,critical_used/maxf(critical,1e-9) if critical > 0 else 1.0)
		optional_fraction = minf(optional_fraction,optional_used/maxf(optional,1e-9) if optional > 0 else 1.0)
		generation += production; demand += critical+optional; supplied += critical_used+optional_used; energy += remaining; capacity += maximum

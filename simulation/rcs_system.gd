class_name RCSSystem
extends RefCounted
## Each standard RCS block is a six-nozzle set; propellant is kilograms.
static func burn(craft: RocketState, dt: float) -> Dictionary:
	var forces: Dictionary = {}; var consumed: Dictionary = {}
	craft.rcs_force = DVec3.new(); craft.rcs_torque = DVec3.new()
	for part: PartInstance in craft.graph.parts.values():
		if not part.has_module("rcs"): continue
		var module: PartModuleState = part.modules.rcs; module.force_output = Vector3.ZERO
		if craft.power.enabled and craft.power.critical_fraction < 0.1: continue
		if not craft.rcs_enabled or not craft.control_available or craft.rcs_command.length_squared() == 0: continue
		var local_command := DVector.from_vec(craft.rcs_command).rotated(part.orientation.inverse())
		var sum: float = absf(local_command.x)+absf(local_command.y)+absf(local_command.z)
		var dm: float = module.config.thrust*sum*dt/(module.config.isp*EngineDefinition.G0)
		var actual: float = minf(dm,module.resources.monopropellant)
		var force := local_command.scaled(module.config.thrust*actual/maxf(dm,1e-30)).rotated(part.orientation)
		module.resources.monopropellant -= actual; module.force_output = force.vec()
		forces[part.id] = force; consumed[part.id] = actual
		craft.rcs_force = craft.rcs_force.plus(force)
		craft.rcs_torque = craft.rcs_torque.plus(part.position.minus(craft.properties.center).cross(force))
	return {"forces":forces,"consumed":consumed}

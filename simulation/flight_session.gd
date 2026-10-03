class_name FlightSession
extends RefCounted

var registry := SpacecraftRegistry.new()
var active: RocketState
var planet: PlanetDefinition
var time: float = 0.0
var celestial: CelestialSystem
var transitions: Array = []
var docking := DockingSystem.new()
var target_uid: String = ""
var target_port_id: String = ""
var source_port_id: String = ""
var scenario_label: String = "LAUNCHED FLIGHT"
var campaign_mode: bool = false

func _init(craft: RocketState, world: PlanetDefinition) -> void:
	active = craft; planet = world
	celestial = CelestialSystem.new(world)
	time = craft.elapsed; celestial.time = time
	craft.celestial = celestial; craft.reference_body = world
	registry.register(craft)

func update_reference(body: RocketState) -> void:
	body.celestial = celestial
	var selected := celestial.dominant(body.position,body.elapsed)
	if body.reference_body != selected:
		transitions.append({"time":body.elapsed,"from":body.reference_body.display_name,"to":selected.display_name,"position":body.position,"velocity":body.velocity})
		body.reference_body = selected
	body.planet_definition = selected

func step_body(body: RocketState, dt: float, manual: Vector3 = Vector3.ZERO) -> void:
	update_reference(body)
	body.power.step(body,celestial,dt)
	var frame := celestial.ephemeris(body.reference_body,body.elapsed)
	var end_frame := celestial.ephemeris(body.reference_body,body.elapsed+dt)
	body.position = body.position.minus(frame.position); body.velocity = body.velocity.minus(frame.velocity)
	body.integrating_relative = true
	var event_start: int = body.events.size()
	body.step(dt,body.reference_body,manual)
	body.position = body.position.plus(end_frame.position); body.velocity = body.velocity.plus(end_frame.velocity)
	body.integrating_relative = false
	for i in range(event_start,body.events.size()): body.events[i].position = body.events[i].position.plus(end_frame.position)
	for child: RocketState in body.pending_bodies:
		if child.celestial != null: continue
		child.celestial = celestial; child.reference_body = body.reference_body
		child.position = child.position.plus(end_frame.position); child.velocity = child.velocity.plus(end_frame.velocity)
	update_reference(body)

func step(dt: float, manual: Vector3) -> void:
	registry.collect_splits()
	for body in registry.bodies:
		step_body(body,dt,manual if body == active else Vector3.ZERO)
	docking.step(self,dt)
	AssemblyCollisions.solve(registry.bodies,dt)
	time += dt
	celestial.time = time

func can_coast(body: RocketState, dt: float) -> bool:
	if body.on_pad or body.contacting or body.water_contact: return false
	if body.rcs_enabled and body.rcs_command.length_squared() > 0: return false
	if docking.captures.any(func(c): return c.a == body or c.b == body): return false
	if body.throttle > 0:
		for part: PartInstance in body.graph.parts.values():
			if part.has_module("engine") and part.modules.engine.active: return false
	if not celestial.interval_safe(body.position,body.velocity,body.reference_body,body.elapsed,dt): return false
	var probe := FlightBody.new(); probe.position = body.relative_position(); probe.velocity = body.relative_velocity()
	return TimeWarp.vacuum_interval_safe(probe,body.reference_body,dt)

func coast_body(body: RocketState, dt: float) -> bool:
	var frame := celestial.ephemeris(body.reference_body,body.elapsed+dt)
	var probe := FlightBody.new(); probe.position = body.relative_position(); probe.velocity = body.relative_velocity()
	if not KeplerCoast.advance(probe,body.reference_body,dt): return false
	# Five-second power samples resolve eclipses without a full thermal/attitude integrator.
	var old_epoch: float = body.elapsed
	var remaining: float = dt
	var sampled: float = 0
	while remaining > 1e-9:
		var tick: float = minf(5,remaining)
		var mid := FlightBody.new(); mid.position = body.relative_position(); mid.velocity = body.relative_velocity()
		if not KeplerCoast.advance(mid,body.reference_body,sampled+tick*0.5): return false
		var mid_position: DVec3 = mid.position.plus(celestial.ephemeris(body.reference_body,old_epoch+sampled+tick*0.5).position)
		body.power.step(body,celestial,tick,mid_position,old_epoch+sampled+tick*0.5)
		remaining -= tick; sampled += tick
	body.position = probe.position.plus(frame.position); body.velocity = probe.velocity.plus(frame.velocity)
	body.gravity = probe.gravity; body.acceleration = probe.acceleration
	body.elapsed += dt; body.thrust = 0; body.thrust_force = DVec3.new()
	body.density = 0; body.dynamic_pressure = 0; body.heating = 0
	body.drag_force = DVec3.new(); body.aerodynamic_torque = Vector3.ZERO
	return true

func coast(dt: float) -> bool:
	registry.collect_splits()
	for body: RocketState in registry.bodies: update_reference(body)
	if not can_coast(active,dt): return false
	# Nearby components must not cross one another unseen during analytical warp.
	for i in range(registry.bodies.size()):
		for j in range(i+1,registry.bodies.size()):
			var a: RocketState = registry.bodies[i]; var b: RocketState = registry.bodies[j]
			var separation := b.position.minus(a.position); var relative := b.velocity.minus(a.velocity)
			var closest: float = clampf(-separation.dot(relative)/maxf(relative.length_squared(),1e-9),0,dt)
			var threshold: float = 5000 if a.lifecycle == "PERSISTENT" and b.lifecycle == "PERSISTENT" else a.length+b.length+10
			var bound: float = separation.plus(relative.scaled(closest)).length()-0.5*(a.acceleration.length()+b.acceleration.length())*dt*dt
			if bound < threshold: return false
	if not coast_body(active,dt): return false
	for body in registry.bodies:
		if body == active or not body.simulation_active: continue
		if can_coast(body,dt) and coast_body(body,dt):
			pass
		else:
			var remaining: float = dt
			while remaining > 1e-9:
				var tick: float = minf(remaining,1.0/120)
				step_body(body,tick); remaining -= tick
	time += dt
	celestial.time = time
	return true

func vessel(uid: String) -> RocketState:
	for body: RocketState in registry.bodies:
		if body.vessel_uid == uid: return body
	return null

func switch_vessel(uid: String) -> bool:
	var body := vessel(uid)
	if body == null or not body.control_available: return false
	var previous := active
	active.rcs_command = Vector3.ZERO
	active = body
	source_port_id = ""
	if target_uid == body.vessel_uid:
		target_uid = previous.vessel_uid
		var ports := DockingSystem.ports(previous); target_port_id = ports[0].id if not ports.is_empty() else ""
	return true

func cycle_vessel(direction: int = 1) -> void:
	var choices := registry.bodies.filter(func(b): return b.control_available and b.lifecycle == "PERSISTENT")
	if choices.is_empty(): return
	var index: int = choices.find(active)
	switch_vessel(choices[posmod(index+direction,choices.size())].vessel_uid)

func selected_source_port() -> PartInstance:
	if active.graph.parts.has(source_port_id) and active.graph.parts[source_port_id].has_module("docking"): return active.graph.parts[source_port_id]
	var available := DockingSystem.ports(active)
	return available[0] if not available.is_empty() else null

func target_metrics() -> Dictionary:
	var target := vessel(target_uid); var source := selected_source_port()
	if target == null or target == active or source == null or not target.graph.parts.has(target_port_id): return {}
	return DockingSystem.metrics(active,source,target,target.graph.parts[target_port_id])

func maximum_proximity_warp() -> int:
	var minimum: float = INF
	for body: RocketState in registry.bodies:
		if body == active or body.lifecycle != "PERSISTENT": continue
		minimum = minf(minimum,body.position.minus(active.position).length()-body.radius-active.radius)
	if minimum < 50 or not docking.captures.is_empty(): return 1
	if minimum < 200: return 2
	if minimum < 2000: return 4
	return 1000

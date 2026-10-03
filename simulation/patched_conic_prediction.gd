class_name PatchedConicPrediction
extends RefCounted
## Timed read-only coast segments. Same ephemerides/conics/SOI boundary as flight.
static func predict(system: CelestialSystem, position: DVec3, velocity: DVec3, epoch: float, duration: float = 24000) -> Dictionary:
	var points: Array = []; var encounters: Array = []
	var p := position; var v := velocity; var time: float = epoch
	var body := system.dominant(p,time)
	var lunar_periapsis: float = INF; var minimum_point: DVec3
	var minimum_radius: float = INF
	var iterations: int = 0
	while time < epoch+duration and iterations < 1600:
		iterations += 1
		var frame := system.ephemeris(body,time)
		var probe := FlightBody.new(); probe.position = p.minus(frame.position); probe.velocity = v.minus(frame.velocity)
		if body is CelestialBodyDefinition:
			var lunar_conic := OrbitalMechanics.elements(probe.position,probe.velocity,body)
			lunar_periapsis = minf(lunar_periapsis,lunar_conic.periapsis)
			if probe.position.length() < minimum_radius:
				minimum_radius = probe.position.length(); minimum_point = p
		if probe.position.length() < body.radius+SurfaceQuery.height(body,probe.position,time): break
		points.append({"position":p,"time":time,"body":body})
		var dt: float = minf(120,epoch+duration-time)
		# Resolve approaching boundaries at subsecond resolution, rather than sampling past them.
		while dt > 0.1 and not system.interval_safe(p,v,body,time,dt): dt *= 0.5
		if not KeplerCoast.advance(probe,body,dt): break
		time += dt; frame = system.ephemeris(body,time)
		p = probe.position.plus(frame.position); v = probe.velocity.plus(frame.velocity)
		var next := system.dominant(p,time)
		if next != body:
			encounters.append({"from":body.display_name,"to":next.display_name,"position":p,"time":time})
			body = next
	return {"points":points,"encounters":encounters,"lunar_periapsis":lunar_periapsis,"periapsis_position":minimum_point,"duration":time-epoch}

class_name OrbitPrediction
extends RefCounted
## Read-only osculating conic. Never changes the flight state or propagates thrust.

static func sample(position: DVec3, velocity: DVec3, planet: PlanetDefinition, segments: int = 720) -> Dictionary:
	var orbit := OrbitalMechanics.elements(position, velocity, planet)
	var result := {"points": [], "orbit": orbit, "closed": false, "impact": null,
		"apoapsis_position": null, "periapsis_position": null, "clipped": false,
		"radial": false, "extent": maxf(position.length(), planet.radius)}
	var h := position.cross(velocity)
	var p: float = h.length_squared() / planet.mu()
	if p < planet.radius * 1.0e-8:
		return radial_path(position, velocity, planet, result)
	var e_vector := velocity.cross(h).scaled(1.0 / planet.mu()).minus(position.unit())
	var e: float = e_vector.length()
	var axis := e_vector.unit() if e > 1.0e-6 else position.unit()
	var tangent := h.unit().cross(axis).unit()
	var start: float = atan2(position.dot(tangent), position.dot(axis))
	var limit: float = maxf(planet.radius * 20.0, position.length() * 1.5)
	var finish: float = start + TAU
	if not orbit.bound:
		finish = acos(clampf((p / limit - 1.0) / maxf(e, 1.0e-12), -1, 1))
		result.clipped = true
	var surface_angle: float = INF
	if e > 1.0e-12 and orbit.periapsis < 0.0:
		var crossing: float = -acos(clampf((p / planet.radius - 1.0) / e, -1, 1))
		crossing = start + fposmod(crossing - start, TAU)
		if crossing <= finish:
			surface_angle = crossing
			finish = crossing
			result.clipped = false
	var points: Array[DVec3] = [position]
	var previous_angle: float = start
	for i in range(1, segments + 1):
		var angle: float = lerpf(start, finish, float(i) / segments)
		var denominator: float = 1.0 + e * cos(angle)
		if denominator <= 1.0e-12:
			result.clipped = true
			break
		var radius: float = p / denominator
		if radius < planet.radius:
			# Refine the first surface intersection so no arc passes through the planet.
			var low: float = previous_angle
			var high: float = angle
			for iteration in range(40):
				var mid: float = (low + high) * 0.5
				if p / (1.0 + e * cos(mid)) >= planet.radius:
					low = mid
				else:
					high = mid
			var impact_angle: float = (low + high) * 0.5
			var impact := axis.scaled(cos(impact_angle)).plus(tangent.scaled(sin(impact_angle))).scaled(planet.radius)
			points.append(impact)
			result.impact = impact
			break
		if radius > limit:
			result.clipped = true
			break
		var point := axis.scaled(cos(angle)).plus(tangent.scaled(sin(angle))).scaled(radius)
		points.append(point)
		result.extent = maxf(result.extent, radius)
		previous_angle = angle
	if is_finite(surface_angle) and result.impact == null and not result.clipped:
		result.impact = axis.scaled(cos(surface_angle)).plus(tangent.scaled(sin(surface_angle))).scaled(planet.radius)
		points[points.size() - 1] = result.impact
	if orbit.bound and result.impact == null and not result.clipped:
		points[points.size() - 1] = position
		result.closed = true
	# A circular orbit has no unique apsides; avoid unstable, flickering labels.
	if e > 1.0e-5:
		if orbit.periapsis >= 0.0 and orbit.periapsis + planet.radius <= limit:
			result.periapsis_position = axis.scaled(orbit.periapsis + planet.radius)
		# If a surface crossing occurs first, an apoapsis beyond that impact is irrelevant.
		var ap_angle: float = start + fposmod(PI - start, TAU)
		if orbit.bound and orbit.apoapsis >= 0.0 and orbit.apoapsis + planet.radius <= limit:
			if result.impact == null or ap_angle <= previous_angle + 1.0e-9:
				result.apoapsis_position = axis.scaled(-(orbit.apoapsis + planet.radius))
	result.points = points
	return result

static func radial_path(position: DVec3, velocity: DVec3, planet: PlanetDefinition, result: Dictionary) -> Dictionary:
	result.radial = true
	if result.orbit.energy < 0.0:
		var turning_radius: float = -planet.mu() / result.orbit.energy
		result.orbit.apoapsis = turning_radius - planet.radius
		if position.dot(velocity) >= 0:
			result.apoapsis_position = position.unit().scaled(turning_radius)
	var probe := FlightBody.new()
	probe.position = position
	probe.velocity = velocity
	var points: Array[DVec3] = [position]
	var dt: float = clampf(sqrt(pow(position.length(), 3) / planet.mu()) / 256.0, 0.25, 10.0)
	for i in range(1024):
		var old_position := probe.position
		# Vacuum gravity alone: use small fixed Verlet steps even near radial impact.
		var a0 := PlanetPhysics.gravity(probe.position, planet)
		var half_v := probe.velocity.plus(a0.scaled(dt * 0.5))
		probe.position = probe.position.plus(half_v.scaled(dt))
		probe.velocity = half_v.plus(PlanetPhysics.gravity(probe.position, planet).scaled(dt * 0.5))
		if probe.position.length() <= planet.radius:
			result.impact = old_position.unit().scaled(planet.radius)
			points.append(result.impact)
			break
		points.append(probe.position)
		result.extent = maxf(result.extent, probe.position.length())
		if probe.position.length() > maxf(position.length() * 1.5, planet.radius * 20.0):
			result.clipped = true
			break
	result.points = points
	return result

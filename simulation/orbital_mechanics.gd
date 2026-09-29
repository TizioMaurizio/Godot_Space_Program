class_name OrbitalMechanics
extends RefCounted

static func elements(position: DVec3, velocity: DVec3, planet: PlanetDefinition) -> Dictionary:
	var r: float = position.length()
	var mu: float = planet.mu()
	var h := position.cross(velocity)
	var h2: float = h.length_squared()
	var energy: float = 0.5 * velocity.length_squared() - mu / r
	var ev := velocity.cross(h).scaled(1.0 / mu).minus(position.unit())
	var eccentricity: float = ev.length()
	var p: float = h2 / mu
	var periapsis: float = p / (1.0 + eccentricity) - planet.radius
	var bound: bool = energy < -1.0e-8 and eccentricity < 1.0
	var semi_major: float = -mu / (2.0 * energy) if absf(energy) > 1.0e-8 else INF
	var apoapsis: float = semi_major * (1.0 + eccentricity) - planet.radius if bound else INF
	var period: float = TAU * sqrt(pow(semi_major, 3.0) / mu) if bound else INF
	var time_to_ap: float = INF
	if bound and eccentricity > 1.0e-7:
		var cos_e: float = clampf((1.0 - r / semi_major) / eccentricity, -1.0, 1.0)
		var sin_e: float = position.dot(velocity) / (eccentricity * sqrt(mu * semi_major))
		var eccentric_anomaly: float = atan2(sin_e, cos_e)
		var mean_anomaly: float = eccentric_anomaly - eccentricity * sin_e
		time_to_ap = fposmod(PI - mean_anomaly, TAU) / TAU * period
	var boundary: float = planet.atmosphere.height if planet.atmosphere else 0.0
	return {"apoapsis": apoapsis, "periapsis": periapsis, "eccentricity": eccentricity,
		"energy": energy, "semi_major": semi_major, "period": period, "time_to_ap": time_to_ap,
		"bound": bound, "stable": bound and apoapsis > boundary and periapsis > boundary}

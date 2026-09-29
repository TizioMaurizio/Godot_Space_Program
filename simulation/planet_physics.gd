class_name PlanetPhysics
extends RefCounted

static func gravity(position: DVec3, planet: PlanetDefinition) -> DVec3:
	var r: float = maxf(position.length(), 1.0)
	return position.scaled(-planet.mu() / (r * r * r))

static func air_velocity(position: DVec3, planet: PlanetDefinition) -> DVec3:
	# Rotation about inertial +Z. Launch is at +Y; east is initially -X.
	return DVec3.new(-planet.rotation_rate * position.y, planet.rotation_rate * position.x, 0.0)

static func density(altitude: float, atmosphere: AtmosphereDefinition) -> float:
	if atmosphere == null or altitude >= atmosphere.height:
		return 0.0
	# Smoothly taper the last 10% to avoid a discontinuity at the boundary.
	var taper: float = 1.0 - smoothstep(atmosphere.height * 0.9, atmosphere.height, altitude)
	return atmosphere.sea_level_density * exp(-maxf(altitude, 0.0) / atmosphere.scale_height) * taper

static func pressure(altitude: float, atmosphere: AtmosphereDefinition) -> float:
	if atmosphere == null or atmosphere.sea_level_density <= 0.0:
		return 0.0
	return atmosphere.sea_level_pressure * density(altitude, atmosphere) / atmosphere.sea_level_density

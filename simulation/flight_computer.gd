class_name FlightComputer
extends RefCounted

static func read(rocket: RocketState, planet: PlanetDefinition) -> Dictionary:
	var up: Vector3 = rocket.position.unit().vec()
	var east: Vector3 = Vector3.BACK.cross(up).normalized()
	if east.length_squared() < 0.01:
		east = Vector3.LEFT
	var north: Vector3 = up.cross(east).normalized()
	var forward: Vector3 = rocket.orientation * Vector3.UP
	var surface := rocket.velocity.minus(PlanetPhysics.air_velocity(rocket.position, planet))
	var orbit := OrbitalMechanics.elements(rocket.position, rocket.velocity, planet)
	return {"altitude": rocket.position.length() - planet.radius, "surface_speed": surface.length(),
		"orbital_speed": rocket.velocity.length(), "vertical_speed": rocket.velocity.dot(rocket.position.unit()),
		"pitch": rad_to_deg(asin(clampf(forward.dot(up), -1, 1))),
		"heading": fposmod(rad_to_deg(atan2(forward.dot(east), forward.dot(north))), 360.0),
		"orbit": orbit, "up": up, "east": east, "north": north, "forward": forward,
		"prograde": surface.vec().normalized() if rocket.position.length() - planet.radius < planet.atmosphere.height else rocket.velocity.unit().vec(),
		"reference": "SURFACE" if rocket.position.length() - planet.radius < planet.atmosphere.height else "ORBITAL"}

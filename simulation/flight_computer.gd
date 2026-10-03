class_name FlightComputer
extends RefCounted

static func read(rocket: RocketState, planet: PlanetDefinition) -> Dictionary:
	planet = rocket.reference_body
	var position := rocket.relative_position(); var velocity := rocket.relative_velocity()
	var up: Vector3 = position.unit().vec()
	var east: Vector3 = Vector3.BACK.cross(up).normalized()
	if east.length_squared() < 0.01:
		east = Vector3.LEFT
	var north: Vector3 = up.cross(east).normalized()
	var forward: Vector3 = rocket.orientation * Vector3.UP
	var surface := velocity.minus(PlanetPhysics.air_velocity(position, planet))
	var orbit := OrbitalMechanics.elements(position, velocity, planet)
	return {"craft":FlightSnapshot.read(rocket),"body":planet.display_name,"ground_altitude":position.length()-planet.radius-SurfaceQuery.height(planet,position,rocket.elapsed),"altitude": position.length() - planet.radius, "surface_speed": surface.length(),
		"orbital_speed": velocity.length(), "vertical_speed": velocity.dot(position.unit()),
		"pitch": rad_to_deg(asin(clampf(forward.dot(up), -1, 1))),
		"heading": fposmod(rad_to_deg(atan2(forward.dot(east), forward.dot(north))), 360.0),
		"orbit": orbit, "up": up, "east": east, "north": north, "forward": forward,
		"prograde": surface.vec().normalized() if position.length() - planet.radius < planet.atmosphere.height else velocity.unit().vec(),
		"reference": "SURFACE" if position.length() - planet.radius < planet.atmosphere.height else "ORBITAL"}

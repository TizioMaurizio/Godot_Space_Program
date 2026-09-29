class_name Aerodynamics
extends RefCounted
## Projected axial/side drag, offset pressure centre, and rotational damping.

static func drag(air_relative: DVec3, density: float, cd: float, area: float) -> DVec3:
	return air_relative.scaled(-0.5 * density * air_relative.length() * cd * area)

static func dynamic_pressure(air_relative: DVec3, density: float) -> float:
	return 0.5 * density * air_relative.length_squared()

static func drag_area(body: FlightBody, air_relative: DVec3) -> float:
	var alignment: float = (body.orientation * Vector3.UP).dot(air_relative.unit().vec())
	var side_area: float = 2.0 * body.radius * body.length
	return body.drag_coefficient * body.area + body.side_drag_coefficient * side_area * maxf(0, 1.0 - alignment * alignment)

static func moment(body: FlightBody) -> Vector3:
	var local_force: Vector3 = body.orientation.inverse() * body.drag_force.vec()
	return Vector3(0, body.length * body.pressure_center_fraction, 0).cross(local_force)

static func damping(body: FlightBody) -> Vector3:
	var side_area: float = 2.0 * body.radius * body.length
	var factor: float = body.aerodynamic_damping * body.density * body.air_velocity.length()
	var transverse: float = factor * body.side_drag_coefficient * side_area * body.length * body.length / 12.0
	var roll: float = factor * body.drag_coefficient * body.area * body.radius * body.radius
	return Vector3(transverse, roll, transverse)

class_name AttitudeController
extends RefCounted
## Torque-driven attitude control. Electric reaction control is idealized and unlimited.

enum Mode { OFF, HOLD, PROGRADE, RETROGRADE, RADIAL_OUT, RADIAL_IN, NORMAL, ANTINORMAL }
const NAMES := ["OFF", "HOLD", "PROGRADE", "RETROGRADE", "RADIAL OUT", "RADIAL IN", "NORMAL", "ANTINORMAL"]
var mode: Mode = Mode.HOLD
var target := Quaternion.IDENTITY
var max_rate: float = deg_to_rad(12.0)
var max_acceleration: float = deg_to_rad(18.0)
var last_torque := Vector3.ZERO

func set_mode(value: Mode, orientation: Quaternion) -> void:
	mode = value
	target = orientation

static func pointing(direction: Vector3, reference: Quaternion) -> Quaternion:
	var up: Vector3 = direction.normalized()
	if up.length_squared() < 0.1:
		return reference
	var right: Vector3 = (reference * Vector3.RIGHT).slide(up).normalized()
	if right.length_squared() < 0.1:
		right = up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1:
		right = up.cross(Vector3.RIGHT).normalized()
	return Basis(right, up, right.cross(up).normalized()).get_rotation_quaternion()

func step(body: FlightBody, planet: PlanetDefinition, manual: Vector3, dt: float) -> void:
	var accel := Vector3.ZERO
	var using_manual: bool = manual.length_squared() > 0.001
	if using_manual:
		accel = (manual * max_rate - body.angular_velocity) * 3.0
		target = body.orientation
	elif mode != Mode.OFF:
		var direction := Vector3.ZERO
		var speed := body.velocity
		if body.position.length() - planet.radius < planet.atmosphere.height:
			speed = speed.minus(PlanetPhysics.air_velocity(body.position, planet))
		match mode:
			Mode.PROGRADE: direction = speed.vec()
			Mode.RETROGRADE: direction = -speed.vec()
			Mode.RADIAL_OUT: direction = body.position.vec()
			Mode.RADIAL_IN: direction = -body.position.vec()
			Mode.NORMAL: direction = body.position.cross(body.velocity).vec()
			Mode.ANTINORMAL: direction = -body.position.cross(body.velocity).vec()
		if direction.length_squared() > 1.0:
			target = pointing(direction, body.orientation)
		var error: Quaternion = (body.orientation.inverse() * target).normalized()
		if error.w < 0:
			error = Quaternion(-error.x, -error.y, -error.z, -error.w)
		var axis := Vector3(error.x, error.y, error.z)
		var angle: float = 2.0 * atan2(axis.length(), error.w)
		var desired_rate: Vector3 = axis.normalized() * minf(angle * 1.8, max_rate)
		accel = (desired_rate - body.angular_velocity) * 4.0
	accel = accel.limit_length(max_acceleration)
	var moments: Vector3 = body.inertia()
	# Euler rigid-body equation in body coordinates: I*w_dot = torque - w × Iw.
	last_torque = (moments * accel).limit_length(moments.x * max_acceleration)
	body.integrate_attitude(last_torque, dt)
	if using_manual:
		target = body.orientation

class_name KeplerCoast
extends RefCounted
## Universal-variable two-body propagation. Same Newtonian trajectory as the
## force integrator, solved analytically in vacuum for high time acceleration.
## See docs/DEVELOPMENT_JOURNAL.md for derivation references and tested tolerances.

static func c(z: float) -> float:
	if absf(z) < 0.001:
		return 0.5 - z / 24.0 + z * z / 720.0 - z * z * z / 40320.0 + pow(z, 4) / 3628800.0
	if z > 0:
		return (1.0 - cos(sqrt(z))) / z
	return (cosh(sqrt(-z)) - 1.0) / -z

static func s(z: float) -> float:
	if absf(z) < 0.001:
		return 1.0 / 6.0 - z / 120.0 + z * z / 5040.0 - z * z * z / 362880.0 + pow(z, 4) / 39916800.0
	if z > 0:
		var root: float = sqrt(z)
		return (root - sin(root)) / (root * root * root)
	var root: float = sqrt(-z)
	return (sinh(root) - root) / (root * root * root)

static func advance(body: FlightBody, planet: PlanetDefinition, dt: float) -> bool:
	if body.crashed or dt == 0:
		return true
	var r0: float = body.position.length()
	var mu: float = planet.mu()
	var root_mu: float = sqrt(mu)
	var alpha: float = 2.0 / r0 - body.velocity.length_squared() / mu
	var rv: float = body.position.dot(body.velocity) / root_mu
	var chi: float = root_mu * dt / r0
	var converged: bool = false
	for iteration in range(32):
		var z: float = alpha * chi * chi
		if not is_finite(z) or z < -1600.0:
			return false
		var cz: float = c(z)
		var sz: float = s(z)
		var residual: float = rv * chi * chi * cz + (1.0 - alpha * r0) * chi * chi * chi * sz + r0 * chi - root_mu * dt
		var derivative: float = rv * chi * (1.0 - z * sz) + (1.0 - alpha * r0) * chi * chi * cz + r0
		if absf(derivative) < 1.0e-12:
			return false
		var correction: float = residual / derivative
		chi -= correction
		if absf(correction) < 1.0e-9:
			converged = true
			break
	if not converged:
		return false
	var z: float = alpha * chi * chi
	var cz: float = c(z)
	var sz: float = s(z)
	var f: float = 1.0 - chi * chi * cz / r0
	var g: float = dt - chi * chi * chi * sz / root_mu
	var new_position := body.position.scaled(f).plus(body.velocity.scaled(g))
	var r1: float = new_position.length()
	var fdot: float = root_mu * chi * (z * sz - 1.0) / (r1 * r0)
	var gdot: float = 1.0 - chi * chi * cz / r1
	var new_velocity := body.position.scaled(fdot).plus(body.velocity.scaled(gdot))
	if not is_finite(r1) or not is_finite(new_velocity.length_squared()):
		return false
	body.position = new_position
	body.velocity = new_velocity
	body.gravity = PlanetPhysics.gravity(body.position, planet)
	body.acceleration = body.gravity
	body.thrust_force = DVec3.new()
	body.sample_atmosphere(planet)
	return true

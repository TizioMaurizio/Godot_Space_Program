class_name TimeWarp
extends RefCounted

const RATES: Array[int] = [1, 2, 3, 4, 10, 50, 100, 1000]
const MAX_PHYSICS_INDEX: int = 3
const ENTRY_MARGIN: float = 1000.0
var index: int = 0
var notice: String = ""

func rate() -> int:
	return RATES[index]

func is_coasting() -> bool:
	return index > MAX_PHYSICS_INDEX

func reset(message: String = "") -> void:
	index = 0
	notice = message

func change(direction: int, rocket: RocketState, planet: PlanetDefinition) -> void:
	planet = rocket.reference_body
	var maximum: int = RATES.size() - 1
	var altitude: float = rocket.relative_position().length() - planet.radius
	if rocket.on_pad or rocket.crashed:
		reset("Launch before increasing time warp")
		return
	if altitude <= planet.atmosphere.height + ENTRY_MARGIN or rocket.throttle > 0.0:
		maximum = MAX_PHYSICS_INDEX
	var requested: int = clampi(index + direction, 0, maximum)
	notice = ""
	if direction > 0 and requested == index:
		notice = "Physics warp limited to 4x in air or under thrust" if maximum == MAX_PHYSICS_INDEX else "Maximum coast warp: 1000x"
	index = requested

func enforce(rocket: RocketState, planet: PlanetDefinition, manual: Vector3, throttle_input: float) -> void:
	planet = rocket.reference_body
	if rocket.crashed or rocket.on_pad:
		reset()
	elif is_coasting():
		if rocket.throttle > 0.0 or manual.length_squared() > 0.0 or throttle_input != 0.0:
			reset("Flight input: normal speed")
		elif not vacuum_interval_safe(rocket, planet, rate() / 60.0):
			reset("Approaching atmosphere: normal speed")

static func vacuum_interval_safe(body: FlightBody, planet: PlanetDefinition, dt: float) -> bool:
	var position: DVec3 = body.relative_position() if body is RocketState else body.position
	var velocity: DVec3 = body.relative_velocity() if body is RocketState else body.velocity
	var terrain_height: float = planet.terrain.maximum_height if planet.terrain != null else 0.0
	var safe_height: float = maxf(planet.atmosphere.height,terrain_height)+ENTRY_MARGIN
	var boundary: float = planet.radius + safe_height
	var gap: float = position.length() - boundary
	if gap <= 0:
		return false
	var elements := OrbitalMechanics.elements(position, velocity, planet)
	if elements.periapsis > safe_height:
		return true
	# A bound on distance travelled before the first boundary crossing protects
	# the entire interval (including trajectories that would enter AND exit it).
	var maximum_gravity: float = planet.mu() / (boundary * boundary)
	return gap > velocity.length() * dt + 0.5 * maximum_gravity * dt * dt

class_name LegacyRocketState
extends FlightBody

var definition: VehicleDefinition
var stages: Array[RocketStage] = []
var stage_index: int = 0
var throttle: float = 0.0
var ignited: bool = false
var on_pad: bool = true
var elapsed: float = 0.0
var launch_time: float = -1.0
var controller := AttitudeController.new()
var peak_q: float = 0.0
var thrust: float = 0.0

func _init(config: VehicleDefinition, planet: PlanetDefinition) -> void:
	definition = config
	for config_stage in config.stages:
		stages.append(RocketStage.new(config_stage))
	refresh_structure()
	position = DVec3.new(0.0, planet.radius + length * 0.5 + 1.0, 0.0)
	velocity = PlanetPhysics.air_velocity(position, planet)

func refresh_structure() -> void:
	mass = definition.payload_mass
	length = definition.payload_length
	for i in range(stage_index, stages.size()):
		mass += stages[i].mass()
		length += stages[i].definition.length
	if stage_index < stages.size():
		radius = stages[stage_index].definition.radius
		drag_coefficient = stages[stage_index].definition.drag_coefficient
		side_drag_coefficient = stages[stage_index].definition.side_drag_coefficient
		pressure_center_fraction = stages[stage_index].definition.pressure_center_fraction
		aerodynamic_damping = stages[stage_index].definition.aerodynamic_damping
	area = PI * radius * radius

func current_stage() -> RocketStage:
	return stages[stage_index] if stage_index < stages.size() else null

func activate_stage() -> FlightBody:
	if crashed:
		return null
	if not ignited:
		ignited = true
		return null
	# The last stage remains attached; capsule separation is outside this milestone.
	if on_pad or stage_index >= stages.size() - 1:
		return null
	var old_stage: RocketStage = stages[stage_index]
	var debris := FlightBody.new()
	debris.mass = old_stage.mass()
	debris.length = old_stage.definition.length
	debris.radius = old_stage.definition.radius
	debris.area = PI * debris.radius * debris.radius
	debris.drag_coefficient = 0.6
	debris.pressure_center_fraction = old_stage.definition.pressure_center_fraction
	debris.side_drag_coefficient = old_stage.definition.side_drag_coefficient
	debris.aerodynamic_damping = old_stage.definition.aerodynamic_damping
	debris.orientation = orientation
	debris.angular_velocity = angular_velocity + Vector3(0.02, 0.0, 0.025)
	stage_index += 1
	refresh_structure()
	var axis := DVector.from_vec(orientation * Vector3.UP)
	var separation: float = (length + debris.length) * 0.5 + 0.5
	var total: float = mass + debris.mass
	debris.position = position.minus(axis.scaled(separation * mass / total))
	position = position.plus(axis.scaled(separation * debris.mass / total))
	debris.velocity = velocity.minus(axis.scaled(2.0 * mass / total))
	velocity = velocity.plus(axis.scaled(2.0 * debris.mass / total))
	return debris

func step(dt: float, planet: PlanetDefinition, manual: Vector3 = Vector3.ZERO) -> void:
	if crashed:
		return
	elapsed += dt
	var altitude: float = position.length() - planet.radius
	var pressure: float = PlanetPhysics.pressure(altitude, planet.atmosphere)
	var old_mass: float = mass
	thrust = current_stage().burn(dt, throttle if ignited else 0.0, pressure / 101325.0)
	refresh_structure()
	var final_mass: float = mass
	mass = (old_mass + final_mass) * 0.5
	if on_pad:
		var angle: float = planet.rotation_rate * elapsed
		var r: float = planet.radius + length * 0.5 + 1.0
		position = DVec3.new(-sin(angle) * r, cos(angle) * r, 0.0)
		velocity = PlanetPhysics.air_velocity(position, planet)
		orientation = Quaternion(Vector3.BACK, angle)
		controller.target = orientation
		if thrust > mass * PlanetPhysics.gravity(position, planet).length():
			on_pad = false
			launch_time = elapsed
	else:
		sample_atmosphere(planet)
		controller.step(self, planet, manual, dt)
	if not on_pad:
		integrate(dt, planet, DVector.from_vec(orientation * Vector3.UP).scaled(thrust))
		if position.length() <= planet.radius + length * 0.4:
			crashed = true
			throttle = 0.0
			thrust = 0.0
			velocity = PlanetPhysics.air_velocity(position, planet)
		peak_q = maxf(peak_q, dynamic_pressure)
	mass = final_mass

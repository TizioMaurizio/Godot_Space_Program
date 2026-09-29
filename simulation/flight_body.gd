class_name FlightBody
extends RefCounted

var position := DVec3.new()
var velocity := DVec3.new()
var orientation := Quaternion.IDENTITY
var angular_velocity := Vector3.ZERO
var mass: float = 1000.0
var area: float = 7.0
var drag_coefficient: float = 0.3
var side_drag_coefficient: float = 0.8
var pressure_center_fraction: float = -0.12
var aerodynamic_damping: float = 0.5
var length: float = 20.0
var radius: float = 1.5
var crashed: bool = false
var gravity := DVec3.new()
var atmosphere_velocity := DVec3.new()
var air_velocity := DVec3.new()
var drag_force := DVec3.new()
var thrust_force := DVec3.new()
var acceleration := DVec3.new()
var density: float = 0.0
var dynamic_pressure: float = 0.0
var aerodynamic_torque := Vector3.ZERO
var damping_coefficient := Vector3.ZERO
## Qualitative convective-heating proxy for FX, not a thermal damage simulation.
var heating: float = 0.0

func sample_atmosphere(planet: PlanetDefinition) -> void:
	atmosphere_velocity = PlanetPhysics.air_velocity(position, planet)
	air_velocity = velocity.minus(atmosphere_velocity)
	density = PlanetPhysics.density(position.length() - planet.radius, planet.atmosphere)
	dynamic_pressure = Aerodynamics.dynamic_pressure(air_velocity, density)
	drag_force = Aerodynamics.drag(air_velocity, density, 1.0, Aerodynamics.drag_area(self, air_velocity))
	aerodynamic_torque = Aerodynamics.moment(self)
	damping_coefficient = Aerodynamics.damping(self)
	heating = clampf(sqrt(density) * pow(air_velocity.length() / 2200.0, 3.0) / 0.2, 0.0, 1.0)

func integrate_attitude(control_torque: Vector3, dt: float) -> void:
	var moments: Vector3 = inertia()
	var gyroscopic: Vector3 = angular_velocity.cross(moments * angular_velocity)
	# Semi-implicit angular step; implicit drag damping cannot add spin energy.
	angular_velocity = (angular_velocity + (control_torque + aerodynamic_torque - gyroscopic) / moments * dt) / (Vector3.ONE + damping_coefficient / moments * dt)
	var rate: float = angular_velocity.length()
	if rate > 1.0e-8:
		orientation = (orientation * Quaternion(angular_velocity / rate, rate * dt)).normalized()

func integrate(dt: float, planet: PlanetDefinition, thrust: DVec3) -> void:
	if crashed:
		return
	thrust_force = thrust
	gravity = PlanetPhysics.gravity(position, planet)
	sample_atmosphere(planet)
	var a0 := gravity.plus(drag_force.plus(thrust).scaled(1.0 / mass))
	var half_velocity := velocity.plus(a0.scaled(dt * 0.5))
	position = position.plus(half_velocity.scaled(dt))
	var predicted_velocity := velocity.plus(a0.scaled(dt))
	var rho1 := PlanetPhysics.density(position.length() - planet.radius, planet.atmosphere)
	var air1 := predicted_velocity.minus(PlanetPhysics.air_velocity(position, planet))
	var drag1 := Aerodynamics.drag(air1, rho1, 1.0, Aerodynamics.drag_area(self, air1))
	var a1 := PlanetPhysics.gravity(position, planet).plus(drag1.plus(thrust).scaled(1.0 / mass))
	velocity = half_velocity.plus(a1.scaled(dt * 0.5))
	acceleration = a0.plus(a1).scaled(0.5)

func inertia() -> Vector3:
	var transverse: float = mass * (3.0 * radius * radius + length * length) / 12.0
	return Vector3(transverse, 0.5 * mass * radius * radius, transverse)

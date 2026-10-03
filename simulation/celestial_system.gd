class_name CelestialSystem
extends RefCounted
## Circular prescribed ephemerides, one shared epoch, patched conics.
var primary: PlanetDefinition
var moons: Array[CelestialBodyDefinition] = []
var time: float = 0

func _init(home: PlanetDefinition) -> void:
	primary = home
	moons.append(load("res://data/neris.tres"))

func ephemeris(body: PlanetDefinition, epoch: float) -> Dictionary:
	if body == primary or not body is CelestialBodyDefinition: return {"position":DVec3.new(),"velocity":DVec3.new()}
	var moon: CelestialBodyDefinition = body
	var n: float = sqrt(primary.mu()/pow(moon.orbit_radius,3))
	var angle: float = moon.orbit_phase+n*epoch
	var c: float = cos(moon.orbit_inclination); var s: float = sin(moon.orbit_inclination)
	return {"position":DVec3.new(cos(angle),sin(angle)*c,sin(angle)*s).scaled(moon.orbit_radius),"velocity":DVec3.new(-sin(angle),cos(angle)*c,cos(angle)*s).scaled(moon.orbit_radius*n)}

func dominant(position: DVec3, epoch: float) -> PlanetDefinition:
	for moon in moons:
		if position.minus(ephemeris(moon,epoch).position).length() < moon.sphere_of_influence(primary): return moon
	return primary

func interval_safe(position: DVec3, velocity: DVec3, body: PlanetDefinition, epoch: float, dt: float) -> bool:
	# Conservative bound guards the WHOLE interval, including enter-and-exit flybys.
	for moon in moons:
		var state := ephemeris(moon,epoch)
		var distance: float = position.minus(state.position).length()
		var soi: float = moon.sphere_of_influence(primary)
		var gap: float = absf(distance-soi)
		var speed: float = velocity.minus(state.velocity).length()
		# Maximum exterior gravity, not gravity at a linearly extrapolated radius:
		# acceleration may increase during the interval being bounded.
		var acceleration_bound: float = primary.mu()/pow(primary.radius,2)+primary.mu()/pow(moon.orbit_radius,2)
		if body == moon: acceleration_bound += moon.mu()/pow(moon.radius,2)
		if gap <= speed*dt+0.5*acceleration_bound*dt*dt+1.0: return false
	return true

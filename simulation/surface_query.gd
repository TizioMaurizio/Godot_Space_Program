class_name SurfaceQuery
extends RefCounted
## Authoritative body-fixed terrain and water fields; renderer samples these too.

static func to_fixed(p: DVec3, planet: PlanetDefinition, time: float) -> DVec3:
	var tilt: float = planet.axial_tilt
	var y: float = cos(tilt)*p.y+sin(tilt)*p.z
	var z: float = -sin(tilt)*p.y+cos(tilt)*p.z
	var angle: float = planet.rotation_rate*time
	return DVec3.new(cos(angle)*p.x+sin(angle)*y,-sin(angle)*p.x+cos(angle)*y,z)

static func to_inertial(p: DVec3, planet: PlanetDefinition, time: float) -> DVec3:
	var angle: float = planet.rotation_rate*time
	var x: float = cos(angle)*p.x-sin(angle)*p.y
	var y: float = sin(angle)*p.x+cos(angle)*p.y
	var tilt: float = planet.axial_tilt
	return DVec3.new(x,cos(tilt)*y-sin(tilt)*p.z,sin(tilt)*y+cos(tilt)*p.z)

static func rotation(planet: PlanetDefinition, time: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT,planet.axial_tilt)*Quaternion(Vector3.BACK,fposmod(planet.rotation_rate*time,TAU))

static func height_fixed(planet: PlanetDefinition, direction: DVec3) -> float:
	if planet.terrain == null: return 0
	var terrain: TerrainDefinition = planet.terrain
	var x: float = direction.x; var y: float = direction.y; var z: float = direction.z
	var height: float
	if terrain.style == "flat":
		height = terrain.height_scale
	elif terrain.style == "lunar":
		height = 350*sin(x*19+y*7)*cos(z*21-y*4)+140*sin(x*80+z*51)*cos(y*66)
		terrain.ensure_craters()
		var n: Vector3 = direction.vec()
		for crater in terrain.craters:
			if n.dot(crater.direction) < 1.0-crater.radius*crater.radius: continue
			var distance: float = direction.minus(crater.center).length()/crater.radius
			if distance < 1.4:
				height += crater.depth*(0.3*exp(-pow((distance-1.0)*7.0,2))-0.65*exp(-pow(distance*1.6,4)))
	else:
		var continent: float = sin(x*5+sin(y*3)*0.7)+0.6*cos(z*6-y*2)+0.35*sin(x*11+z*9)
		var mountains: float = pow(1-absf(sin(x*12+z*9+y*4)),6)*smoothstep(0.3,1.0,continent)*1800
		height = (continent-0.35)*terrain.height_scale+mountains
		height += sin(x*85+y*52)*cos(z*73-x*11)*100*smoothstep(-0.2,0.5,continent)
		height += sin(x*800+y*230)*cos(z*740+y*210)*10
	if terrain.launch_plateau:
		var distance: float = direction.minus(DVec3.new(0,1,0)).length()*planet.radius
		height = lerpf(terrain.launch_plateau_height,height,smoothstep(200,1200,distance))
	return height

static func height(planet: PlanetDefinition, position: DVec3, time: float) -> float:
	var fixed := to_fixed(position.unit(),planet,time)
	var result: float = height_fixed(planet,fixed)
	if planet.terrain != null and planet.terrain.launch_plateau:
		var distance: float = fixed.minus(DVec3.new(0,1,0)).length()*planet.radius
		if distance < 3.8: result += 0.865
		elif distance < 8.0: result += 0.755
		elif distance < 18.0: result += 0.6
	return result

static func normal(planet: PlanetDefinition, position: DVec3, time: float) -> DVec3:
	var up := position.unit()
	var reference := DVec3.new(0,0,1) if absf(up.z) < 0.9 else DVec3.new(1,0,0)
	var east := reference.cross(up).unit(); var north := up.cross(east).unit()
	var epsilon: float = 1.0/planet.radius
	var dx: float = (height(planet,up.plus(east.scaled(epsilon)).unit(),time)-height(planet,up.minus(east.scaled(epsilon)).unit(),time))*0.5
	var dz: float = (height(planet,up.plus(north.scaled(epsilon)).unit(),time)-height(planet,up.minus(north.scaled(epsilon)).unit(),time))*0.5
	return up.minus(east.scaled(dx)).minus(north.scaled(dz)).unit()

static func wave_height(planet: PlanetDefinition, fixed_position: DVec3, time: float) -> float:
	if planet.ocean == null: return 0
	var k: float = TAU/planet.ocean.wavelength
	return planet.ocean.wave_amplitude*(sin(fixed_position.x*k+time*0.9)+0.4*sin(fixed_position.z*k*1.43-time*1.3)+0.2*sin(fixed_position.y*k*0.71+time*0.6))

static func wave_velocity(planet: PlanetDefinition, fixed_position: DVec3, time: float) -> float:
	if planet.ocean == null: return 0
	var k: float = TAU/planet.ocean.wavelength
	return planet.ocean.wave_amplitude*(0.9*cos(fixed_position.x*k+time*0.9)-0.52*cos(fixed_position.z*k*1.43-time*1.3)+0.12*cos(fixed_position.y*k*0.71+time*0.6))

static func water_radius(planet: PlanetDefinition, position: DVec3, time: float) -> float:
	if planet.ocean == null: return -INF
	return planet.radius+planet.ocean.sea_level+wave_height(planet,to_fixed(position,planet,time),time)

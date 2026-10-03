extends SceneTree
## Test-only guidance: all authoritative changes are throttle/staging/SAS commands.
var home: PlanetDefinition
var rocket: RocketState
var session: FlightSession
var phase: String = "ASCENT"
var failures: int = 0
var moon: CelestialBodyDefinition
var log_clock: float = -100

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1
func tick(dt: float = 1.0/120) -> void:
	session.step(dt,Vector3.ZERO)
func orbit() -> Dictionary:
	return OrbitalMechanics.elements(rocket.relative_position(),rocket.relative_velocity(),rocket.reference_body)
func coast(seconds: float) -> void:
	var until: float = rocket.elapsed+seconds
	while rocket.elapsed < until-1e-8 and not rocket.crashed:
		# Same distant-debris lifecycle as main.gd; no active-craft state alteration.
		for body in session.registry.bodies.duplicate():
			if body != rocket and body.position.minus(rocket.position).length() > 200000: session.registry.bodies.erase(body)
		var dt: float = minf(10,until-rocket.elapsed)
		if not session.coast(dt): tick(minf(1.0/120,dt))
func settle(mode: AttitudeController.Mode, seconds: float = 20) -> void:
	rocket.throttle = 0; rocket.controller.set_mode(mode,rocket.orientation)
	for i in range(int(seconds*120)): tick()
func status(label: String) -> void:
	var o := orbit()
	print("MISSION %s t=%.2f body=%s h=%.3fkm Ap=%.3f Pe=%.3f v=%.2f fuel=%.1f%%"%[label,rocket.elapsed,rocket.reference_body.display_name,(rocket.relative_position().length()-rocket.reference_body.radius)/1000,o.apoapsis/1000,o.periapsis/1000,rocket.relative_velocity().length(),rocket.current_stage().fraction()*100])
func run() -> void:
	home = load("res://data/aster.tres")
	rocket = RocketState.new(CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json"),home)
	session = FlightSession.new(rocket,home); moon = session.celestial.moons[0]
	rocket.throttle = 1; rocket.activate_stage()
	for i in range(120*1000):
		var data := FlightComputer.read(rocket,home); var o: Dictionary = data.orbit
		if rocket.crashed: break
		if rocket.current_stage().fraction() < 0.001 and rocket.stage_index == 0: rocket.activate_stage()
		if phase == "ASCENT":
			var h: float = data.altitude; var pitch: float
			if h < 1000: pitch = 90
			elif h < 5000: pitch = lerpf(88,65,(h-1000)/4000)
			elif h < 20000: pitch = lerpf(65,35,(h-5000)/15000)
			else: pitch = maxf(5,lerpf(35,5,(h-20000)/25000))
			rocket.controller.target = AttitudeController.pointing(data.up*sin(deg_to_rad(pitch))+data.east*cos(deg_to_rad(pitch)),rocket.orientation)
			if o.apoapsis > 120000:
				phase = "COAST"; rocket.throttle = 0
				if rocket.stage_index == 0: rocket.activate_stage()
				rocket.controller.set_mode(AttitudeController.Mode.PROGRADE,rocket.orientation)
		elif phase == "COAST":
			if o.time_to_ap < 50 or data.vertical_speed < 0: phase = "INSERTION"; rocket.throttle = 1
		elif phase == "INSERTION" and o.periapsis > 65000 and o.stable:
			rocket.throttle = 0; phase = "ORBIT"; break
		tick()
	check(phase == "ORBIT" and not rocket.crashed,"physical launch establishes Aster orbit")
	if failures: finish(); return
	status("ASTER ORBIT")
	coast(maxf(0,orbit().time_to_ap-24)); settle(AttitudeController.Mode.PROGRADE)
	rocket.throttle = 0.3
	for i in range(120*80):
		if orbit().periapsis > 145000: break
		tick()
	rocket.throttle = 0; status("PARKING ORBIT")
	var target_radius: float = moon.orbit_radius-50000
	var parking: float = rocket.position.length()
	var transfer_time: float = PI*sqrt(pow((parking+target_radius)*0.5,3)/home.mu())
	var moon_rate: float = sqrt(home.mu()/pow(moon.orbit_radius,3))
	var desired_phase: float = PI-moon_rate*transfer_time+0.065
	# Leave enough time for pointing and the finite-duration injection burn.
	for i in range(4000):
		var moon_p: DVec3 = session.celestial.ephemeris(moon,rocket.elapsed).position
		var angle: float = fposmod(atan2(moon_p.y,moon_p.x)-atan2(rocket.position.y,rocket.position.x),TAU)
		if absf(wrapf(angle-desired_phase,-PI,PI)) < 0.008: break
		coast(2)
	settle(AttitudeController.Mode.PROGRADE,12)
	rocket.throttle = 1
	for i in range(120*180):
		var o := orbit()
		if o.apoapsis+home.radius >= target_radius: break
		tick()
	rocket.throttle = 0; status("TLI")
	var predicted := PatchedConicPrediction.predict(session.celestial,rocket.position,rocket.velocity,rocket.elapsed,10000)
	print("MISSION forecast: %s lunar Pe %.3f km"%[predicted.encounters,predicted.lunar_periapsis/1000])
	var entry_deadline: float = rocket.elapsed+14000
	while rocket.reference_body == home and rocket.elapsed < entry_deadline and not rocket.crashed: coast(10)
	check(rocket.reference_body == moon,"translunar burn reaches Neris SOI through propagated flight")
	if failures: finish(); return
	status("NERIS ENTRY")
	# Correct the approach with actual tangential thrust to clear the terrain.
	rocket.controller.set_mode(AttitudeController.Mode.HOLD,rocket.orientation)
	for i in range(120*120):
		var p := rocket.relative_position(); var v := rocket.relative_velocity()
		var tangent := p.cross(v).unit().cross(p.unit()).unit()
		rocket.controller.target = AttitudeController.pointing(tangent.vec(),rocket.orientation)
		var alignment: float = (rocket.orientation*Vector3.UP).dot(tangent.vec())
		rocket.throttle = 0.35 if alignment > 0.998 else 0
		if orbit().periapsis > 25000: break
		tick()
	rocket.throttle = 0; status("APPROACH CORRECTION")
	var entry := orbit()
	check(entry.periapsis > 2000,"encounter periapsis clears lunar terrain")
	if failures: finish(); return
	while rocket.relative_position().dot(rocket.relative_velocity()) < 0 and rocket.relative_position().length() > moon.radius+entry.periapsis+5000:
		coast(2)
	settle(AttitudeController.Mode.RETROGRADE,20)
	rocket.throttle = 0.25
	for i in range(120*250):
		var o := orbit()
		if o.bound and o.apoapsis < 110000 and o.periapsis > 2000: break
		tick()
	rocket.throttle = 0; status("LUNAR CAPTURE")
	check(orbit().bound and orbit().apoapsis < moon.sphere_of_influence(home)-moon.radius and orbit().periapsis > 2000,"retrograde engine burn establishes a safe lunar orbit")
	if failures: finish(); return
	var lunar_orbit := orbit(); var mass: float = rocket.mass
	coast(lunar_orbit.period)
	check(rocket.reference_body == moon and absf(orbit().periapsis-lunar_orbit.periapsis) < 0.1 and rocket.mass == mass,"complete unpowered lunar orbit conserves mass and periapsis")
	status("LUNAR ORBIT COMPLETE")
	# Depart on the trailing side: thrust points opposite the Moon's Aster motion.
	for i in range(4000):
		var moon_v: DVec3 = session.celestial.ephemeris(moon,rocket.elapsed).velocity
		if rocket.relative_velocity().unit().dot(moon_v.unit()) < -0.98: break
		coast(2)
	settle(AttitudeController.Mode.PROGRADE,12)
	rocket.throttle = 0.35
	for i in range(120*300):
		var o := orbit()
		if o.energy > 110000: break
		tick()
	rocket.throttle = 0; status("LUNAR DEPARTURE")
	var escape_deadline: float = rocket.elapsed+8000
	while rocket.reference_body == moon and rocket.elapsed < escape_deadline and not rocket.crashed: coast(5)
	check(rocket.reference_body == home,"propagated hyperbolic departure escapes Neris")
	if failures: finish(); return
	status("ASTER RETURN CONIC")
	settle(AttitudeController.Mode.RETROGRADE,20)
	rocket.throttle = 0.25
	for i in range(120*300):
		if orbit().periapsis < 35000: break
		tick()
	rocket.throttle = 0; status("RETURN CORRECTION")
	check(orbit().periapsis < 60000,"departure and optional correction trajectory intersects Aster atmosphere")
	var return_deadline: float = rocket.elapsed+30000
	while rocket.position.length() > home.radius+60000 and rocket.elapsed < return_deadline and not rocket.crashed: coast(10)
	check(rocket.reference_body == home and rocket.position.length() <= home.radius+60000,"spacecraft physically returns to Aster atmosphere")
	status("ASTER RETURN")
	finish()
func finish() -> void:
	print("RESULT: %d failures"%failures)
	call_deferred("quit",1 if failures else 0)

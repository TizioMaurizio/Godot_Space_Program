extends SceneTree
## Test-only pilot: torque-controller setpoints, throttle and stage commands.
## Never changes position, velocity, attitude, gravity or orbit classification.

func _initialize() -> void:
	var planet: PlanetDefinition = load("res://data/aster.tres")
	var vehicle: VehicleDefinition = load("res://data/orbital_test_vehicle.tres")
	var rocket := RocketState.new(vehicle, planet)
	rocket.throttle = 1.0
	rocket.activate_stage()
	var phase: String = "ASCENT"
	var dt: float = 1.0 / 120.0
	var reached: bool = false
	var first_orbit: Dictionary = {}
	var pitch: float = 90.0
	var manual_pilot: bool = "--manual-pilot" in OS.get_cmdline_user_args()
	var manual := Vector3.ZERO
	print("Pilot: %s" % ("discrete W/S inputs, HOLD, then PROGRADE" if manual_pilot else "torque-controller attitude targets"))
	for i in range(120 * 1000):
		var data := FlightComputer.read(rocket, planet)
		var orbit: Dictionary = data.orbit
		if i % 2400 == 0:
			print("t=%5.0f  %-10s h=%7.1f km  v=%6.0f  pitch=%5.1f  Ap=%7.1f Pe=%7.1f  TAp=%5.0f  stage=%d prop=%.0f%%" % [rocket.elapsed, phase, data.altitude / 1000, data.orbital_speed, data.pitch, orbit.apoapsis / 1000, orbit.periapsis / 1000, orbit.time_to_ap, rocket.stage_index + 1, rocket.current_stage().fraction() * 100])
		if rocket.crashed:
			break
		if rocket.current_stage().fraction() < 0.001 and rocket.stage_index == 0:
			rocket.activate_stage()
		if phase == "ASCENT":
			var altitude: float = data.altitude
			if altitude < 1000:
				pitch = 90.0
			elif altitude < 5000:
				pitch = lerpf(88.0, 65.0, (altitude - 1000) / 4000)
			elif altitude < 20000:
				pitch = lerpf(65.0, 35.0, (altitude - 5000) / 15000)
			else:
				pitch = maxf(5.0, lerpf(35.0, 5.0, (altitude - 20000) / 25000))
			var direction: Vector3 = data.up * sin(deg_to_rad(pitch)) + data.east * cos(deg_to_rad(pitch))
			if manual_pilot:
				# Decide at 10 Hz, with a one-degree deadband, as a player tapping W/S.
				if i % 12 == 0:
					manual.z = signf(data.pitch - pitch) if absf(data.pitch - pitch) > 1.0 else 0.0
			else:
				rocket.controller.target = AttitudeController.pointing(direction, rocket.orientation)
			if orbit.apoapsis > 120000:
				phase = "COAST"
				manual = Vector3.ZERO
				rocket.throttle = 0.0
				if rocket.stage_index == 0:
					rocket.activate_stage()
				rocket.controller.set_mode(AttitudeController.Mode.PROGRADE, rocket.orientation)
		elif phase == "COAST":
			if orbit.time_to_ap < 50.0 or data.vertical_speed < 0:
				phase = "INSERTION"
				rocket.throttle = 1.0
		elif phase == "INSERTION":
			if orbit.periapsis > 65000 and orbit.stable:
				rocket.throttle = 0.0
				reached = true
				first_orbit = orbit
				print("ORBIT ACHIEVED at %.2f s: Ap %.3f km / Pe %.3f km; propellant %.1f%%; max-Q %.3f kPa" % [rocket.elapsed, orbit.apoapsis / 1000, orbit.periapsis / 1000, rocket.current_stage().fraction() * 100, rocket.peak_q / 1000])
				break
		rocket.step(dt, planet, manual)
	if not reached:
		printerr("FAIL: launch-to-orbit pilot did not reach stable orbit")
		quit(1)
		return
	var mass_at_cutoff: float = rocket.mass
	for i in range(int(first_orbit.period / dt)):
		rocket.step(dt, planet)
	var final := FlightComputer.read(rocket, planet)
	var drift: float = absf(final.orbit.periapsis - first_orbit.periapsis)
	var passed: bool = final.orbit.stable and drift < 5.0 and rocket.mass == mass_at_cutoff and not rocket.crashed
	print("%s: one complete engine-off orbit; periapsis drift %.6f m; mass unchanged %s" % ["PASS" if passed else "FAIL", drift, rocket.mass == mass_at_cutoff])
	quit(0 if passed else 1)

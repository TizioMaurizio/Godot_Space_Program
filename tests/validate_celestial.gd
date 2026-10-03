extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1
func _initialize() -> void:
	var home: PlanetDefinition = load("res://data/aster.tres")
	var craft := RocketState.new(CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json"),home)
	craft.on_pad = false
	var session := FlightSession.new(craft,home); var moon := session.celestial.moons[0]
	var frame := session.celestial.ephemeris(moon,0)
	var r: float = moon.radius+25000
	craft.position = frame.position.plus(DVec3.new(0,r,0))
	craft.velocity = frame.velocity.plus(DVec3.new(-sqrt(moon.mu()/r),0,0))
	var p := craft.position; var v := craft.velocity
	session.update_reference(craft)
	check(craft.reference_body == moon and craft.position == p and craft.velocity == v,"SOI selection preserves inertial state exactly")
	check(absf(craft.relative_position().length()-r) < 1e-8,"lunar relative frame derives from inertial double state")
	var initial := OrbitalMechanics.elements(craft.relative_position(),craft.relative_velocity(),moon)
	var direct := RocketState.new(craft.definition,home); direct.on_pad = false; direct.position = p; direct.velocity = v
	var normal := FlightSession.new(direct,home)
	for i in range(120*30): normal.step(1.0/120,Vector3.ZERO)
	check(session.coast(30),"lunar orbit supports analytical coast")
	check(craft.position.minus(direct.position).length() < 0.05 and craft.velocity.minus(direct.velocity).length() < 0.001,"lunar force/coast agree over 30 s within 5 cm / 1 mm/s")
	for i in range(300): session.coast(initial.period/300)
	var final := OrbitalMechanics.elements(craft.relative_position(),craft.relative_velocity(),moon)
	check(absf(final.periapsis-initial.periapsis) < 0.01,"one lunar coast orbit preserves periapsis within 1 cm")
	check(craft.density == 0,"Neris is airless")
	var soi: float = moon.sphere_of_influence(home)
	var start: DVec3 = frame.position.plus(DVec3.new(soi+10000,0,0)); var fast: DVec3 = frame.velocity.plus(DVec3.new(-5000,0,0))
	check(not session.celestial.interval_safe(start,fast,home,0,200),"whole-interval warp guard rejects an enter-and-exit SOI flyby")
	var prediction := PatchedConicPrediction.predict(session.celestial,start,fast,0,180)
	check(prediction.encounters.size() >= 1 and prediction.encounters[0].to == "Neris","timed prediction detects Neris encounter")
	check(is_finite(prediction.lunar_periapsis),"prediction reports lunar closest approach")
	check(start.x == frame.position.x+soi+10000,"prediction leaves source state unchanged")
	print("RESULT: %d failures"%failures)
	call_deferred("quit",1 if failures else 0)

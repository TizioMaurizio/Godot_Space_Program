extends SceneTree
func _initialize() -> void:
	var planet: PlanetDefinition = load("res://data/aster.tres")
	var base := CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
	for count in [10,50,100,300]:
		var design := CraftDesign.new(); design.root_part_id = "tank_0"
		for i in range(count):
			var part: Dictionary = base.parts[1].duplicate(true); part.id = "tank_%d"%i; part.position_m = [0,-i*6.5,0]; design.parts.append(part)
			if i > 0: design.connections.append({"id":"c%d"%i,"a":["tank_%d"%(i-1),"bottom"],"b":[part.id,"top"],"crossfeed":true})
		var craft := RocketState.new(design,planet); craft.on_pad = false; craft.structural_failure_enabled = false
		craft.controller.set_mode(AttitudeController.Mode.OFF,craft.orientation)
		for altitude in [150000,20000]:
			craft.position = DVec3.new(0,planet.radius+altitude,0); craft.velocity = DVec3.new(-1000,0,0)
			for i in range(4): craft.step(1.0/120,planet)
			var begin: int = Time.get_ticks_usec()
			for i in range(40): craft.step(1.0/120,planet)
			print("PROFILE full craft %d parts %s: %.3f ms/substep"%[count,"vacuum" if altitude > 60000 else "air",(Time.get_ticks_usec()-begin)/40000.0])
	call_deferred("quit",0)

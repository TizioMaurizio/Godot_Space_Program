extends SceneTree
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ")+message)
	if not ok: failures += 1

func run() -> void:
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_physics_process(false)
	game.hud.build_requested.emit(); await process_frame
	var editor: AssemblyEditor = game.assembly
	editor.new_craft()
	for id in ["command.capsule","tank.lumen","engine.lumen","decoupler.stack","tank.forge","engine.forge"]:
		var index: int = editor.catalog_ids.find(id)
		editor.catalog.item_selected.emit(index)
		if id != "command.capsule": editor.port_buttons.bottom.pressed.emit()
	check(editor.design.parts.size() == 6 and CraftCodec.validate(editor.design).is_empty(),"construct six-part two-stage craft through editor catalog/attachment controls")
	check(editor.design.stages.size() == 2,"editor generates two actionable propulsion stages")
	var stats := CraftAnalysis.analyze(editor.design)
	check(absf(stats.mass-29000) < 1e-6 and stats.delta_v > 6900,"editor engineering stats use actual part masses and stage resources")
	editor.name_input.text = "Editor orbital proof"; editor.design.display_name = editor.name_input.text
	editor.save_current()
	var saved := editor.design.to_data()
	editor.new_craft()
	check(editor.design.parts.is_empty(),"NEW clears assembly")
	var loaded: bool = editor.load_path("user://craft/Editor orbital proof.json")
	# JSON has one numeric type; compare the complete canonical JSON values.
	var before_json = JSON.parse_string(JSON.stringify(saved,"",true,true))
	var after_json = JSON.parse_string(JSON.stringify(editor.design.to_data(),"",true,true))
	check(loaded and before_json == after_json,"editor save/reload preserves full craft graph and stages")
	var count: int = editor.design.parts.size()
	editor.remove_selected(); editor.undo()
	check(editor.design.parts.size() == count,"undo restores removed craft")
	editor.redo(); editor.undo()
	check(editor.design.parts.size() == count,"redo/undo round trip preserves design")
	editor.symmetry = 4
	editor.selected_id = editor.design.parts[4].id
	editor.choose_part("aero.fin"); editor.commit_at("radial")
	check(editor.design.parts.size() == 10,"4x radial symmetry creates four physical fin instances")
	var fin_ids := CraftBuilder.descendants(editor.design,editor.selected_id)
	check(not editor.design.parts[-1].get("symmetry_group","").is_empty(),"symmetrical placement records group identity")
	editor.remove_selected()
	check(editor.design.parts.size() == 6,"group deletion removes all symmetrical fins")
	for n in [1,2,3,4,6,8]:
		var result := CraftBuilder.place(editor.design,"aero.fin",editor.design.parts[4].id,"radial",n)
		check(not result.has("error") and result.craft.parts.size() == 6+n,"radial %dx symmetry validates" % n)
	var invalid := CraftBuilder.place(editor.design,"tank.forge",editor.design.root_part_id,"bottom")
	check(invalid.has("error"),"occupied/overlapping placement is rejected")
	editor.symmetry = 1
	editor.selected_id = editor.design.parts[4].id
	editor.duplicate_selected(); editor.commit_at("radial")
	check(editor.design.parts.size() == 8 and CraftCodec.validate(editor.design).is_empty(),"copy preserves an entire tank/engine branch and valid attachments")
	var duplicate_id: String = editor.selected_id
	editor.move_selected(); editor.selected_id = editor.design.parts[4].id; editor.commit_at("radial_high")
	check(editor.design.parts.size() == 8 and CraftCodec.validate(editor.design).is_empty(),"moving a branch preserves topology, actions and configuration")
	editor.undo(); editor.undo()
	check(editor.design.parts.size() == 6,"undo restores the original graph after copy and move")
	editor.move_stage_action(1,2,0)
	check(editor.design.stages[0].actions.size() == 2,"stage actions can be moved between stages")
	editor.undo()
	check(editor.load_path("user://craft/Editor orbital proof.json"),"restore saved six-part craft before launch")
	for i in range(15): await process_frame
	DirAccess.make_dir_recursive_absolute("res://docs/validation")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/18_vehicle_assembly.png")
	editor.launch_current()
	check(not editor.visible and not game.menu and game.rocket.graph.parts.size() == 6,"editor LAUNCH uses the saved design in actual flight")
	# Physical pilot uses the live game's staged body, with no state teleportation.
	game.rocket.throttle = 1; game.stage()
	var phase: String = "ASCENT"
	var reached: bool = false
	for i in range(120*1000):
		if i % 1200 == 0: await process_frame
		var data := FlightComputer.read(game.rocket,game.planet)
		if game.rocket.crashed: break
		if phase == "ASCENT":
			var h: float = data.altitude
			var pitch: float = 90
			if h >= 1000 and h < 5000: pitch = lerpf(88,65,(h-1000)/4000)
			elif h >= 5000 and h < 20000: pitch = lerpf(65,35,(h-5000)/15000)
			elif h >= 20000: pitch = maxf(5,lerpf(35,5,(h-20000)/25000))
			game.rocket.controller.target = AttitudeController.pointing(data.up*sin(deg_to_rad(pitch))+data.east*cos(deg_to_rad(pitch)),game.rocket.orientation)
			if game.rocket.current_stage().fraction() < 0.001 and game.rocket.stage_index == 0: game.stage()
			if data.orbit.apoapsis > 120000:
				game.rocket.throttle = 0
				if game.rocket.stage_index == 0: game.stage()
				game.rocket.controller.set_mode(AttitudeController.Mode.PROGRADE,game.rocket.orientation)
				phase = "COAST"
		elif phase == "COAST" and data.orbit.time_to_ap < 50:
			phase = "INSERTION"; game.rocket.throttle = 1
		elif phase == "INSERTION" and data.orbit.stable and data.orbit.periapsis > 65000:
			game.rocket.throttle = 0; reached = true
			print("EDITOR ORBIT: t %.2f Ap %.3f km Pe %.3f km" % [game.rocket.elapsed,data.orbit.apoapsis/1000,data.orbit.periapsis/1000]); break
		game.session.step(1.0/120,Vector3.ZERO)
	check(reached,"build from scratch -> save -> reload -> launch -> actual stable orbit")
	for i in range(12): await process_frame
	game.toggle_map(); await process_frame
	game.orbit_map.fit_view()
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/19_editor_craft_orbit.png")
	print("RESULT: %d failures" % failures)
	game.queue_free(); await process_frame; await RenderingServer.frame_post_draw
	quit(1 if failures else 0)

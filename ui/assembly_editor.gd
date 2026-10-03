class_name AssemblyEditor
extends Control

signal launch_requested(design: CraftDesign)
signal exit_requested

var design := CraftDesign.new()
var selected_id: String = ""
var pending_part: String = ""
var symmetry: int = 1
var rotation_angle: float = 0
var group_edits: bool = true
var auto_stages: bool = true
var history: Array = []
var future: Array = []
var viewport: SubViewport
var workspace: TextureRect
var camera: Camera3D
var visual: RocketVisual
var preview_body: RocketState
var ghost: RocketVisual
var ghost_body: RocketState
var catalog: ItemList
var catalog_ids: Array[String] = []
var properties_label: Label
var stats_label: Label
var message: Label
var name_input: LineEdit
var part_list: ItemList
var stage_box: HBoxContainer
var fuel_slider: HSlider
var setting_label: Label
var module_toggle: CheckBox
var nodes_overlay: Control
var top_bar: HBoxContainer
var catalog_panel: VBoxContainer
var right_panel: VBoxContainer
var right_scroll: ScrollContainer
var bottom_scroll: ScrollContainer
var load_dialog: AcceptDialog
var load_list: ItemList
var saved_paths: Array[String] = []
var markers: Array[MeshInstance3D] = []
var show_markers: bool = true
var distance: float = 62
var yaw: float = 0.5
var elevation: float = 0.15
var dragging: bool = false
var hover_port: String = ""
var candidate: Dictionary = {}
var move_source: String = ""
var copy_source: String = ""
var port_buttons: Dictionary = {}
var preview_key: Array = []
var floor_mesh: MeshInstance3D
var camera_target := Vector3.ZERO
var thrust_arrow: MeshInstance3D
var auto_stage_toggle: CheckBox
var socket_choice := OptionButton.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new(); background.color = Color("08131d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	viewport = SubViewport.new(); viewport.own_world_3d = true; viewport.size = Vector2i(800,600)
	add_child(viewport)
	workspace = AssemblyDropSurface.new(); workspace.editor = self; workspace.texture = viewport.get_texture(); workspace.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(workspace)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("101e2d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c0d3de"); env.environment.ambient_light_energy = 0.8
	viewport.add_child(env)
	var light := DirectionalLight3D.new(); viewport.add_child(light); light.rotation_degrees = Vector3(-40,-30,0)
	visual = RocketVisual.new(); viewport.add_child(visual)
	ghost = RocketVisual.new(); viewport.add_child(ghost); ghost.visible = false
	camera = Camera3D.new(); camera.current = true; camera.fov = 48; camera.near = 0.1; camera.far = 10000
	viewport.add_child(camera)
	thrust_arrow = MeshInstance3D.new()
	var arrow_material := RocketVisual.material(Color("75dbcf")); arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thrust_arrow.material_override = arrow_material; viewport.add_child(thrust_arrow)
	camera.position = Vector3(20,8,55); camera.look_at(Vector3.ZERO,Vector3.UP)
	floor_mesh = MeshInstance3D.new(); var floor_plane := PlaneMesh.new(); floor_plane.size = Vector2(200,200); floor_mesh.mesh = floor_plane
	var floor_material := ShaderMaterial.new(); floor_material.shader = load("res://shaders/assembly_grid.gdshader"); floor_mesh.material_override = floor_material
	floor_mesh.position.y = -18; viewport.add_child(floor_mesh)
	for i in range(3):
		var marker := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 0.5; sphere.height = 1
		marker.mesh = sphere
		var mat := RocketVisual.material([Color("fbc66e"),Color("75dbcf"),Color("b0a0fb")][i])
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = mat; viewport.add_child(marker); markers.append(marker)
	top_bar = HBoxContainer.new(); add_child(top_bar)
	name_input = LineEdit.new(); name_input.placeholder_text = "Craft name"; name_input.custom_minimum_size = Vector2(245,38); name_input.max_length = 60
	top_bar.add_child(name_input)
	name_input.text_changed.connect(func(value): design.display_name = value)
	add_button(top_bar,"NEW",new_craft)
	add_button(top_bar,"LOAD",show_load)
	add_button(top_bar,"SAVE",save_current)
	add_button(top_bar,"UNDO",undo)
	add_button(top_bar,"REDO",redo)
	add_button(top_bar,"LAUNCH",launch_current)
	add_button(top_bar,"MENU",exit_requested.emit)
	catalog_panel = VBoxContainer.new(); add_child(catalog_panel)
	var title := Label.new(); title.text = "GODOT SPACE PROGRAM\nVEHICLE ASSEMBLY"; title.add_theme_font_size_override("font_size",20); catalog_panel.add_child(title)
	catalog = CatalogDragList.new(); catalog.custom_minimum_size = Vector2(256,350); catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_panel.add_child(catalog)
	for id in PartCatalog.all():
		var d := PartCatalog.get_part(id)
		var catalog_title: String = d.display_name if d.size_class.is_empty() or d.display_name.begins_with(d.size_class+" ") else d.size_class+" / "+d.display_name
		catalog_ids.append(id); catalog.add_item(catalog_title); catalog.set_item_metadata(catalog.item_count-1,id)
	catalog.item_selected.connect(func(index): choose_part(catalog_ids[index]))
	var symmetry_select := OptionButton.new()
	for count in [1,2,3,4,6,8]: symmetry_select.add_item("Radial symmetry: %dx" % count)
	symmetry_select.item_selected.connect(func(index): symmetry = [1,2,3,4,6,8][index])
	catalog_panel.add_child(symmetry_select)
	var group := CheckBox.new(); group.text = "Group properties / delete / rotate"; group.button_pressed = true
	group.toggled.connect(func(value): group_edits = value); catalog_panel.add_child(group)
	add_button(catalog_panel,"COM / THRUST / PRESSURE",func(): show_markers = not show_markers; update_markers())
	right_scroll = ScrollContainer.new(); add_child(right_scroll)
	right_panel = VBoxContainer.new(); right_panel.custom_minimum_size.x = 252; right_scroll.add_child(right_panel)
	properties_label = Label.new(); properties_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; properties_label.custom_minimum_size = Vector2(255,96); right_panel.add_child(properties_label)
	setting_label = Label.new(); right_panel.add_child(setting_label)
	fuel_slider = HSlider.new(); fuel_slider.min_value = 0; fuel_slider.max_value = 100; fuel_slider.step = 5; fuel_slider.value = 100
	fuel_slider.value_changed.connect(set_fill); right_panel.add_child(fuel_slider)
	module_toggle = CheckBox.new(); right_panel.add_child(module_toggle); module_toggle.toggled.connect(set_module_option)
	var buttons := HBoxContainer.new(); right_panel.add_child(buttons)
	add_button(buttons,"MOVE",move_selected); add_button(buttons,"COPY",duplicate_selected); add_button(buttons,"DELETE",remove_selected)
	var ports := HBoxContainer.new(); right_panel.add_child(ports)
	for port in ["bottom","top","radial","radial_low"]:
		port_buttons[port] = add_button(ports,port.capitalize().replace("Radial_low","Low"),func(): commit_at(port))
	right_panel.add_child(socket_choice)
	add_button(right_panel,"ATTACH AT SELECTED SOCKET",func():
		if socket_choice.selected >= 0: commit_at(socket_choice.get_item_metadata(socket_choice.selected)))
	part_list = ItemList.new(); part_list.custom_minimum_size = Vector2(255,115); right_panel.add_child(part_list)
	part_list.item_selected.connect(func(index): selected_id = design.parts[index].id; update_properties())
	stats_label = Label.new(); stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; stats_label.custom_minimum_size = Vector2(255,225); right_panel.add_child(stats_label)
	var auto := CheckBox.new(); auto.text = "Automatic stages"; auto.button_pressed = true
	auto_stage_toggle = auto
	auto.toggled.connect(func(value):
		auto_stages = value
		if value:
			CraftBuilder.auto_stage(design)
			rebuild())
	right_panel.add_child(auto)
	add_button(right_panel,"ADD EMPTY STAGE",func(): remember(); design.stages.append({"id":"stage_%d" % design.stages.size(),"actions":[]}); rebuild_stages())
	bottom_scroll = ScrollContainer.new(); add_child(bottom_scroll)
	stage_box = HBoxContainer.new(); bottom_scroll.add_child(stage_box)
	message = Label.new(); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; message.add_theme_color_override("font_color",Color("ffcb80")); add_child(message)
	nodes_overlay = Control.new(); nodes_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); nodes_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nodes_overlay); nodes_overlay.draw.connect(draw_nodes)
	load_dialog = AcceptDialog.new(); load_dialog.title = "Load spacecraft"; load_dialog.size = Vector2i(500,350); add_child(load_dialog)
	load_list = ItemList.new(); load_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); load_list.offset_bottom = -42; load_dialog.add_child(load_list)
	load_dialog.confirmed.connect(load_selected)
	new_craft()
	visible = false

func add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new(); button.text = text; button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 32; button.add_theme_font_size_override("font_size",13)
	button.pressed.connect(action); parent.add_child(button)
	return button

func open(craft: CraftDesign = null) -> void:
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if craft != null:
		design = craft.copy(); selected_id = design.root_part_id
		auto_stages = false; auto_stage_toggle.set_pressed_no_signal(false)
	rebuild()

func close() -> void:
	visible = false; dragging = false; viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(_dt: float) -> void:
	if not visible: return
	top_bar.position = Vector2(24,18); top_bar.size = Vector2(size.x-48,38)
	catalog_panel.position = Vector2(24,76); catalog_panel.size = Vector2(258,size.y-330)
	right_scroll.position = Vector2(size.x-294,76); right_scroll.size = Vector2(270,size.y-315)
	workspace.position = Vector2(296,74); workspace.size = Vector2(maxf(300,size.x-604),maxf(300,size.y-314))
	viewport.size = Vector2i(workspace.size)
	bottom_scroll.position = Vector2(24,size.y-213); bottom_scroll.size = Vector2(size.x-48,170)
	message.position = Vector2(300,size.y-236); message.size = Vector2(size.x-606,45)
	camera.position = camera_target+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*distance
	camera.look_at(camera_target,Vector3.UP)
	nodes_overlay.queue_redraw()

func remember() -> void:
	history.append(design.to_data()); future.clear()
	if history.size() > 100: history.pop_front()

func undo() -> void:
	if history.is_empty(): return
	future.append(design.to_data()); design = CraftCodec.from_data(history.pop_back()); selected_id = design.root_part_id; rebuild()

func redo() -> void:
	if future.is_empty(): return
	history.append(design.to_data()); design = CraftCodec.from_data(future.pop_back()); selected_id = design.root_part_id; rebuild()

func new_craft() -> void:
	if not design.parts.is_empty(): remember()
	design = CraftDesign.new(); selected_id = ""; pending_part = ""; move_source = ""; copy_source = ""
	auto_stages = true; auto_stage_toggle.set_pressed_no_signal(true)
	rebuild(); message.text = "Choose a command capsule or probe to begin."

func choose_part(id: String) -> void:
	preview_key.clear()
	pending_part = id; move_source = ""; copy_source = ""; rotation_angle = 0
	if design.parts.is_empty(): commit_at(""); return
	message.text = "Choose a highlighted node or an attachment button. R rotates the preview."
	var ghost_design := CraftDesign.new()
	ghost_design.parts = [{"id":"ghost","definition_id":id,"position_m":[0,0,0],"rotation_xyzw":[0,0,0,1]}]
	ghost_design.root_part_id = "ghost"
	ghost_body = RocketState.new(ghost_design,load("res://data/aster.tres"))
	ghost.rebuild(ghost_body)
	for parent in ghost.get_children():
		for mesh in parent.get_children():
			if mesh is MeshInstance3D:
				var preview_material := RocketVisual.material(Color(0.3,0.9,0.8,0.45))
				preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh.material_override = preview_material
	ghost.visible = false

func preview_at(port: String) -> Dictionary:
	if pending_part.is_empty(): return {}
	var key: Array = [design.display_name,selected_id,port,pending_part,symmetry,rotation_angle,move_source,copy_source]
	if key == preview_key: return candidate
	preview_key = key
	if not move_source.is_empty() or not copy_source.is_empty():
		candidate = CraftBuilder.attach_branch(design,design,move_source if not move_source.is_empty() else copy_source,selected_id,port,symmetry,rotation_angle,not move_source.is_empty())
		return candidate
	var source := CraftBuilder.remove(design,move_source,false) if not move_source.is_empty() else design
	candidate = CraftBuilder.place(source,pending_part,selected_id,port,symmetry,rotation_angle)
	return candidate

func commit_at(port: String) -> void:
	if pending_part.is_empty(): message.text = "Choose a part from the catalog first."; return
	var result := preview_at(port)
	if result.has("error"): message.text = result.error; return
	remember()
	design = result.craft
	selected_id = result.ids[0]
	pending_part = ""; move_source = ""; copy_source = ""; ghost.visible = false
	if auto_stages: CraftBuilder.auto_stage(design)
	else: ensure_actions()
	rebuild(); message.text = "Part attached. Select another part or configure stages below."

func remove_selected() -> void:
	if selected_id.is_empty(): return
	remember(); design = CraftBuilder.remove(design,selected_id,group_edits)
	selected_id = design.root_part_id
	if auto_stages: CraftBuilder.auto_stage(design)
	rebuild()

func duplicate_selected() -> void:
	var p := CraftBuilder.find(design,selected_id)
	if p.is_empty(): return
	choose_part(p.definition_id)
	copy_source = p.id
	message.text = "Copy selected. Choose a free attachment node."

func move_selected() -> void:
	var p := CraftBuilder.find(design,selected_id)
	if p.is_empty() or selected_id == design.root_part_id: message.text = "Select a non-root part to move."; return
	var old_id := selected_id
	choose_part(p.definition_id); move_source = old_id
	selected_id = design.root_part_id
	message.text = "Choose the new parent and attachment point."

func set_fill(value: float) -> void:
	var p := CraftBuilder.find(design,selected_id)
	if p.is_empty(): return
	var d := PartCatalog.get_part(p.definition_id)
	if not d.modules.has("tank") and not d.modules.has("engine"): return
	remember()
	for target in property_targets(p):
		if not target.has("settings"): target.settings = {}
		if d.modules.has("tank"):
			target.settings.fuel_fill = value/100; target.settings.oxidizer_fill = value/100
		else: target.settings.thrust_limit = value/100
	rebuild(false)

func set_module_option(value: bool) -> void:
	var p := CraftBuilder.find(design,selected_id)
	if p.is_empty(): return
	remember()
	var d := PartCatalog.get_part(p.definition_id)
	for target in property_targets(p):
		if not target.has("settings"): target.settings = {}
		if d.modules.has("engine"): target.settings.gimbal_enabled = value
		elif d.modules.has("decoupler"):
			target.settings.crossfeed = value
			for edge in design.connections:
				if edge.b[0] == target.id: edge.crossfeed = value
		elif d.modules.has("wheel"): target.settings.wheel_enabled = value
		elif d.modules.has("leg"): target.settings.leg_deployed = value
	rebuild()

func property_targets(entry: Dictionary) -> Array:
	if not group_edits or entry.get("symmetry_group","").is_empty(): return [entry]
	return design.parts.filter(func(p): return p.get("symmetry_group","") == entry.symmetry_group)

func ensure_actions() -> void:
	if design.stages.is_empty(): design.stages = [{"id":"launch","actions":[]}]
	for entry in design.parts:
		var d := PartCatalog.get_part(entry.definition_id)
		var action: String = "ignite" if d.modules.has("engine") else ("decouple" if d.modules.has("decoupler") else ("deploy" if d.modules.has("leg") or d.modules.has("parachute") else ""))
		if action.is_empty(): continue
		var exists: bool = false
		for stage in design.stages:
			for item in stage.actions:
				if item.part_id == entry.id and item.action == action: exists = true
		if not exists: design.stages[0 if action == "ignite" else design.stages.size()-1].actions.append({"part_id":entry.id,"action":action})

func rebuild(update_slider: bool = true) -> void:
	preview_key.clear()
	name_input.text = design.display_name
	part_list.clear()
	for p in design.parts:
		part_list.add_item(PartCatalog.get_part(p.definition_id).display_name)
		if p.id == selected_id: part_list.select(part_list.item_count-1)
	visual.visible = not design.parts.is_empty()
	if not design.parts.is_empty():
		preview_body = RocketState.new(design,load("res://data/aster.tres"))
		visual.rebuild(preview_body)
		floor_mesh.position.y = preview_body.properties.minimum.y-preview_body.properties.center.y-2
		distance = maxf(distance,preview_body.length*1.5)
	update_properties(update_slider)
	update_markers()
	rebuild_stages()

func update_properties(update_slider: bool = true) -> void:
	var entry := CraftBuilder.find(design,selected_id)
	if entry.is_empty():
		properties_label.text = "PART PROPERTIES"; fuel_slider.visible = false; module_toggle.visible = false; setting_label.text = ""; stats_label.text = "No craft yet."; return
	var d := PartCatalog.get_part(entry.definition_id)
	socket_choice.clear()
	for socket in d.nodes:
		socket_choice.add_item(str(socket)); socket_choice.set_item_metadata(socket_choice.item_count-1,socket)
	properties_label.text = "%s\n%s / %s\nDry mass %.1f kg\n%s" % [d.display_name,d.category,d.size_class if not d.size_class.is_empty() else "legacy size",d.dry_mass,d.description]
	fuel_slider.visible = d.modules.has("tank") or d.modules.has("engine")
	setting_label.text = "Propellant fill" if d.modules.has("tank") else ("Thrust limit" if d.modules.has("engine") else "")
	module_toggle.visible = d.modules.has("engine") or d.modules.has("decoupler") or d.modules.has("wheel") or d.modules.has("leg")
	var option_key: String = "gimbal_enabled" if d.modules.has("engine") else ("crossfeed" if d.modules.has("decoupler") else ("wheel_enabled" if d.modules.has("wheel") else "leg_deployed"))
	module_toggle.text = {"gimbal_enabled":"Enable manual engine gimbal","crossfeed":"Allow fuel crossfeed","wheel_enabled":"Enable reaction wheel","leg_deployed":"Deploy legs at launch"}[option_key]
	module_toggle.set_pressed_no_signal(entry.get("settings",{}).get(option_key,option_key == "wheel_enabled"))
	if update_slider:
		fuel_slider.set_value_no_signal(float(entry.get("settings",{}).get("fuel_fill" if d.modules.has("tank") else "thrust_limit",1))*100)
	var analysis := CraftAnalysis.analyze(design)
	var gravity: float = 9.81
	stats_label.text = "ENGINEERING\nMass %.2f t / Dry %.2f t\nPropellant %.2f t\nThrust %.0f kN\nTWR sea %.2f / vacuum %.2f\nIdeal vacuum Δv %.0f m/s\n%d parts\n" % [analysis.mass/1000,analysis.dry_mass/1000,analysis.propellant/1000,analysis.thrust/1000,analysis.sea_thrust/maxf(analysis.mass*gravity,1),analysis.thrust/maxf(analysis.mass*gravity,1),analysis.delta_v,design.parts.size()]
	var force := DVec3.new(); var torque := DVec3.new()
	if preview_body != null:
		for action in design.stages[0].actions if not design.stages.is_empty() else []:
			if action.action != "ignite" or not preview_body.graph.parts.has(action.part_id): continue
			var part: PartInstance = preview_body.graph.parts[action.part_id]
			var f := DVec3.new(0,part.modules.engine.engine.vacuum_thrust,0).rotated(part.orientation)
			force = force.plus(f); torque = torque.plus(part.position.minus(preview_body.properties.center).cross(f))
		if torque.length() > force.length()*0.05: stats_label.text += "WARNING: thrust line misses COM\n"
		if analysis.sea_thrust < analysis.mass*gravity: stats_label.text += "Low liftoff TWR\n"

func update_markers() -> void:
	for marker in markers: marker.visible = show_markers and not design.parts.is_empty()
	thrust_arrow.visible = show_markers and not design.parts.is_empty()
	if preview_body == null or design.parts.is_empty(): return
	markers[0].position = Vector3.ZERO
	var thrust_center := DVec3.new(); var thrust_weight: float = 0
	var pressure_center := DVec3.new(); var pressure_weight: float = 0
	var analysis := CraftAnalysis.analyze(design)
	var active_ids: Array = analysis.get("first_engine_ids",[])
	var planet: PlanetDefinition = load("res://data/aster.tres")
	var probe_velocity := PlanetPhysics.air_velocity(preview_body.position,planet).plus(DVec3.new(8.7,99.6,0))
	preview_body.part_aero.evaluate(preview_body,preview_body.position,probe_velocity,planet,true)
	for part: PartInstance in preview_body.graph.parts.values():
		var weight: float = absf(part.aero_force.x)
		var cp := part.position.plus(DVec3.new(0,part.definition.pressure_center_fraction*part.definition.length,0).rotated(part.orientation))
		pressure_center = pressure_center.plus(cp.scaled(weight)); pressure_weight += weight
		if part.has_module("engine") and part.id in active_ids:
			var thrust: float = part.modules.engine.engine.vacuum_thrust*part.modules.engine.config.get("thrust_limit",1.0)
			thrust_center = thrust_center.plus(part.position.scaled(thrust)); thrust_weight += thrust
	markers[1].position = thrust_center.scaled(1/maxf(thrust_weight,1)).minus(preview_body.properties.center).vec()
	markers[1].visible = show_markers and thrust_weight > 0
	markers[2].position = pressure_center.scaled(1/maxf(pressure_weight,1)).minus(preview_body.properties.center).vec()
	var net: DVec3 = analysis.get("thrust_vector",DVec3.new())
	var mesh := ImmediateMesh.new()
	if net.length() > 0:
		var direction: Vector3 = net.unit().vec()
		var start: Vector3 = markers[1].position
		var end: Vector3 = start+direction*5
		var side: Vector3 = direction.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.1: side = Vector3.RIGHT
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for point in [start,end,end,end-direction+side*0.5,end,end-direction-side*0.5]: mesh.surface_add_vertex(point)
		mesh.surface_end()
	thrust_arrow.mesh = mesh

func rebuild_stages() -> void:
	for child in stage_box.get_children(): stage_box.remove_child(child); child.queue_free()
	var analysis: Dictionary = CraftAnalysis.analyze(design) if not design.parts.is_empty() else {"stages":[]}
	for i in range(design.stages.size()):
		var panel := VBoxContainer.new(); panel.custom_minimum_size = Vector2(260,160); stage_box.add_child(panel)
		var header := HBoxContainer.new(); panel.add_child(header)
		var label := Label.new(); label.text = "STAGE %d" % (design.stages.size()-i); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(label)
		add_button(header,"←",func(): reorder_stage(i,-1))
		add_button(header,"→",func(): reorder_stage(i,1))
		var remove_button := add_button(header,"×",func(): remember(); design.stages.remove_at(i); rebuild_stages())
		remove_button.disabled = not design.stages[i].actions.is_empty()
		remove_button.tooltip_text = "Move actions out before removing this stage"
		var items := StageDropList.new(); items.stage_index = i; items.custom_minimum_size = Vector2(250,84); panel.add_child(items)
		items.action_moved.connect(move_stage_action)
		for action in design.stages[i].actions:
			var entry := CraftBuilder.find(design,action.part_id)
			items.add_item("%s  ·  %s" % [action.action,PartCatalog.get_part(entry.definition_id).display_name] if not entry.is_empty() else "Missing part")
		if i < analysis.stages.size():
			var stats: Dictionary = analysis.stages[i]
			var estimate := Label.new(); estimate.text = "%.1f t / %.0f kN / Δv %.0f / %.0f s" % [stats.mass/1000,stats.thrust/1000,stats.delta_v,stats.burn_time]; panel.add_child(estimate)

func reorder_stage(index: int, direction: int) -> void:
	var target: int = index+direction
	if target < 0 or target >= design.stages.size(): return
	remember(); auto_stages = false; auto_stage_toggle.set_pressed_no_signal(false)
	var stage: Dictionary = design.stages.pop_at(index)
	design.stages.insert(target,stage)
	rebuild_stages(); update_properties()

func move_stage_action(from_stage: int, index: int, to_stage: int) -> void:
	if from_stage == to_stage: return
	remember(); auto_stages = false
	auto_stage_toggle.set_pressed_no_signal(false)
	var action: Dictionary = design.stages[from_stage].actions.pop_at(index)
	design.stages[to_stage].actions.append(action)
	rebuild_stages()

func save_current() -> void:
	design.display_name = name_input.text.strip_edges()
	var name: String = design.display_name.validate_filename().left(60)
	if name.is_empty(): message.text = "Enter a craft name."; return
	var error := CraftCodec.save_craft(design,"user://craft/"+name+".json")
	message.text = "Saved " + name if error == OK else "Cannot save: " + "; ".join(CraftCodec.validate(design))

func show_load() -> void:
	load_list.clear(); saved_paths.clear()
	for path in ["res://data/craft/orbital_test_vehicle.json","res://data/craft/suborbital.json","res://data/craft/neris_explorer.json","res://data/craft/aors_complete.json","res://data/craft/docking_tug.json","res://data/craft/module_launcher.json"]:
		if FileAccess.file_exists(path): saved_paths.append(path); load_list.add_item(path.get_file().get_basename().capitalize()+" [prebuilt]")
	DirAccess.make_dir_recursive_absolute("user://craft")
	for file in DirAccess.get_files_at("user://craft"):
		if file.ends_with(".json"): saved_paths.append("user://craft/"+file); load_list.add_item(file.get_basename())
	load_dialog.popup_centered(Vector2i(500,350))

func load_selected() -> void:
	if load_list.get_selected_items().is_empty(): return
	load_path(saved_paths[load_list.get_selected_items()[0]])

func load_path(path: String) -> bool:
	var loaded := CraftCodec.load_craft(path)
	if loaded == null: message.text = "Invalid craft; current design preserved."; return false
	remember(); design = loaded; selected_id = design.root_part_id; pending_part = ""
	auto_stages = false; auto_stage_toggle.set_pressed_no_signal(false); rebuild()
	message.text = "Loaded " + design.display_name
	return true

func launch_current() -> void:
	var errors := CraftCodec.validate(design)
	if not errors.is_empty(): message.text = "; ".join(errors); return
	close(); launch_requested.emit(design.copy())

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and preview_body != null:
			distance = maxf(12,preview_body.length*1.6); camera_target = Vector3.ZERO
		if event.keycode == KEY_R:
			if pending_part.is_empty():
				var rotated := CraftBuilder.rotate_branch(design,selected_id,PI/4,group_edits)
				var errors := CraftBuilder.geometry_errors(rotated)
				if errors.is_empty(): remember(); design = rotated; rebuild()
				else: message.text = errors[0]
			else: rotation_angle += PI/4
		if event.keycode == KEY_DELETE: remove_selected()
		if event.ctrl_pressed and event.keycode == KEY_Z: undo()
		if event.ctrl_pressed and event.keycode == KEY_Y: redo()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.pressed and workspace.get_rect().has_point(event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(8,distance/1.15)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(1500,distance*1.15)
			if event.button_index == MOUSE_BUTTON_LEFT:
				if not pending_part.is_empty() and not hover_port.is_empty(): commit_at(hover_port)
				else: select_at(event.position-workspace.position)
	if event is InputEventMouseMotion:
		if dragging:
			yaw += event.relative.x*0.006; elevation = clampf(elevation+event.relative.y*0.006,-1.3,1.3)
		update_preview(event.position)

func select_at(screen: Vector2) -> void:
	if preview_body == null: return
	var o: Vector3 = camera.project_ray_origin(screen)+preview_body.properties.center.vec()
	var v: Vector3 = camera.project_ray_normal(screen)
	var best: float = INF
	for part: PartInstance in preview_body.graph.parts.values():
		var local: Vector3 = part.orientation.inverse()*(o-part.position.vec())
		var half := part.definition.half_extents()
		var hit = AABB(-half,half*2).intersects_ray(local,part.orientation.inverse()*v)
		if hit != null and local.distance_to(hit) < best: best = local.distance_to(hit); selected_id = part.id
	update_properties()

func node_screen(port: String) -> Vector2:
	if preview_body == null or not preview_body.graph.parts.has(selected_id): return Vector2(-1000,-1000)
	var point: Vector3 = preview_body.graph.parts[selected_id].node_position(port).minus(preview_body.properties.center).vec()
	if camera.is_position_behind(point) or absf(camera.to_local(point).z) < camera.near: return Vector2(-1000,-1000)
	return workspace.position+camera.unproject_position(point)

func update_preview(screen: Vector2) -> void:
	hover_port = ""; ghost.visible = false
	if pending_part.is_empty() or preview_body == null or not preview_body.graph.parts.has(selected_id): return
	var best: float = 35
	for port in preview_body.graph.parts[selected_id].definition.nodes:
		if port == "surface": continue
		var distance_to_mouse: float = screen.distance_to(node_screen(port))
		if distance_to_mouse < best: hover_port = port; best = distance_to_mouse
	if hover_port.is_empty(): return
	candidate = preview_at(hover_port)
	if candidate.has("error"): message.text = candidate.error; return
	var entry := CraftBuilder.find(candidate.craft,candidate.ids[0])
	var part := PartInstance.new(entry)
	ghost.position = part.position.minus(preview_body.properties.center).vec()
	ghost.quaternion = part.orientation
	ghost.visible = true
	message.text = "Click to attach · R rotates · symmetry %dx" % symmetry

func draw_nodes() -> void:
	if not visible or preview_body == null or not preview_body.graph.parts.has(selected_id): return
	var font: Font = ThemeDB.fallback_font
	for port in preview_body.graph.parts[selected_id].definition.nodes:
		if port == "surface": continue
		var p := node_screen(port)
		if not workspace.get_rect().has_point(p): continue
		var color := Color("79dccc") if port != hover_port else Color("ffcb80")
		nodes_overlay.draw_circle(p,6,color)
		nodes_overlay.draw_string(font,p+Vector2(10,-5),port,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	for i in range(markers.size()):
		if not markers[i].visible: continue
		if camera.is_position_behind(markers[i].position) or absf(camera.to_local(markers[i].position).z) < camera.near: continue
		var p: Vector2 = workspace.position+camera.unproject_position(markers[i].position)
		nodes_overlay.draw_string(font,p+Vector2(10,20+i*14),["COM","THRUST","PRESSURE"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("dce9ef"))

class_name StationOperations
extends Control
signal scenario_requested(path: String)
signal switch_requested(uid: String)
signal save_requested
signal load_requested
signal assembly_requested
var session: FlightSession
var camera: Camera3D
var menu: bool = true
var map_active: bool = false
var show_list: bool = false
var message: String = ""
var menu_controls := Control.new()
var flight_controls := Control.new()
var list_panel := PanelContainer.new()
var vessel_select := OptionButton.new()
var target_select := OptionButton.new()
var port_select := OptionButton.new()
var source_select := OptionButton.new()
var signature: String = ""
var font := ThemeDB.fallback_font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_controls); add_child(flight_controls); add_child(list_panel)
	menu_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE; flight_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_button(menu_controls,"AORS IN ORBIT / PREBUILT",Vector2(604,84),Vector2(330,38),func(): scenario_requested.emit("res://data/scenarios/aors_complete_orbit.json"))
	add_button(menu_controls,"AORS + DOCKING TUG / PREBUILT",Vector2(604,130),Vector2(330,38),func(): scenario_requested.emit("res://data/scenarios/aors_docking_test.json"))
	add_button(menu_controls,"LOAD FLIGHT / F9",Vector2(604,176),Vector2(330,34),load_requested.emit)
	add_button(flight_controls,"VESSELS / F7",Vector2(320,74),Vector2(135,30),func(): show_list = not show_list)
	add_button(flight_controls,"SAVE / F5",Vector2(465,74),Vector2(100,30),save_requested.emit)
	add_button(flight_controls,"LOAD / F9",Vector2(575,74),Vector2(100,30),load_requested.emit)
	add_button(flight_controls,"ADD LAUNCH",Vector2(685,74),Vector2(125,30),assembly_requested.emit)
	list_panel.position = Vector2(320,112); list_panel.custom_minimum_size = Vector2(500,295)
	var rows := VBoxContainer.new(); list_panel.add_child(rows)
	for i in range(4):
		var label := Label.new(); label.text = ["Switch active vessel (F6 / Shift+F6)","Target vessel","Target docking port","Your docking port"][i]; rows.add_child(label)
		var choice: OptionButton = [vessel_select,target_select,port_select,source_select][i]
		rows.add_child(choice)
	add_button(rows,"SWITCH TO SELECTED VESSEL",Vector2.ZERO,Vector2(480,30),func():
		if vessel_select.selected >= 0: switch_requested.emit(vessel_select.get_item_metadata(vessel_select.selected)))
	target_select.item_selected.connect(func(index):
		if session == null: return
		session.target_uid = target_select.get_item_metadata(index); session.target_port_id = ""; rebuild_ports())
	port_select.item_selected.connect(func(index): session.target_port_id = port_select.get_item_metadata(index))
	source_select.item_selected.connect(func(index): session.source_port_id = source_select.get_item_metadata(index))

func add_button(parent: Node, title: String, position_value: Vector2, size_value: Vector2, callback: Callable) -> Button:
	var button := Button.new(); button.text = title; button.position = position_value; button.custom_minimum_size = size_value; button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button); button.pressed.connect(callback); return button

func rebuild_list() -> void:
	vessel_select.clear(); target_select.clear(); target_select.add_item("No target"); target_select.set_item_metadata(0,"")
	for body: RocketState in session.registry.bodies:
		if body.lifecycle != "PERSISTENT": continue
		if body.control_available:
			vessel_select.add_item(body.vessel_name); vessel_select.set_item_metadata(vessel_select.item_count-1,body.vessel_uid)
			if body == session.active: vessel_select.select(vessel_select.item_count-1)
		if body != session.active:
			target_select.add_item(body.vessel_name); target_select.set_item_metadata(target_select.item_count-1,body.vessel_uid)
			if body.vessel_uid == session.target_uid: target_select.select(target_select.item_count-1)
	rebuild_ports()

func rebuild_ports() -> void:
	port_select.clear(); source_select.clear()
	var target := session.vessel(session.target_uid)
	if target != null:
		for port: PartInstance in DockingSystem.ports(target):
			port_select.add_item(port.id+" / "+port.modules.docking.state); port_select.set_item_metadata(port_select.item_count-1,port.id)
			if port.id == session.target_port_id: port_select.select(port_select.item_count-1)
		if session.target_port_id.is_empty() and port_select.item_count > 0: session.target_port_id = port_select.get_item_metadata(0)
	for port: PartInstance in DockingSystem.ports(session.active):
		source_select.add_item(port.id); source_select.set_item_metadata(source_select.item_count-1,port.id)
		if port.id == session.source_port_id: source_select.select(source_select.item_count-1)
	if session.source_port_id.is_empty() and source_select.item_count > 0: session.source_port_id = source_select.get_item_metadata(0)

func update_display(current: FlightSession, is_menu: bool, mapped: bool) -> void:
	session = current; menu = is_menu; map_active = mapped
	menu_controls.visible = menu; flight_controls.visible = not menu and session.campaign_mode
	list_panel.visible = not menu and show_list
	var key: String = session.active.vessel_uid+"|"+str(session.registry.bodies.map(func(b): return b.vessel_uid+str(b.graph.parts.size())))
	if key != signature: signature = key; rebuild_list()
	queue_redraw()

func _draw() -> void:
	if session == null: return
	if menu:
		draw_string(font,Vector2(607,240),"Initialized orbital scenarios / construction flights are separate",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("79dccc"))
		return
	if not session.campaign_mode: return
	var body := session.active
	var rect := Rect2(320,112,490,135)
	if not show_list:
		draw_rect(rect,Color(0.02,0.05,0.075,0.9)); draw_rect(rect,Color("385461"),false)
		var lines: Array[String] = [body.vessel_name.left(55),"RCS %s / V toggle   Dock %s / N arm, G undock"%["ON" if body.rcs_enabled else "OFF","ARMED" if body.docking_armed else "SAFE"],"Translate I/K fore/aft, J/L left/right, U/O up/down"]
		var m := session.target_metrics()
		if not m.is_empty():
			lines.append("Target %s  %.1f m  close %+.3f m/s"%[session.target_port_id,m.range,m.closing])
			lines.append("Relative %.3f  lateral %.3f m/s / offset %.3f m / angle %.2f°"%[m.relative_speed,m.lateral_speed,m.lateral,m.alignment])
		else: lines.append(session.scenario_label)
		for i in range(lines.size()): draw_string(font,Vector2(332,134+i*22),lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d0e6ed"))
	var p := body.power
	draw_rect(Rect2(320,size.y-110,490,45),Color(0.02,0.05,0.075,0.92))
	draw_string(font,Vector2(331,size.y-91),"Power %.1f / %.1f kW   Battery %.1f / %.1f MJ   %s"%[p.generation/1000,p.demand/1000,p.energy/1e6,p.capacity/1e6,"ECLIPSE" if p.eclipse else "SUNLIGHT"],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("79dccc"))
	draw_string(font,Vector2(331,size.y-72),(message if not message.is_empty() else session.docking.last_message).left(70),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffcb80"))
	if map_active or camera == null: return
	var m := session.target_metrics()
	var target := session.vessel(session.target_uid)
	if m.is_empty() or target == null: return
	var world: Vector3 = DockingSystem.frame(target,target.graph.parts[session.target_port_id]).position.minus(body.position).vec()
	if not camera.is_position_behind(world):
		var point := camera.unproject_position(world)
		draw_arc(point,12,0,TAU,24,Color("79dccc"),2,true)
		draw_string(font,point+Vector2(16,5),"TARGET / "+session.target_port_id,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("79dccc"))
	if m.range < 100:
		var center := Vector2(size.x*0.5,size.y*0.48)
		var error: DVec3 = m.lateral_vector.rotated(body.orientation.inverse())
		draw_arc(center,45,0,TAU,48,Color("79dccc"),1,true)
		draw_line(center-Vector2(50,0),center+Vector2(50,0),Color("79dccc")); draw_line(center-Vector2(0,50),center+Vector2(0,50),Color("79dccc"))
		draw_circle(center+Vector2(error.x,-error.z).limit_length(5)*9,5,Color("ffcb80"))

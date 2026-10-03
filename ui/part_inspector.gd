class_name PartInspector
extends Control

var session: FlightSession
var camera: Camera3D
var selected_id: String = ""
var show_stress: bool = false
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func pick(screen: Vector2) -> void:
	if session == null: return
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var best: float = INF
	selected_id = ""
	for body: RocketState in session.registry.bodies:
		var local_origin: Vector3 = body.orientation.inverse()*(origin-body.position.minus(session.active.position).vec())+body.properties.center.vec()
		var local_direction: Vector3 = body.orientation.inverse()*direction
		for part: PartInstance in body.graph.parts.values():
			var o: Vector3 = part.orientation.inverse()*(local_origin-part.position.vec())
			var v: Vector3 = part.orientation.inverse()*local_direction
			var half := part.definition.half_extents()
			var hit = AABB(-half,half*2).intersects_ray(o,v)
			if hit != null:
				var distance: float = o.distance_to(hit)
				if distance < best: best = distance; selected_id = part.id
	queue_redraw()

func _draw() -> void:
	if session == null: return
	var selected: PartInstance
	var owner_body: RocketState
	var load: Dictionary = {"axial":0.0,"shear":0.0,"bending":0.0,"torsion":0.0,"utilization":0.0}
	for body: RocketState in session.registry.bodies:
		if body.graph.parts.has(selected_id): selected = body.graph.parts[selected_id]; owner_body = body
		for edge in body.graph.connections:
			if selected_id in [edge.a[0],edge.b[0]] and edge.load.utilization >= load.utilization: load = edge.load
			if not show_stress: continue
			var a: Vector3 = body.part_world_position(body.graph.parts[edge.a[0]]).minus(session.active.position).vec()
			var b: Vector3 = body.part_world_position(body.graph.parts[edge.b[0]]).minus(session.active.position).vec()
			if camera.is_position_behind(a) or camera.is_position_behind(b): continue
			var color: Color = Color("6dd3ae") if edge.load.utilization < 0.5 else Color("ffcb80")
			if edge.load.utilization > 0.85: color = Color("ff7159")
			var p: Vector2 = camera.unproject_position(a)
			var q: Vector2 = camera.unproject_position(b)
			draw_line(p,q,color,3,true)
			draw_circle(p,4,color)
			if edge.load.utilization > 0.2 or selected_id in [edge.a[0],edge.b[0]]:
				draw_string(font,(p+q)*0.5+Vector2(10,0),"%.0f%%" % (edge.load.utilization*100),HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	if show_stress:
		draw_string(font,Vector2(320,86),"STRUCTURAL LOADS  /  F4    ·    Click a part to inspect",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("79dccc"))
	if selected == null: return
	var rect := Rect2(310,106,430,387)
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.02,0.05,0.08,0.96)
	style.set_border_width_all(1); style.border_color = Color("79dccc")
	draw_style_box(style,rect)
	var fuel: float = 0; var ox: float = 0
	if selected.modules.has("tank"): fuel = selected.modules.tank.resources.fuel; ox = selected.modules.tank.resources.oxidizer
	var engine_state: String = "—"
	if selected.modules.has("engine"): engine_state = "ACTIVE" if selected.modules.engine.active else "OFF"
	var lines := [selected.definition.display_name, "PART %s / BODY %d" % [selected.id,owner_body.body_id],
		"Mass %.2f kg" % selected.mass(),"Fuel %.2f kg  /  Oxidizer %.2f kg" % [fuel,ox],
		"Engine %s  /  Damage %.0f%%" % [engine_state,selected.damage*100],"Temperature: not modeled",
		"Joint utilization %.1f%%" % (load.utilization*100),"Axial %+0.1f N  /  Shear %.1f N" % [load.axial,load.shear],
		"Bending %.1f Nm  /  Torsion %.1f Nm" % [load.bending,load.torsion],
		"Frontal exposure %.0f%%" % (selected.shielding*100),"Submerged %.0f%%" % (selected.submerged*100),
		"DESTROYED / INERT WRECK" if selected.destroyed else "STRUCTURE INTACT", "I closes inspection  /  F4 toggles connections"]
	for i in range(lines.size()):
		draw_string(font,rect.position+Vector2(16,28+i*27),lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18 if i == 0 else 14,Color("dce9ef"))

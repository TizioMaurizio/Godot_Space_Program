class_name OrbitMap
extends Control
## Independent scaled 3D map and screen-space annotations; purely observational.

signal flight_requested
const INK := Color("e0ecf1")
const MUTED := Color("86a0b0")
const TEAL := Color("79dccc")
const GOLD := Color("ffcb80")
const SCALE_MIN: float = 0.2
var font: Font = ThemeDB.fallback_font
var viewport: SubViewport
var texture: TextureRect
var map_camera: Camera3D
var planet_mesh: MeshInstance3D
var path_mesh: MeshInstance3D
var atmosphere_mesh: MeshInstance3D
var rocket: RocketState
var planet: PlanetDefinition
var warp: TimeWarp
var prediction: Dictionary = {}
var view_basis := Basis.IDENTITY
var yaw: float = 0.0
var pitch: float = 0.25
var zoom: float = 3.2
var zoom_target: float = 3.2
var dragging: bool = false
var focus_craft: bool = false
var initialized_view: bool = false
var refresh_clock: float = 0.0
var paused: bool = false
var fit_button: Button
var focus_button: Button
var flight_button: Button
var label_rects: Array[Rect2] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	texture = TextureRect.new()
	texture.texture = viewport.get_texture()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture)
	# Annotations draw above the viewport texture, while the panel background is below it.
	var annotations := Control.new()
	annotations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	annotations.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	annotations.draw.connect(draw_annotations)
	annotations.name = "Annotations"
	add_child(annotations)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("050c15")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a5c5d5")
	world.environment.ambient_light_energy = 0.65
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.3
	viewport.add_child(light)
	light.look_at(Vector3(0.5, -0.7, -0.6), Vector3.UP)
	planet_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 128
	sphere.rings = 64
	planet_mesh.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/planet.gdshader")
	planet_mesh.material_override = mat
	viewport.add_child(planet_mesh)
	atmosphere_mesh = MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 1.0
	shell.height = 2.0
	shell.radial_segments = 128
	shell.rings = 64
	atmosphere_mesh.mesh = shell
	var air_mat := RocketVisual.material(Color(0.2, 0.6, 0.95, 0.07))
	air_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	air_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmosphere_mesh.material_override = air_mat
	viewport.add_child(atmosphere_mesh)
	path_mesh = MeshInstance3D.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	path_mesh.material_override = line_mat
	viewport.add_child(path_mesh)
	map_camera = Camera3D.new()
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.current = true
	viewport.add_child(map_camera)
	fit_button = button("FIT ORBIT · F", fit_view)
	focus_button = button("FOCUS CRAFT · TAB", func(): focus_craft = not focus_craft)
	flight_button = button("FLIGHT · M", flight_requested.emit)
	visible = false

func button(title: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.size = Vector2(150, 34)
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("132b38")
	style.border_color = Color("385461")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	control.add_theme_stylebox_override("normal", style)
	control.pressed.connect(callback)
	add_child(control)
	return control

func open(state: RocketState, config: PlanetDefinition, time_warp: TimeWarp) -> void:
	rocket = state
	planet = config
	warp = time_warp
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	refresh_path()
	if not initialized_view:
		fit_view()
	update_map(0.0, false)

func close() -> void:
	visible = false
	dragging = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func fit_view() -> void:
	if rocket == null:
		return
	var normal: Vector3 = rocket.position.cross(rocket.velocity).unit().vec()
	var up: Vector3 = rocket.position.unit().vec()
	if normal.length_squared() < 0.1:
		normal = up.cross(Vector3.RIGHT).normalized()
	if normal.length_squared() < 0.1:
		normal = up.cross(Vector3.BACK).normalized()
	view_basis = Basis(up.cross(normal).normalized(), up, normal)
	yaw = 0.0
	pitch = 0.25
	focus_craft = false
	zoom_target = maxf(2.8, float(prediction.get("extent", planet.radius)) / planet.radius * 2.5)
	zoom = zoom_target
	initialized_view = true

func handle(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = maxf(SCALE_MIN, zoom_target / 1.2)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = minf(maxf(200.0, prediction.get("extent", planet.radius) / planet.radius * 4.0), zoom_target * 1.2)
	if event is InputEventMouseMotion and dragging:
		yaw += event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.006, -1.45, 1.45)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			fit_view()
		if event.keycode == KEY_TAB:
			focus_craft = not focus_craft

func update_map(delta: float, is_paused: bool) -> void:
	if not visible or rocket == null:
		return
	paused = is_paused
	texture.position = Vector2(312, 82)
	texture.size = Vector2(maxf(400, size.x - 336), maxf(300, size.y - 184))
	var desired_size := Vector2i(texture.size)
	if viewport.size != desired_size:
		viewport.size = desired_size
	fit_button.position = Vector2(size.x - 520, 23)
	focus_button.position = Vector2(size.x - 360, 23)
	focus_button.size.x = 180
	flight_button.position = Vector2(size.x - 170, 23)
	flight_button.size.x = 146
	focus_button.text = "FOCUS PLANET · TAB" if focus_craft else "FOCUS CRAFT · TAB"
	refresh_clock += delta
	if refresh_clock >= 0.15:
		refresh_clock = 0
		refresh_path()
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-delta * 10.0))
	map_camera.size = zoom
	var target := rocket.position.scaled(1.0 / planet.radius).vec() if focus_craft else Vector3.ZERO
	var offset: Vector3 = view_basis * Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	map_camera.position = target + offset * maxf(10.0, zoom * 2.0)
	map_camera.near = 0.01
	map_camera.far = maxf(100.0, zoom * 10.0)
	map_camera.look_at(target, view_basis.y)
	planet_mesh.rotation.z = rocket.elapsed * planet.rotation_rate
	atmosphere_mesh.scale = Vector3.ONE * (1.0 + planet.atmosphere.height / planet.radius)
	queue_redraw()
	get_node("Annotations").queue_redraw()

func refresh_path() -> void:
	prediction = OrbitPrediction.sample(rocket.position, rocket.velocity, planet)
	var mesh := ImmediateMesh.new()
	var points: Array = prediction.points
	if points.size() >= 2:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(points.size() - 1):
			var color := path_color()
			if minf(points[i].length(), points[i + 1].length()) < planet.radius + planet.atmosphere.height:
				color = Color("f29966")
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(points[i].scaled(1.0 / planet.radius).vec())
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(points[i + 1].scaled(1.0 / planet.radius).vec())
		mesh.surface_end()
	path_mesh.mesh = mesh

func path_color() -> Color:
	if prediction.radial:
		return GOLD
	if not prediction.orbit.bound:
		return Color("baafff")
	return TEAL if prediction.orbit.stable else GOLD

func _draw() -> void:
	if rocket == null or prediction.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("050c15"))
	panel(Rect2(18, 14, size.x - 36, 52))
	label_at(Vector2(36, 47), "ASTER  /  ORBIT MAP", 21, TEAL)
	label_at(Vector2(340, 46), "PAUSED" if paused else "LIVE FLIGHT", 14, GOLD if paused else MUTED)
	panel(Rect2(24, 82, 270, size.y - 184))
	label_at(Vector2(42, 116), "ORBITAL TEST VEHICLE", 14, TEAL)
	var orbit: Dictionary = prediction.orbit
	var status: String = "STABLE ORBIT" if orbit.stable else "SUBORBITAL"
	if orbit.bound and not orbit.stable and orbit.periapsis >= 0: status = "ATMOSPHERIC ORBIT"
	if not orbit.bound: status = "ESCAPE TRAJECTORY"
	if prediction.radial: status = "RADIAL TRAJECTORY"
	if rocket.on_pad: status = "ON LAUNCHPAD"
	if rocket.crashed: status = "VEHICLE LOST"
	label_at(Vector2(42, 150), status, 18, path_color())
	metric(192, "ALTITUDE", FlightHUD.distance(rocket.position.length() - planet.radius))
	metric(257, "APOAPSIS", FlightHUD.distance(orbit.apoapsis))
	metric(322, "PERIAPSIS", FlightHUD.distance(orbit.periapsis), TEAL if orbit.stable else GOLD)
	metric(387, "TIME TO APOAPSIS", "%.0f s" % orbit.time_to_ap if is_finite(orbit.time_to_ap) else "—")
	metric(452, "ORBITAL SPEED", "%.0f m/s" % rocket.velocity.length())
	var normal := rocket.position.cross(rocket.velocity).unit()
	label_at(Vector2(42, 517), "ECC  %.4f" % orbit.eccentricity, 14, MUTED)
	label_at(Vector2(42, 545), "INCLINATION  —" if prediction.radial else "INCLINATION  %.1f°" % rad_to_deg(acos(clampf(normal.z, -1, 1))), 14, MUTED)
	label_at(Vector2(42, 573), "PERIOD  %.1f min" % (orbit.period / 60) if is_finite(orbit.period) else "PERIOD  —", 14, MUTED)
	label_at(Vector2(42, 620), "THROTTLE  %.0f%%" % (rocket.throttle * 100), 14, GOLD)
	label_at(Vector2(42, 647), "STAGE %d   ·   FUEL %.0f%%" % [rocket.stage_index + 1, rocket.current_stage().fraction() * 100], 14, MUTED)
	label_at(Vector2(42, 689), "WARP  %dx  /  %s" % [warp.rate(), "COAST" if warp.is_coasting() else "PHYSICS"], 17, TEAL)
	label_at(Vector2(42, 720), "ATTITUDE LOCKED" if warp.is_coasting() else "SAS  " + AttitudeController.NAMES[rocket.controller.mode], 13, MUTED)
	panel(Rect2(24, size.y - 84, size.x - 48, 65))
	label_at(Vector2(42, size.y - 56), "M  flight    Right drag  rotate    Wheel  zoom    F  fit orbit    TAB  focus    , / .  warp    Z / X  full / cut", 15)
	var note: String = "Coast prediction. Thrust and atmospheric drag change this path. Orange segments enter the atmosphere."
	if prediction.impact != null: note = "Surface intersection predicted. The path ends at impact; atmospheric drag can change the actual landing point."
	if prediction.clipped: note = "Open trajectory: display range is limited. This is an escape or very extended coast path."
	label_at(Vector2(42, size.y - 32), note, 13, MUTED)

func draw_annotations() -> void:
	if not visible or rocket == null or prediction.is_empty():
		return
	var painter: Control = get_node("Annotations")
	label_rects.clear()
	marker(painter, rocket.position, "YOU", Color.WHITE, Vector2(14, -16), true)
	if prediction.apoapsis_position != null:
		marker(painter, prediction.apoapsis_position, "Ap  " + FlightHUD.distance(prediction.orbit.apoapsis), TEAL, Vector2(15, -19))
	if prediction.periapsis_position != null:
		marker(painter, prediction.periapsis_position, "Pe  " + FlightHUD.distance(prediction.orbit.periapsis), GOLD, Vector2(15, 25))
	if prediction.impact != null:
		marker(painter, prediction.impact, "SURFACE INTERSECTION", Color("ff987d"), Vector2(16, 31))
	var region: Rect2 = texture.get_rect()
	painter.draw_string(font, region.position + Vector2(18, 28), "%s  ·  ATMOSPHERE %.0f km" % [planet.display_name.to_upper(), planet.atmosphere.height / 1000], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	if prediction.orbit.eccentricity < 1.0e-5:
		painter.draw_string(font, region.position + Vector2(18, 52), "CIRCULAR ORBIT  ·  NO UNIQUE APSIDES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)

func marker(painter: Control, point: DVec3, title: String, color: Color, offset: Vector2, craft: bool = false) -> void:
	var world_point := point.scaled(1.0 / planet.radius).vec()
	if map_camera.is_position_behind(world_point): return
	var p: Vector2 = texture.position + map_camera.unproject_position(world_point)
	if not texture.get_rect().grow(-10).has_point(p): return
	if craft:
		var ahead: Vector2 = texture.position + map_camera.unproject_position(world_point + rocket.velocity.unit().vec() * 0.05)
		var angle: float = (ahead - p).angle() + PI * 0.5
		painter.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8).rotated(angle), p + Vector2(7, 6).rotated(angle), p, p + Vector2(-7, 6).rotated(angle)]), color)
	else:
		painter.draw_circle(p, 4, color)
		painter.draw_arc(p, 8, 0, TAU, 24, color, 1.2, true)
	var text_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var label_pos := p + offset
	label_pos.x = clampf(label_pos.x, texture.position.x + 12, texture.position.x + texture.size.x - text_width - 12)
	label_pos.y = clampf(label_pos.y, texture.position.y + 65, texture.position.y + texture.size.y - 12)
	var label_rect := Rect2(label_pos + Vector2(-5, -17), Vector2(text_width + 10, 24))
	for attempt in range(6):
		var overlaps: bool = false
		for other in label_rects:
			if label_rect.grow(3).intersects(other): overlaps = true
		if not overlaps: break
		label_pos.y += 29 if label_pos.y < texture.position.y + texture.size.y - 45 else -58
		label_rect.position = label_pos + Vector2(-5, -17)
	label_rects.append(label_rect)
	painter.draw_line(p, label_pos + Vector2(-5, -4), Color(color, 0.6), 1, true)
	painter.draw_style_box(panel_style(), label_rect)
	painter.draw_string(font, label_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.09, 0.95)
	style.border_color = Color("294451")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func panel(rect: Rect2) -> void:
	draw_style_box(panel_style(), rect)

func label_at(pos: Vector2, value: String, font_size: int = 16, color: Color = INK) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func metric(y: float, title: String, value: String, color: Color = INK) -> void:
	label_at(Vector2(42, y), title, 12, MUTED)
	label_at(Vector2(42, y + 29), value, 25, color)

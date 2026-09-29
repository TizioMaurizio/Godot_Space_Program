class_name FlightHUD
extends Control

signal launch_requested
signal restart_requested
signal menu_requested
signal quit_requested
signal sas_requested(mode: int)
signal map_requested

const INK := Color("e0ecf1")
const MUTED := Color("86a0b0")
const ACCENT := Color("79dccc")
const GOLD := Color("ffcb80")
var font: Font = ThemeDB.fallback_font
var rocket: RocketState
var planet: PlanetDefinition
var telemetry: Dictionary = {}
var in_menu: bool = true
var debug: bool = false
var help: bool = false
var paused: bool = false
var warp: TimeWarp
var indicator := AttitudeIndicator.new()
var menu_controls := Control.new()
var flight_controls := Control.new()
var sas_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(indicator)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_controls)
	add_child(flight_controls)
	make_button(menu_controls, "SELECT VEHICLE  /  GO TO LAUNCHPAD  →", Vector2(66, 587), Vector2(452, 56), launch_requested.emit)
	make_button(menu_controls, "QUIT", Vector2(66, 660), Vector2(108, 38), quit_requested.emit)
	make_button(flight_controls, "RELAUNCH", Vector2(0, 0), Vector2(106, 32), restart_requested.emit).name = "Restart"
	make_button(flight_controls, "VEHICLES", Vector2(0, 0), Vector2(106, 32), menu_requested.emit).name = "Menu"
	make_button(flight_controls, "ORBIT MAP · M", Vector2.ZERO, Vector2(146, 34), map_requested.emit).name = "Map"
	for i in range(4):
		var button := make_button(flight_controls, ["OFF · T", "HOLD · H", "PRO · P", "RETRO · R"][i], Vector2.ZERO, Vector2(92, 32), func(): sas_requested.emit(i))
		sas_buttons.append(button)

func make_button(parent: Control, text: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("23444b") if state in ["hover", "pressed"] else Color("132b38")
		style.border_color = ACCENT if state != "normal" else Color("385461")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func update_display(state: RocketState, config: PlanetDefinition, data: Dictionary, menu: bool) -> void:
	rocket = state
	planet = config
	telemetry = data
	in_menu = menu
	menu_controls.visible = menu
	flight_controls.visible = not menu
	indicator.visible = not menu
	indicator.rocket = state
	indicator.telemetry = data
	indicator.position = Vector2(size.x * 0.5 - 110, size.y - 266)
	indicator.size = Vector2(220, 220)
	indicator.queue_redraw()
	flight_controls.get_node("Restart").position = Vector2(size.x - 250, 22)
	flight_controls.get_node("Menu").position = Vector2(size.x - 132, 22)
	flight_controls.get_node("Map").position = Vector2(size.x - 300, 607)
	for i in range(sas_buttons.size()):
		sas_buttons[i].position = Vector2(size.x * 0.5 - 192 + i * 98, size.y - 42)
		sas_buttons[i].modulate = ACCENT if state.controller.mode == i else Color.WHITE
	queue_redraw()

func panel(rect: Rect2) -> void:
	draw_style_box(panel_style(), rect)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.09, 0.91)
	style.border_color = Color(0.25, 0.4, 0.46, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func text_at(pos: Vector2, value: String, font_size: int = 16, color: Color = INK) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

static func distance(value: float) -> String:
	if not is_finite(value):
		return "ESCAPE"
	return "%.1f km" % (value / 1000.0)

func metric(x: float, y: float, label: String, value: String, color: Color = INK) -> void:
	text_at(Vector2(x, y), label, 13, MUTED)
	text_at(Vector2(x, y + 27), value, 23, color)

func _draw() -> void:
	if rocket == null:
		return
	if in_menu:
		draw_rect(Rect2(0, 0, 570, size.y), Color(0.02, 0.045, 0.065, 0.97))
		text_at(Vector2(66, 65), "A S T E R   /   F L I G H T   L A B", 18, ACCENT)
		text_at(Vector2(66, 169), "Your first orbit.", 48)
		text_at(Vector2(66, 209), "Built on physics. Flown by you.", 22, MUTED)
		text_at(Vector2(66, 284), "01    /    VEHICLE SELECTION", 14, ACCENT)
		panel(Rect2(66, 310, 452, 244))
		text_at(Vector2(88, 350), "Orbital Test Vehicle", 27)
		text_at(Vector2(88, 382), "FORGE BOOSTER  +  LUMEN ORBITAL STAGE", 12, GOLD)
		text_at(Vector2(88, 424), "Two restartable stages. Electric attitude control.", 16, MUTED)
		text_at(Vector2(88, 451), "An ample fuel margin for learning to fly.", 16, MUTED)
		metric(88, 492, "LIFTOFF MASS", "%.1f t" % (rocket.definition.wet_mass() / 1000))
		metric(294, 492, "VACUUM Δv", "%.0f m/s" % rocket.definition.vacuum_delta_v())
		text_at(Vector2(66, size.y - 96), "TARGET   /   ASTER", 13, ACCENT)
		text_at(Vector2(66, size.y - 64), "%.0f km radius  ·  %.2f m/s²  ·  atmosphere to %.0f km" % [planet.radius / 1000, planet.mu() / (planet.radius * planet.radius), planet.atmosphere.height / 1000], 15, MUTED)
		text_at(Vector2(size.x - 365, size.y - 45), "ORBITAL RESEARCH  /  FLIGHT ARTICLE 01", 13, INK)
		return
	panel(Rect2(18, 14, size.x - 36, 52))
	text_at(Vector2(36, 47), "ASTER  /  FLIGHT LAB", 19, ACCENT)
	var met: float = maxf(0.0, rocket.elapsed - rocket.launch_time) if rocket.launch_time >= 0 else 0.0
	text_at(Vector2(310, 46), "MET  %02d:%02d" % [int(met) / 60, int(met) % 60], 19)
	text_at(Vector2(485, 46), status(), 16, GOLD if not telemetry.orbit.stable else ACCENT)
	panel(Rect2(24, 88, 266, 421))
	text_at(Vector2(42, 116), "FLIGHT TELEMETRY", 13, ACCENT)
	metric(42, 148, "ALTITUDE / SEA LEVEL", distance(telemetry.altitude))
	metric(42, 214, "SURFACE SPEED", "%.1f m/s" % telemetry.surface_speed)
	metric(42, 280, "INERTIAL SPEED", "%.1f m/s" % telemetry.orbital_speed)
	metric(42, 346, "VERTICAL SPEED", "%+.1f m/s" % telemetry.vertical_speed)
	metric(42, 412, "DYNAMIC PRESSURE", "%.2f kPa" % (rocket.dynamic_pressure / 1000))
	text_at(Vector2(42, 486), "MAX Q   %.2f kPa" % (rocket.peak_q / 1000), 14, MUTED)
	var ox: float = size.x - 300
	panel(Rect2(ox, 88, 276, 324))
	text_at(Vector2(ox + 18, 116), "ORBIT / OSCULATING", 13, ACCENT)
	metric(ox + 18, 149, "APOAPSIS", distance(telemetry.orbit.apoapsis))
	metric(ox + 18, 215, "PERIAPSIS", distance(telemetry.orbit.periapsis), ACCENT if telemetry.orbit.stable else GOLD)
	var eta: float = telemetry.orbit.time_to_ap
	metric(ox + 18, 281, "TIME TO APOAPSIS", "%.0f s" % eta if is_finite(eta) else "—")
	text_at(Vector2(ox + 18, 344), "ATMOSPHERE ENDS AT %.1f km" % (planet.atmosphere.height / 1000), 13, MUTED)
	text_at(Vector2(ox + 18, 380), "ECC  %.4f" % telemetry.orbit.eccentricity, 16)
	if warp:
		panel(Rect2(ox, 426, 276, 164))
		text_at(Vector2(ox + 18, 454), "TIME WARP  /  " + ("COAST" if warp.is_coasting() else "PHYSICS"), 13, ACCENT)
		text_at(Vector2(ox + 18, 488), "%dx   [ , ] slower   [ . ] faster" % warp.rate(), 16, GOLD)
		text_at(Vector2(ox + 18, 516), "HEATING   %3.0f%%" % (rocket.heating * 100), 13, GOLD if rocket.heating > 0.1 else MUTED)
		var note: String = "Attitude locked during coast warp" if warp.is_coasting() else warp.notice
		if note.length() > 35:
			text_at(Vector2(ox + 18, 545), note.left(35), 11, MUTED)
			text_at(Vector2(ox + 18, 564), note.substr(35), 11, MUTED)
		else:
			text_at(Vector2(ox + 18, 549), note, 11, MUTED)
	panel(Rect2(24, size.y - 224, 310, 196))
	text_at(Vector2(42, size.y - 194), "PROPULSION  /  STAGE %d OF %d" % [rocket.stage_index + 1, rocket.stages.size()], 13, ACCENT)
	bar(Vector2(42, size.y - 161), "THROTTLE", rocket.throttle, GOLD)
	bar(Vector2(42, size.y - 110), "PROPELLANT", rocket.current_stage().fraction(), ACCENT)
	text_at(Vector2(42, size.y - 48), "MASS  %.2f t     THRUST  %.0f kN" % [rocket.mass / 1000, rocket.thrust / 1000], 14, MUTED)
	panel(Rect2(size.x * 0.5 - 224, size.y - 293, 448, 242))
	text_at(Vector2(size.x * 0.5 - 98, size.y - 273), "%s  /  SAS %s" % [telemetry.reference, AttitudeController.NAMES[rocket.controller.mode]], 13, ACCENT)
	text_at(Vector2(size.x * 0.5 - 200, size.y - 160), "PITCH", 12, MUTED)
	text_at(Vector2(size.x * 0.5 - 200, size.y - 133), "%.1f°" % telemetry.pitch, 22)
	text_at(Vector2(size.x * 0.5 + 125, size.y - 160), "HEADING", 12, MUTED)
	text_at(Vector2(size.x * 0.5 + 125, size.y - 133), "%03.0f°" % telemetry.heading, 22)
	panel(Rect2(size.x - 356, size.y - 224, 332, 196))
	text_at(Vector2(size.x - 338, size.y - 194), "FLIGHT DIRECTOR  /  MANUAL", 13, ACCENT)
	var lines: PackedStringArray = guidance().split("\n")
	for i in range(lines.size()):
		text_at(Vector2(size.x - 338, size.y - 163 + i * 25), lines[i], 15)
	text_at(Vector2(size.x - 338, size.y - 48), "F1  controls & ascent guide    F3  debug", 13, MUTED)
	if telemetry.orbit.stable:
		panel(Rect2(size.x * 0.5 - 210, 94, 420, 78))
		text_at(Vector2(size.x * 0.5 - 135, 126), "ORBIT ACHIEVED", 27, ACCENT)
		text_at(Vector2(size.x * 0.5 - 168, 152), "Both apsides clear the atmosphere. Cut thrust.", 14)
	if paused:
		panel(Rect2(size.x * 0.5 - 180, 260, 360, 72))
		text_at(Vector2(size.x * 0.5 - 118, 305), "PAUSED  /  ESC to resume", 19, GOLD)
	if debug:
		draw_debug()
	if help:
		draw_help()

func bar(pos: Vector2, label: String, fraction: float, color: Color) -> void:
	text_at(pos, "%s   %3.0f%%" % [label, fraction * 100], 14)
	draw_rect(Rect2(pos + Vector2(0, 9), Vector2(270, 6)), Color("263e4b"))
	draw_rect(Rect2(pos + Vector2(0, 9), Vector2(270 * fraction, 6)), color)

func status() -> String:
	if rocket.crashed: return "VEHICLE LOST  /  RELAUNCH TO TRY AGAIN"
	if rocket.on_pad: return "PAD READY  /  Z full throttle · SPACE ignite"
	if telemetry.orbit.stable: return "STABLE ORBIT"
	if telemetry.vertical_speed < -100 and rocket.heating > 0.1: return "REENTRY  /  AERODYNAMIC HEATING"
	if telemetry.altitude > planet.atmosphere.height: return "SPACEFLIGHT"
	return "ATMOSPHERIC FLIGHT"

func guidance() -> String:
	if rocket.crashed: return "Surface impact.\nUse RELAUNCH to start again.\nKeep your nose above the horizon."
	if rocket.on_pad: return "Z: full throttle. SPACE: ignite.\nClimb vertically to 1 km.\nThen hold W to pitch eastward."
	if telemetry.vertical_speed < -100 and telemetry.altitude < planet.atmosphere.height:
		return "Airflow applies force and torque.\nSAS OFF lets the craft weathercock.\nWatch heating and dynamic pressure."
	if telemetry.orbit.stable: return "X: cut the engine.\nYour orbit now sustains itself.\nWatch altitude and periapsis."
	if rocket.current_stage().fraction() < 0.01 and rocket.stage_index == 0: return "Booster depleted. Press SPACE.\nStage 2 starts at your set throttle.\nKeep watching apoapsis."
	if telemetry.altitude > 60000: return "P: prograde. Burn near apoapsis.\nRaise PERIAPSIS above 60 km.\nX: cut thrust once orbit is stable."
	if telemetry.orbit.apoapsis > 110000 and telemetry.vertical_speed > 100: return "X: cut thrust. Coast upward.\nSPACE: stage booster. P: prograde.\nBurn about 50 s before apoapsis."
	if telemetry.altitude < 1000: return "Hold vertical until 1 km.\nW pitches east; S pitches back.\nH holds your chosen attitude."
	return "Ease east with W, then press H.\nAim 65° at 5 km, 35° at 20 km.\nTarget an apoapsis of 100–150 km."

func draw_help() -> void:
	var x: float = size.x * 0.5 - 305
	panel(Rect2(x, 160, 610, 474))
	text_at(Vector2(x + 24, 220), "FLIGHT HANDBOOK", 24, ACCENT)
	var lines := ["W / S     Pitch east / west       A / D     Yaw       Q / E     Roll",
		"SHIFT / CTRL     Throttle up / down       Z / X     Full / cut",
		"SPACE     Ignite / separate booster + activate upper stage",
		"T     SAS off       H     Hold       P     Prograde       R     Retrograde",
		"1 / 2     Radial out / in       3 / 4     Normal / antinormal",
		"Right drag     Orbit camera       Wheel     Zoom       ESC     Pause",
		", / .     Slower / faster: 1–4x physics, up to 1,000x coast",
		"Coast warp: engines off; controls or atmosphere approach end warp.",
		"M     Orbit map / flight       F     Fit map       TAB     Map focus",
		"Launch vertical. Pitch gradually east starting at 1 km.",
		"Aim 65° at 5 km, 35° at 20 km, then lower toward the horizon.",
		"Cut at Ap 120 km. Separate booster, then coast in prograde.",
		"Burn prograde ~50 s before Ap. Taper throttle as Pe reaches 60 km.",
		"Green circle = prograde; crossed orange circle = retrograde.",
		"F1 closes this guide. F3 toggles the physics debug overlay."]
	for i in range(lines.size()):
		text_at(Vector2(x + 24, 253 + i * 25), lines[i], 15, INK if i < 8 else MUTED)

func draw_debug() -> void:
	var x: float = 310
	panel(Rect2(x, 160, 650, 455))
	text_at(Vector2(x + 18, 213), "PHYSICS DEBUG  /  SI UNITS  /  120 Hz integration", 16, ACCENT)
	var lines := ["POSITION     " + rocket.position.display(), "INERTIAL V   " + rocket.velocity.display(),
		"ATMOSPHERE V " + rocket.atmosphere_velocity.display(), "AIR-REL V    " + rocket.air_velocity.display(),
		"GRAVITY      " + rocket.gravity.display(), "DRAG N       " + rocket.drag_force.display(),
		"THRUST N     " + rocket.thrust_force.display(), "ACCEL m/s²   " + rocket.acceleration.display(),
		"MASS %.3f kg    DENSITY %.7f kg/m³" % [rocket.mass, rocket.density],
		"Q %.2f Pa    ECC %.7f" % [rocket.dynamic_pressure, telemetry.orbit.eccentricity],
		"AP %s    PE %s" % [distance(telemetry.orbit.apoapsis), distance(telemetry.orbit.periapsis)],
		"FUEL %.2f kg    OXIDIZER %.2f kg" % [rocket.current_stage().fuel, rocket.current_stage().oxidizer],
		"ANGULAR VELOCITY  " + str(rocket.angular_velocity),
		"AERO TORQUE Nm   " + str(rocket.aerodynamic_torque),
		"HEATING PROXY %.3f  (visual only)" % rocket.heating]
	for i in range(lines.size()):
		text_at(Vector2(x + 18, 240 + i * 24), lines[i], 14)

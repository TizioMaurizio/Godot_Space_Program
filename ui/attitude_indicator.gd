class_name AttitudeIndicator
extends Control

var rocket: RocketState
var telemetry: Dictionary = {}
var font: Font = ThemeDB.fallback_font

func _draw() -> void:
	if rocket == null or telemetry.is_empty():
		return
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.42
	var up: Vector3 = rocket.orientation.inverse() * telemetry.up
	draw_circle(center, radius + 7, Color("233c4d"))
	draw_circle(center, radius, Color("235873"))
	var circle: PackedVector2Array = []
	for i in range(97):
		circle.append(Vector2(cos(i * TAU / 96), sin(i * TAU / 96)) * radius)
	var normal := Vector2(up.z, -up.x)
	var ground: PackedVector2Array = []
	# Clip the circular instrument against the projected local horizon.
	for i in range(circle.size() - 1):
		var a: Vector2 = circle[i]
		var b: Vector2 = circle[i + 1]
		var da: float = normal.dot(a) + up.y * radius
		var db: float = normal.dot(b) + up.y * radius
		if da < 0:
			ground.append(a + center)
		if (da < 0) != (db < 0):
			ground.append(a.lerp(b, da / (da - db)) + center)
	if ground.size() > 2:
		draw_colored_polygon(ground, Color("795544"))
	if normal.length() > 0.001:
		var offset: float = -up.y * radius / normal.length()
		if absf(offset) < radius:
			var n: Vector2 = normal.normalized()
			var tangent := Vector2(-n.y, n.x) * sqrt(radius * radius - offset * offset)
			draw_line(center + n * offset - tangent, center + n * offset + tangent, Color("d4e7e8"), 2, true)
	for i in range(12):
		var axis := Vector2(sin(i * TAU / 12), -cos(i * TAU / 12))
		draw_line(center + axis * (radius - 7), center + axis * radius, Color("9ab4c2"), 1, true)
	var prograde: Vector3 = rocket.orientation.inverse() * telemetry.prograde
	marker(center, radius, prograde, false)
	marker(center, radius, -prograde, true)
	var gold := Color("ffd082")
	draw_line(center + Vector2(-27, 0), center + Vector2(-8, 0), gold, 3, true)
	draw_line(center + Vector2(8, 0), center + Vector2(27, 0), gold, 3, true)
	draw_arc(center, 8, 0, PI, 16, gold, 2, true)

func marker(center: Vector2, radius: float, direction: Vector3, retro: bool) -> void:
	var p := Vector2(direction.z, -direction.x) * radius * 0.87
	if direction.y < 0:
		p = p.normalized() * radius * 0.93
	var color := Color("f5a080") if retro else Color("a9f2b4")
	if direction.y < 0:
		color.a = 0.4
	p += center
	draw_arc(p, 6, 0, TAU, 20, color, 1.8, true)
	if retro:
		draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), color, 1.5, true)
		draw_line(p + Vector2(4, -4), p + Vector2(-4, 4), color, 1.5, true)
	else:
		for v in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
			draw_line(p + v * 7, p + v * 13, color, 1.8, true)

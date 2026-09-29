class_name OrbitCamera
extends Camera3D

var azimuth: float = 0.55
var elevation: float = 0.18
var distance: float = 62.0
var smooth_distance: float = 62.0
var dragging: bool = false
var smooth_up := Vector3.UP

func _ready() -> void:
	near = 0.1
	far = 80000.0
	fov = 52.0
	current = true

func handle(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(12.0, distance / 1.15)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(1500.0, distance * 1.15)
	if event is InputEventMouseMotion and dragging:
		azimuth += event.relative.x * 0.006
		elevation = clampf(elevation + event.relative.y * 0.005, -1.3, 1.3)

func follow(up: Vector3, delta: float, menu: bool) -> void:
	smooth_distance = lerpf(smooth_distance, distance, 1.0 - exp(-delta * 9.0))
	smooth_up = smooth_up.lerp(up, 1.0 - exp(-delta * 8.0)).normalized()
	var east: Vector3 = Vector3.BACK.cross(smooth_up).normalized()
	if east.length_squared() < 0.1:
		east = Vector3.LEFT
	var north: Vector3 = smooth_up.cross(east).normalized()
	var offset: Vector3 = (east * sin(azimuth) + north * cos(azimuth)) * cos(elevation) + smooth_up * sin(elevation)
	position = offset * smooth_distance
	look_at(Vector3.ZERO, smooth_up)
	h_offset = -smooth_distance * 0.18 if menu else 0.0

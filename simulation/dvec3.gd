class_name DVec3
extends RefCounted
## SI-coordinate vector. Never round absolute simulation positions through Vector3.

var x: float
var y: float
var z: float

func _init(px: float = 0.0, py: float = 0.0, pz: float = 0.0) -> void:
	x = px
	y = py
	z = pz

static func from_vec(v: Vector3) -> DVec3:
	return DVec3.new(v.x, v.y, v.z)

func vec() -> Vector3:
	return Vector3(x, y, z)

func plus(b: DVec3) -> DVec3:
	return DVec3.new(x + b.x, y + b.y, z + b.z)

func minus(b: DVec3) -> DVec3:
	return DVec3.new(x - b.x, y - b.y, z - b.z)

func scaled(s: float) -> DVec3:
	return DVec3.new(x * s, y * s, z * s)

func dot(b: DVec3) -> float:
	return x * b.x + y * b.y + z * b.z

func cross(b: DVec3) -> DVec3:
	return DVec3.new(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x)

func length_squared() -> float:
	return dot(self)

func length() -> float:
	return sqrt(length_squared())

func unit() -> DVec3:
	return scaled(1.0 / maxf(length(), 1.0e-30))

func display() -> String:
	return "(%+.3f, %+.3f, %+.3f)" % [x, y, z]

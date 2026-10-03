class_name DVector
extends RefCounted
## Factories live outside the value type to avoid Godot 4.6 self-factory cache cycles.
static func from_vec(v: Vector3) -> DVec3:
	return DVec3.new(v.x,v.y,v.z)

static func from_array(a: Array) -> DVec3:
	return DVec3.new(float(a[0]),float(a[1]),float(a[2]))

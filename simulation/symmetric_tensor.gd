class_name SymmetricTensor
extends RefCounted

var xx: float
var yy: float
var zz: float
var xy: float
var xz: float
var yz: float

func _init(a: float = 0, b: float = 0, c: float = 0, d: float = 0, e: float = 0, f: float = 0) -> void:
	xx = a; yy = b; zz = c; xy = d; xz = e; yz = f

func plus(b: SymmetricTensor) -> SymmetricTensor:
	return SymmetricTensor.new(xx+b.xx, yy+b.yy, zz+b.zz, xy+b.xy, xz+b.xz, yz+b.yz)

func scaled(s: float) -> SymmetricTensor:
	return SymmetricTensor.new(xx*s, yy*s, zz*s, xy*s, xz*s, yz*s)

func multiply(v: DVec3) -> DVec3:
	return DVec3.new(xx*v.x+xy*v.y+xz*v.z, xy*v.x+yy*v.y+yz*v.z, xz*v.x+yz*v.y+zz*v.z)

func solve(v: DVec3) -> DVec3:
	var det: float = xx*(yy*zz-yz*yz)-xy*(xy*zz-yz*xz)+xz*(xy*yz-yy*xz)
	if absf(det) < 1e-18: return DVec3.new()
	return DVec3.new((yy*zz-yz*yz)*v.x+(xz*yz-xy*zz)*v.y+(xy*yz-xz*yy)*v.z,
		(xz*yz-xy*zz)*v.x+(xx*zz-xz*xz)*v.y+(xy*xz-xx*yz)*v.z,
		(xy*yz-xz*yy)*v.x+(xy*xz-xx*yz)*v.y+(xx*yy-xy*xy)*v.z).scaled(1.0/det)

static func parallel_axis(m: float, r: DVec3) -> SymmetricTensor:
	return SymmetricTensor.new(m*(r.y*r.y+r.z*r.z),m*(r.x*r.x+r.z*r.z),m*(r.x*r.x+r.y*r.y),-m*r.x*r.y,-m*r.x*r.z,-m*r.y*r.z)

static func cylinder(m: float, radius: float, height: float, q: Quaternion) -> SymmetricTensor:
	var transverse: float = m*(3*radius*radius+height*height)/12.0
	var axial: float = 0.5*m*radius*radius
	var y := DVec3.new(0,1,0).rotated(q)
	var delta: float = axial-transverse
	return SymmetricTensor.new(transverse+delta*y.x*y.x,transverse+delta*y.y*y.y,transverse+delta*y.z*y.z,delta*y.x*y.y,delta*y.x*y.z,delta*y.y*y.z)

static func box(m: float, size: Vector3, q: Quaternion) -> SymmetricTensor:
	var diagonal := [m*(size.y*size.y+size.z*size.z)/12.0,m*(size.x*size.x+size.z*size.z)/12.0,m*(size.x*size.x+size.y*size.y)/12.0]
	var result := SymmetricTensor.new()
	for i in range(3):
		var axis := DVector.from_vec([Vector3.RIGHT,Vector3.UP,Vector3.BACK][i]).rotated(q)
		var value: float = diagonal[i]
		result.xx += value*axis.x*axis.x; result.yy += value*axis.y*axis.y; result.zz += value*axis.z*axis.z
		result.xy += value*axis.x*axis.y; result.xz += value*axis.x*axis.z; result.yz += value*axis.y*axis.z
	return result

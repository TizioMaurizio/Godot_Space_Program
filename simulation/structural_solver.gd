class_name StructuralSolver
extends RefCounted

var version: int = -1
var order: Array[String] = []
var parent_edges: Dictionary = {}
var parents: Dictionary = {}
var maximum_utilization: float = 0
var joint_axes: Dictionary = {}
var joint_points: Dictionary = {}
var zero_loads: bool = false

func rebuild(graph: PartGraph) -> void:
	if version == graph.version: return
	version = graph.version; order.clear(); parent_edges.clear(); parents.clear(); joint_axes.clear(); joint_points.clear()
	zero_loads = false
	var stack: Array[String] = [graph.root_id]
	parents[graph.root_id] = ""
	while not stack.is_empty():
		var id: String = stack.pop_back()
		order.append(id)
		for edge: Dictionary in graph.adjacency.get(id,[]):
			var child: String = edge.b[0] if edge.a[0] == id else edge.a[0]
			if parents.has(child): continue
			parents[child] = id; parent_edges[child] = edge; stack.append(child)
			var part: PartInstance = graph.parts[child]
			var end: Array = edge.a if edge.a[0] == child else edge.b
			joint_axes[child] = DVector.from_array(part.definition.nodes[end[1]].normal).rotated(part.orientation).scaled(-1).unit()
			joint_points[child] = part.node_position(end[1])

func evaluate(craft: RocketState, angular_acceleration: Vector3) -> Array:
	rebuild(craft.graph)
	# Exact uniform, nonrotating free fall has zero internal load. No tolerance,
	# stabilizing torque or force is suppressed by this algebraic fast path.
	if craft.angular_velocity == Vector3.ZERO and angular_acceleration == Vector3.ZERO and craft.acceleration.x == craft.gravity.x and craft.acceleration.y == craft.gravity.y and craft.acceleration.z == craft.gravity.z:
		var free_fall: bool = true
		for part: PartInstance in craft.graph.parts.values():
			if part.force.length_squared()+part.aero_force.length_squared()+part.fluid_force.length_squared()+part.moment.length_squared()+part.aero_moment.length_squared()+part.fluid_moment.length_squared() != 0: free_fall = false; break
		if free_fall:
			if not zero_loads:
				for edge in craft.graph.connections: edge.load = {"axial":0.0,"shear":0.0,"bending":0.0,"torsion":0.0,"utilization":0.0}
			zero_loads = true; maximum_utilization = 0
			return []
	zero_loads = false
	var forces: Dictionary = {}; var moments: Dictionary = {}
	var a := craft.acceleration.rotated(craft.orientation.inverse())
	var g := craft.gravity.rotated(craft.orientation.inverse())
	var omega := DVector.from_vec(craft.angular_velocity)
	var alpha := DVector.from_vec(angular_acceleration)
	var wheel_total: float = maxf(craft.control_torque_limit(),1e-12)
	var net := a.minus(g)
	for id in order:
		var part: PartInstance = craft.graph.parts[id]
		var arm := part.position.minus(craft.properties.center)
		var m: float = part.mass()
		var w_cross := omega.cross(arm)
		var residual := DVec3.new(
			(net.x+alpha.y*arm.z-alpha.z*arm.y+omega.y*w_cross.z-omega.z*w_cross.y)*m-part.force.x-part.aero_force.x-part.fluid_force.x,
			(net.y+alpha.z*arm.x-alpha.x*arm.z+omega.z*w_cross.x-omega.x*w_cross.z)*m-part.force.y-part.aero_force.y-part.fluid_force.y,
			(net.z+alpha.x*arm.y-alpha.y*arm.x+omega.x*w_cross.y-omega.y*w_cross.x)*m-part.force.z-part.aero_force.z-part.fluid_force.z)
		var inertia := part.inertia_per_kg.scaled(m)
		var couple := part.moment.plus(part.aero_moment).plus(part.fluid_moment).minus(DVector.from_vec((part.air_damping+part.fluid_damping)*craft.angular_velocity))
		if part.has_module("wheel") and part.modules.wheel.config.get("enabled",true):
			couple = couple.plus(DVector.from_vec(craft.controller.last_torque).scaled(part.modules.wheel.config.torque/wheel_total))
		forces[id] = residual
		moments[id] = arm.cross(residual).plus(inertia.multiply(alpha)).plus(omega.cross(inertia.multiply(omega))).minus(couple)
	var failures: Array = []
	maximum_utilization = 0
	for i in range(order.size()-1,0,-1):
		var id: String = order[i]
		var parent: String = parents[id]
		var edge: Dictionary = parent_edges[id]
		var endpoint: Array = edge.a if edge.a[0] == parent else edge.b
		var part: PartInstance = craft.graph.parts[parent]
		var node: Dictionary = part.definition.nodes[endpoint[1]]
		var other: PartInstance = craft.graph.parts[id]
		var child_endpoint: Array = edge.a if edge.a[0] == id else edge.b
		var axis: DVec3 = joint_axes[id]
		var joint_arm: DVec3 = joint_points[id].minus(craft.properties.center)
		var f: DVec3 = forces[id]
		var m: DVec3 = moments[id].minus(joint_arm.cross(f))
		var axial: float = f.dot(axis)
		var shear: float = f.minus(axis.scaled(axial)).length()
		var torsion: float = m.dot(axis)
		var bending: float = m.minus(axis.scaled(torsion)).length()
		var rating: float = edge.get("strength",minf(part.definition.strength,other.definition.strength))
		var bend_rating: float = edge.get("bending_strength",minf(part.definition.bending_strength,other.definition.bending_strength))
		var utilization: float = maxf(maxf(absf(axial)/maxf(rating,1.0),shear/maxf(edge.get("shear_strength",rating),1.0)),maxf(absf(torsion)/maxf(edge.get("torsion_strength",bend_rating),1.0),bending/maxf(bend_rating,1.0)))
		edge.load = {"axial":axial,"shear":shear,"bending":bending,"torsion":torsion,"utilization":utilization}
		maximum_utilization = maxf(maximum_utilization,utilization)
		if utilization > 1.0: failures.append(edge.id)
		forces[parent] = forces[parent].plus(f)
		moments[parent] = moments[parent].plus(moments[id])
	failures.sort()
	return failures

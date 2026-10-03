class_name CraftBuilder
extends RefCounted
## All editor operations produce the same versioned CraftDesign consumed by flight.

static func next_id(design: CraftDesign, prefix: String = "part") -> String:
	var used: Dictionary = {}
	for p in design.parts: used[p.id] = true
	for c in design.connections: used[c.id] = true
	var number: int = 1
	while used.has(prefix+str(number)): number += 1
	return prefix+str(number)

static func find(design: CraftDesign, id: String) -> Dictionary:
	for p in design.parts:
		if p.id == id: return p
	return {}

static func descendants(design: CraftDesign, id: String) -> Array:
	var graph := PartGraph.new(design.parts,design.connections,design.root_part_id)
	var parents: Dictionary = {design.root_part_id:""}
	var stack: Array = [design.root_part_id]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		for edge in graph.adjacency.get(current,[]):
			var other: String = edge.b[0] if edge.a[0] == current else edge.a[0]
			if parents.has(other): continue
			parents[other] = current; stack.append(other)
	var result: Array = []
	for p in design.parts:
		var cursor: String = p.id
		while cursor != "":
			if cursor == id: result.append(p.id); break
			cursor = parents.get(cursor,"")
	return result

static func remove(design: CraftDesign, id: String, group: bool = true) -> CraftDesign:
	var result := design.copy()
	var entry := find(design,id)
	if entry.is_empty(): return result
	var roots: Array = [id]
	if group and not entry.get("symmetry_group","").is_empty():
		for p in design.parts:
			if p.get("symmetry_group","") == entry.symmetry_group and not p.id in roots: roots.append(p.id)
	var removed: Array = []
	for root_id in roots: removed.append_array(descendants(design,root_id))
	result.parts = result.parts.filter(func(p): return not p.id in removed)
	result.connections = result.connections.filter(func(c): return not c.a[0] in removed and not c.b[0] in removed)
	for stage in result.stages:
		stage.actions = stage.actions.filter(func(a): return not a.part_id in removed)
	if result.parts.is_empty(): result.root_part_id = ""
	rebuild_symmetry(result)
	return result

static func place(design: CraftDesign, catalog_id: String, parent_id: String, port: String, symmetry: int = 1, angle: float = 0.0) -> Dictionary:
	var d := PartCatalog.get_part(catalog_id)
	if d == null: return {"error":"Unknown part"}
	var result := design.copy()
	if result.parts.is_empty():
		if not d.modules.has("command"): return {"error":"Begin with a capsule or probe core"}
		var id := next_id(result)
		result.parts.append({"id":id,"definition_id":catalog_id,"position_m":[0,0,0],"rotation_xyzw":[0,0,0,1],"settings":{}})
		result.root_part_id = id
		return {"craft":result,"ids":[id]}
	var parent_entry := find(design,parent_id)
	if parent_entry.is_empty(): return {"error":"Select an attachment parent"}
	var parent := PartInstance.new(parent_entry)
	if not parent.definition.nodes.has(port): return {"error":"Attachment point unavailable"}
	var radial: bool = port.begins_with("radial")
	var child_port: String = "surface" if radial else ("top" if port == "bottom" else "bottom")
	if not d.nodes.has(child_port): return {"error":"Part has no compatible attachment point"}
	var parent_node: Dictionary = parent.definition.nodes[port]
	var child_node: Dictionary = d.nodes[child_port]
	if not radial and absf(float(parent_node.size)-float(child_node.size)) > 0.15:
		return {"error":"Stack sizes differ; use a structural adapter"}
	var count: int = symmetry if radial else 1
	var used: int = 0
	for edge in design.connections:
		if edge.a == [parent_id,port] or edge.b == [parent_id,port]: used += 1
	if used+count > parent_node.get("capacity",1): return {"error":"Attachment node is occupied"}
	var ids: Array = []
	var group_id: String = "sym_"+next_id(result) if count > 1 else ""
	for index in range(count):
		var azimuth: float = index*TAU/count
		var radial_rotation := Quaternion(Vector3.UP,azimuth)
		var mount_rotation := Quaternion(DVector.from_array(child_node.normal).vec().normalized(),-DVector.from_array(parent_node.normal).vec().normalized())
		var rotation: Quaternion = parent.orientation*(radial_rotation*Quaternion(Vector3.RIGHT,angle) if radial else Quaternion(DVector.from_array(parent_node.normal).vec().normalized(),angle)*mount_rotation)
		var node_offset := DVector.from_array(parent_node.position).rotated(radial_rotation if radial else Quaternion.IDENTITY)
		var parent_point := parent.position.plus(node_offset.rotated(parent.orientation))
		var p := parent_point.minus(DVector.from_array(child_node.position).rotated(rotation))
		var entry := {"id":next_id(result),"definition_id":catalog_id,"position_m":p.array(),"rotation_xyzw":[rotation.x,rotation.y,rotation.z,rotation.w],"settings":{},"symmetry_group":group_id}
		var candidate := PartInstance.new(entry)
		for other_entry in result.parts:
			var other := PartInstance.new(other_entry)
			var a := {"position":candidate.position,"basis":Basis(candidate.orientation),"half":d.half_extents(),"box":not d.box_size.is_empty()}
			var b := {"position":other.position,"basis":Basis(other.orientation),"half":other.definition.half_extents(),"box":not other.definition.box_size.is_empty()}
			if not AssemblyCollisions.overlap(a,b).is_empty(): return {"error":"Placement overlaps " + other.definition.display_name}
		result.parts.append(entry); ids.append(entry.id)
		var crossfeed: bool = not d.modules.has("decoupler")
		result.connections.append({"id":next_id(result,"joint"),"a":[parent_id,port],"b":[entry.id,child_port],"crossfeed":crossfeed,"radial_angle":azimuth})
	if count > 1: result.symmetry_groups.append({"id":group_id,"members":ids.duplicate()})
	return {"craft":result,"ids":ids}

static func auto_stage(design: CraftDesign) -> void:
	if design.parts.is_empty(): design.stages = []; return
	var graph := PartGraph.new(design.parts,design.connections,design.root_part_id)
	var depths: Dictionary = {design.root_part_id:0}
	var stack: Array[String] = [design.root_part_id]
	var groups: Dictionary = {}
	var decouplers: Dictionary = {}
	while not stack.is_empty():
		var id: String = stack.pop_back()
		var part: PartInstance = graph.parts[id]
		var level: int = depths[id]
		if part.has_module("engine"):
			if not groups.has(level): groups[level] = []
			groups[level].append(id)
		if part.has_module("decoupler"):
			if not decouplers.has(level): decouplers[level] = []
			decouplers[level].append(id)
		for edge in graph.adjacency[id]:
			var other: String = edge.b[0] if edge.a[0] == id else edge.a[0]
			if depths.has(other): continue
			depths[other] = level+(1 if part.has_module("decoupler") and part.modules.decoupler.config.get("node","top") != "surface" else 0)
			stack.append(other)
	var levels: Array = groups.keys(); levels.sort(); levels.reverse()
	var stages: Array = []
	var previous: Array = []
	for level in levels:
		var actions: Array = []
		for id in previous: actions.append({"part_id":id,"action":"shutdown"})
		if not previous.is_empty():
			for id in decouplers.get(level,[]): actions.append({"part_id":id,"action":"decouple"})
		for id in groups[level]: actions.append({"part_id":id,"action":"ignite"})
		stages.append({"id":"stage_%d" % stages.size(),"actions":actions})
		previous = groups[level]
	# Ensure radial/passive decouplers are also actionable, even without a new engine tier.
	var unused: Array = []
	for part: PartInstance in graph.parts.values():
		if not part.has_module("decoupler"): continue
		var staged: bool = false
		for stage in stages:
			for action in stage.actions:
				if action.part_id == part.id and action.action == "decouple": staged = true
		if not staged:
			for child_id in descendants(design,part.id):
				if graph.parts[child_id].has_module("engine"): unused.append({"part_id":child_id,"action":"shutdown"})
			unused.append({"part_id":part.id,"action":"decouple"})
	if not unused.is_empty(): stages.append({"id":"separation","actions":unused})
	var utility: Array = []
	for part: PartInstance in graph.parts.values():
		if part.has_module("parachute") or part.has_module("leg"): utility.append({"part_id":part.id,"action":"deploy"})
	if not utility.is_empty(): stages.append({"id":"recovery","actions":utility})
	design.stages = stages

static func attach_branch(design: CraftDesign, source: CraftDesign, root_id: String, parent_id: String, port: String, symmetry: int, angle: float, moving: bool) -> Dictionary:
	var original := PartInstance.new(find(source,root_id))
	var branch: Array = descendants(source,root_id)
	if moving and parent_id in branch: return {"error":"Cannot attach a branch to itself"}
	var base := remove(design,root_id,false) if moving else design
	var placed := place(base,original.definition.id,parent_id,port,symmetry,angle)
	if placed.has("error"): return placed
	var result: CraftDesign = placed.craft
	var roots: Array = placed.ids.duplicate()
	for new_root in roots:
		var root_entry := find(result,new_root)
		root_entry.settings = find(source,root_id).get("settings",{}).duplicate(true)
		var destination := PartInstance.new(root_entry)
		var rotation: Quaternion = destination.orientation*original.orientation.inverse()
		var mapping: Dictionary = {root_id:new_root}
		for id in branch:
			if id == root_id: continue
			var entry := find(source,id).duplicate(true)
			var part := PartInstance.new(entry)
			entry.id = next_id(result)
			mapping[id] = entry.id
			entry.position_m = destination.position.plus(part.position.minus(original.position).rotated(rotation)).array()
			var q: Quaternion = (rotation*part.orientation).normalized()
			entry.rotation_xyzw = [q.x,q.y,q.z,q.w]
			var original_group: String = entry.get("symmetry_group","")
			entry.symmetry_group = root_entry.get("symmetry_group","")+"_"+id if roots.size() > 1 else (new_root+"_"+original_group if not original_group.is_empty() else "")
			var candidate := PartInstance.new(entry)
			for other_entry in result.parts:
				var other := PartInstance.new(other_entry)
				if not AssemblyCollisions.overlap({"position":candidate.position,"basis":Basis(candidate.orientation),"half":candidate.definition.half_extents(),"box":not candidate.definition.box_size.is_empty()}, {"position":other.position,"basis":Basis(other.orientation),"half":other.definition.half_extents(),"box":not other.definition.box_size.is_empty()}).is_empty():
					return {"error":"Branch overlaps existing geometry"}
			result.parts.append(entry)
		for edge in source.connections:
			if not edge.a[0] in branch or not edge.b[0] in branch: continue
			var copy: Dictionary = edge.duplicate(true)
			copy.id = next_id(result,"joint")
			copy.a[0] = mapping[edge.a[0]]; copy.b[0] = mapping[edge.b[0]]
			result.connections.append(copy)
		# Keep action intent for duplicated/moved branches; IDs follow the new instances.
		for i in range(source.stages.size()):
			while result.stages.size() <= i: result.stages.append({"id":"stage_%d" % result.stages.size(),"actions":[]})
			for action in source.stages[i].actions:
				if mapping.has(action.part_id):
					var copy: Dictionary = action.duplicate(true); copy.part_id = mapping[action.part_id]
					result.stages[i].actions.append(copy)
	rebuild_symmetry(result)
	return {"craft":result,"ids":roots}

static func rotate_branch(design: CraftDesign, selected: String, angle: float, group: bool) -> CraftDesign:
	var result := design.copy()
	var roots: Array = [selected]
	var entry := find(result,selected)
	if entry.is_empty(): return result
	if group and not entry.get("symmetry_group","").is_empty():
		for p in result.parts:
			if p.get("symmetry_group","") == entry.symmetry_group and not p.id in roots: roots.append(p.id)
	for root_id in roots:
		var part := PartInstance.new(find(result,root_id))
		var pivot := part.position; var axis := DVec3.new(0,1,0).rotated(part.orientation)
		for edge in result.connections:
			if edge.b[0] == root_id:
				pivot = part.node_position(edge.b[1]); axis = DVector.from_array(part.definition.nodes[edge.b[1]].normal).rotated(part.orientation)
		var rotation := Quaternion(axis.vec().normalized(),angle)
		for id in descendants(result,root_id):
			var p := find(result,id)
			var instance := PartInstance.new(p)
			p.position_m = pivot.plus(instance.position.minus(pivot).rotated(rotation)).array()
			var q: Quaternion = (rotation*instance.orientation).normalized()
			p.rotation_xyzw = [q.x,q.y,q.z,q.w]
	return result

static func geometry_errors(design: CraftDesign) -> PackedStringArray:
	var errors: PackedStringArray = []
	var docking_pairs: Dictionary = {}
	for edge in design.connections:
		if edge.get("kind","") == "docking": docking_pairs[edge.a[0]+"/"+edge.b[0]] = true; docking_pairs[edge.b[0]+"/"+edge.a[0]] = true
	var cell_size: float = 8
	for entry in design.parts:
		var d := PartCatalog.get_part(entry.definition_id)
		cell_size = maxf(cell_size,maxf(d.length,d.radius*2)*2)
	var buckets: Dictionary = {}
	for entry in design.parts:
		var part := PartInstance.new(entry)
		var cell := Vector3i(floori(part.position.x/cell_size),floori(part.position.y/cell_size),floori(part.position.z/cell_size))
		var shape := {"position":part.position,"basis":Basis(part.orientation),"half":part.definition.half_extents(),"box":not part.definition.box_size.is_empty(),"id":part.id}
		for dx in range(-1,2):
			for dy in range(-1,2):
				for dz in range(-1,2):
					for other in buckets.get(cell+Vector3i(dx,dy,dz),[]):
						var overlap := AssemblyCollisions.overlap(shape,other)
						if docking_pairs.has(part.id+"/"+other.id) and overlap.get("depth",0) <= 0.15: continue
						if not overlap.is_empty():
							errors.append("Overlapping parts: %s / %s" % [part.id,other.id])
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(shape)
	return errors

static func rebuild_symmetry(design: CraftDesign) -> void:
	var groups: Dictionary = {}
	for entry in design.parts:
		var id: String = entry.get("symmetry_group","")
		if id.is_empty(): continue
		if not groups.has(id): groups[id] = []
		groups[id].append(entry.id)
	design.symmetry_groups = []
	for id in groups: design.symmetry_groups.append({"id":id,"members":groups[id]})

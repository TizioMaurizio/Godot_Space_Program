class_name CraftCodec
extends RefCounted

static func from_data(data: Dictionary) -> CraftDesign:
	for field in ["parts","connections","stages","symmetry_groups"]:
		if not data.get(field,[]) is Array: return null
	for field in ["name","root_part_id","aero_model"]:
		if not data.get(field,"") is String: return null
	if not (data.get("schema_version",0) is float or data.get("schema_version",0) is int): return null
	var craft := CraftDesign.new()
	craft.schema_version = data.get("schema_version",0)
	craft.display_name = data.get("name","Untitled spacecraft")
	craft.root_part_id = data.get("root_part_id","")
	craft.parts = data.get("parts",[]).duplicate(true)
	craft.connections = data.get("connections",[]).duplicate(true)
	craft.stages = data.get("stages",[]).duplicate(true)
	craft.symmetry_groups = data.get("symmetry_groups",[]).duplicate(true)
	craft.aero_model = data.get("aero_model","parts")
	return craft

static func validate(craft: CraftDesign, require_command: bool = true) -> PackedStringArray:
	var errors: PackedStringArray = []
	if craft == null: return PackedStringArray(["Invalid craft schema"])
	if craft.schema_version != 1: errors.append("Unsupported craft format version")
	var ids: Dictionary = {}
	for entry in craft.parts:
		if not entry is Dictionary or not entry.has("id") or not entry.has("definition_id"):
			errors.append("Invalid part entry"); continue
		if not entry.id is String or not entry.definition_id is String or not entry.get("settings",{}) is Dictionary:
			errors.append("Invalid part identity/settings"); continue
		if ids.has(entry.id): errors.append("Duplicate part id: " + entry.id)
		ids[entry.id] = entry
		if PartCatalog.get_part(entry.definition_id) == null: errors.append("Unknown part: " + str(entry.definition_id))
		for field in ["position_m","rotation_xyzw"]:
			var values = entry.get(field,[])
			if not values is Array or values.size() != (3 if field == "position_m" else 4):
				errors.append("Invalid part transform"); continue
			for number in values:
				if not (number is float or number is int) or not is_finite(float(number)): errors.append("Non-finite transform")
		if not errors.is_empty(): continue
		var rotation: Array = entry.get("rotation_xyzw",[])
		if rotation.size() == 4 and rotation.all(func(n): return n is float or n is int):
			var norm: float = 0
			for n in rotation: norm += n*n
			if norm < 1e-12: errors.append("Zero rotation quaternion")
		var settings: Dictionary = entry.get("settings",{})
		for fill in ["fuel_fill","oxidizer_fill","thrust_limit"]:
			if settings.has(fill):
				if not (settings[fill] is float or settings[fill] is int) or not is_finite(float(settings[fill])) or float(settings[fill]) < 0 or float(settings[fill]) > 1: errors.append("Invalid fill/thrust limit (expected 0..1)")
	if not errors.is_empty(): return errors
	if not ids.has(craft.root_part_id): errors.append("Missing root part")
	var occupied: Dictionary = {}
	var edge_ids: Dictionary = {}
	for edge in craft.connections:
		if not edge is Dictionary or not edge.has("a") or not edge.has("b") or not edge.has("id"):
			errors.append("Invalid connection"); continue
		if not edge.id is String: errors.append("Invalid connection id"); continue
		for number in ["radial_angle","strength","bending_strength"]:
			if edge.has(number) and (not (edge[number] is float or edge[number] is int) or not is_finite(float(edge[number]))): errors.append("Invalid connection parameter")
		if edge_ids.has(edge.id): errors.append("Duplicate connection id")
		edge_ids[edge.id] = true
		for endpoint in [edge.a,edge.b]:
			if not endpoint is Array or endpoint.size() != 2 or not endpoint[0] is String or not endpoint[1] is String or not ids.has(endpoint[0]):
				errors.append("Dangling connection"); continue
			var def: PartDefinition = PartCatalog.get_part(ids[endpoint[0]].definition_id)
			if def == null or not def.nodes.has(endpoint[1]): errors.append("Unknown attachment node"); continue
			var key: String = endpoint[0]+":"+endpoint[1]
			occupied[key] = occupied.get(key,0)+1
			if occupied[key] > def.nodes[endpoint[1]].get("capacity",1): errors.append("Attachment node is occupied")
	if errors.is_empty():
		var graph := PartGraph.new(craft.parts,craft.connections,craft.root_part_id)
		if graph.reachable(craft.root_part_id).size() != craft.parts.size(): errors.append("Disconnected craft")
		if craft.connections.size() != maxi(0,craft.parts.size()-1): errors.append("Structural cycles are unsupported")
		if require_command and not graph.parts[craft.root_part_id].has_module("command"): errors.append("Root requires command capability")
		for edge in craft.connections:
			var parent: PartInstance = graph.parts[edge.a[0]]
			var child: PartInstance = graph.parts[edge.b[0]]
			var node: Dictionary = parent.definition.nodes[edge.a[1]]
			var radial := Quaternion(Vector3.UP,float(edge.get("radial_angle",0)))
			var point := parent.position.plus(DVector.from_array(node.position).rotated(radial).rotated(parent.orientation))
			var docking: bool = edge.get("kind","") == "docking"
			if point.minus(child.node_position(edge.b[1])).length() > (0.15 if docking else 0.005): errors.append("Attachment poses do not meet")
			var normal := DVector.from_array(node.normal).rotated(radial).rotated(parent.orientation)
			var child_normal := DVector.from_array(child.definition.nodes[edge.b[1]].normal).rotated(child.orientation)
			if normal.dot(child_normal) > (-cos(deg_to_rad(7.5)) if docking else -0.999): errors.append("Attachment normals are incompatible")
		errors.append_array(CraftBuilder.geometry_errors(craft))
	for stage in craft.stages:
		if not stage is Dictionary or not stage.get("actions",[]) is Array: errors.append("Invalid stage"); continue
		for action in stage.get("actions",[]):
			if not action is Dictionary: errors.append("Invalid action"); continue
			if not ids.has(action.get("part_id","")): errors.append("Stage references missing part"); continue
			var definition: PartDefinition = PartCatalog.get_part(ids[action.part_id].definition_id)
			var kind: String = action.get("action","")
			if not kind in ["ignite","shutdown","decouple","deploy"]: errors.append("Unknown stage action")
			if definition == null: continue
			if kind in ["ignite","shutdown"] and not definition.modules.has("engine"): errors.append("Engine action on non-engine part")
			if kind == "decouple" and not definition.modules.has("decoupler"): errors.append("Decoupler action on non-decoupler")
			if kind == "deploy" and not definition.modules.has("leg") and not definition.modules.has("parachute"): errors.append("Deploy action requires recoverable hardware")
	return errors

static func save_craft(craft: CraftDesign, path: String) -> Error:
	if not validate(craft).is_empty(): return ERR_INVALID_DATA
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(craft.to_data(),"\t",true,true))
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path)

static func load_craft(path: String) -> CraftDesign:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	var parsed = parser.data
	if not parsed is Dictionary: return null
	for field in ["parts","connections","stages"]:
		if not parsed.get(field,[]) is Array: return null
	if parsed.get("catalog_version",1) != 1: return null
	var craft := from_data(parsed)
	return craft if craft != null and validate(craft).is_empty() else null

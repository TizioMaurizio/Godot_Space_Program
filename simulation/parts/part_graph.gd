class_name PartGraph
extends RefCounted

var parts: Dictionary = {}
var connections: Array[Dictionary] = []
var adjacency: Dictionary = {}
var root_id: String
var version: int = 0

func _init(entries: Array = [], edges: Array = [], root: String = "") -> void:
	root_id = root
	for entry in entries:
		var part := PartInstance.new(entry)
		parts[part.id] = part
	for edge in edges:
		var c: Dictionary = edge.duplicate(true)
		c["load"] = {"axial":0.0,"shear":0.0,"bending":0.0,"torsion":0.0,"utilization":0.0}
		connections.append(c)
	rebuild()

func rebuild() -> void:
	adjacency.clear()
	for id in parts: adjacency[id] = []
	for c in connections:
		if parts.has(c.a[0]) and parts.has(c.b[0]):
			adjacency[c.a[0]].append(c)
			adjacency[c.b[0]].append(c)
	version += 1

func reachable(start: String, fuel_only: bool = false) -> Array[String]:
	var found: Array[String] = []
	var seen: Dictionary = {}
	var pending: Array[String] = [start]
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if seen.has(id) or not parts.has(id): continue
		seen[id] = true
		found.append(id)
		for c: Dictionary in adjacency.get(id,[]):
			if fuel_only and not c.get("crossfeed",true): continue
			pending.append(c.b[0] if c.a[0] == id else c.a[0])
	found.sort()
	return found

func components() -> Array:
	var groups: Array = []
	var visited: Dictionary = {}
	var ids: Array = parts.keys(); ids.sort()
	for id in ids:
		if visited.has(id): continue
		var group := reachable(id)
		for member in group: visited[member] = true
		groups.append(group)
	return groups

func cut(ids: Array) -> void:
	connections = connections.filter(func(c): return not c.id in ids)
	rebuild()

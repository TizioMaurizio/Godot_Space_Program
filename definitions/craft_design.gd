class_name CraftDesign
extends Resource

var schema_version: int = 1
var display_name: String = "Untitled spacecraft"
var root_part_id: String = ""
var parts: Array = []
var connections: Array = []
var stages: Array = []
var symmetry_groups: Array = []
var aero_model: String = "parts"

func to_data() -> Dictionary:
	return {"schema_version":schema_version,"catalog_version":1,"name":display_name,"root_part_id":root_part_id,
		"parts":parts.duplicate(true),"connections":connections.duplicate(true),"stages":stages.duplicate(true),
		"symmetry_groups":symmetry_groups.duplicate(true),"aero_model":aero_model}

func copy() -> CraftDesign:
	var result := CraftDesign.new()
	result.schema_version = schema_version
	result.display_name = display_name
	result.root_part_id = root_part_id
	result.parts = parts.duplicate(true)
	result.connections = connections.duplicate(true)
	result.stages = stages.duplicate(true)
	result.symmetry_groups = symmetry_groups.duplicate(true)
	result.aero_model = aero_model
	return result

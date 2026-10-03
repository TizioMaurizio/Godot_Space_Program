class_name PartCatalog
extends RefCounted

static var definitions: Dictionary = {}

static func all() -> Dictionary:
	if definitions.is_empty():
		var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/parts/catalog.json"))
		data.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/parts/standard_parts.json")))
		for entry in data:
			var definition := PartDefinition.from_data(entry)
			definitions[definition.id] = definition
	return definitions

static func get_part(id: String) -> PartDefinition:
	return all().get(id)

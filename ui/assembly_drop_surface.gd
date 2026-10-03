class_name AssemblyDropSurface
extends TextureRect

var editor

func _gui_input(event: InputEvent) -> void:
	var forwarded := event.duplicate()
	if forwarded is InputEventMouse: forwarded.position += position
	editor.handle_input(forwarded)
	accept_event()

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary or not data.has("catalog_part"): return false
	if editor.pending_part != data.catalog_part: editor.choose_part(data.catalog_part)
	editor.update_preview(position+at_position)
	return not editor.hover_port.is_empty() and editor.candidate.has("craft")

func _drop_data(at_position: Vector2, _data) -> void:
	editor.update_preview(position+at_position)
	editor.commit_at(editor.hover_port)

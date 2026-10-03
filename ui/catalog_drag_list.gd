class_name CatalogDragList
extends ItemList

func _get_drag_data(at_position: Vector2):
	var index: int = get_item_at_position(at_position,true)
	if index < 0: return null
	var preview := Label.new(); preview.text = get_item_text(index); set_drag_preview(preview)
	item_selected.emit(index)
	return {"catalog_part":get_item_metadata(index)}

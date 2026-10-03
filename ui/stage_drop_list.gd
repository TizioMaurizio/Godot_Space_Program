class_name StageDropList
extends ItemList
signal action_moved(from_stage: int, action_index: int, to_stage: int)
var stage_index: int = 0

func _get_drag_data(at_position: Vector2):
	var index: int = get_item_at_position(at_position,true)
	if index < 0: return null
	var label := Label.new(); label.text = get_item_text(index)
	set_drag_preview(label)
	return {"stage_action":true,"stage":stage_index,"index":index}

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("stage_action",false)

func _drop_data(_at_position: Vector2, data) -> void:
	action_moved.emit(data.stage,data.index,stage_index)

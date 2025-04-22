extends OptionButton
class_name GPListButton

signal gp_selected(id: int)
signal new_selected()


func set_gp_list(gp_list: Dictionary) -> void:
	for gp_id: int in gp_list.keys():
		add_item(gp_list[gp_id].grapheme as String + "-" + gp_list[gp_id].phoneme as String, gp_id)


func _on_item_selected(index: int) -> void:
	if index == 0:
		new_selected.emit()
		return
	var id: = get_item_id(index)
	gp_selected.emit(id)


func select_id(p_id: int) -> void:
	select(get_item_index(p_id))

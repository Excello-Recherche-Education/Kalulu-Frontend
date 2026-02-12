extends GutTest


func _create_binder_for_control(control: Control) -> ControlBinder:
	var binder: ControlBinder = ControlBinder.new()
	control.add_child(binder)
	binder._ready()
	return binder


func test_get_value_reads_from_range() -> void:
	var slider: HSlider = HSlider.new()
	slider.set_step(0.1)
	slider.set_value(3.5)
	var binder: ControlBinder = _create_binder_for_control(slider)
	var value: Variant = binder.get_value()
	assert_eq(typeof(value), TYPE_FLOAT)
	assert_eq(value as float, 3.5)


func test_get_value_reads_from_line_edit_and_text_edit() -> void:
	var line_edit: LineEdit = LineEdit.new()
	line_edit.set_text("hello")
	var line_binder: ControlBinder = _create_binder_for_control(line_edit)
	var value_line_edit: Variant = line_binder.get_value()
	assert_eq(typeof(value_line_edit), TYPE_STRING)
	assert_eq(value_line_edit as String, "hello")

	var text_edit: TextEdit = TextEdit.new()
	text_edit.set_text("multiline")
	var text_binder: ControlBinder = _create_binder_for_control(text_edit)
	var value_text_edit: Variant = text_binder.get_value()
	assert_eq(typeof(value_text_edit), TYPE_STRING)
	assert_eq(value_text_edit as String, "multiline")


func test_get_value_reads_item_list_selections() -> void:
	var item_list: ItemList = ItemList.new()
	item_list.add_item("alpha")
	item_list.add_item("beta")
	item_list.set_select_mode(ItemList.SELECT_SINGLE)
	item_list.select(1)
	var binder: ControlBinder = _create_binder_for_control(item_list)
	var value_single: Variant = binder.get_value()
	assert_eq(typeof(value_single), TYPE_INT)
	assert_eq(value_single as int, 1)

	var multi_list: ItemList = ItemList.new()
	multi_list.add_item("one")
	multi_list.add_item("two")
	multi_list.add_item("three")
	multi_list.set_select_mode(ItemList.SELECT_MULTI)
	multi_list.select(0, false)
	multi_list.select(2, false)
	var multi_binder: ControlBinder = _create_binder_for_control(multi_list)
	var value_multi: Variant = multi_binder.get_value()
	assert_eq(typeof(value_multi), TYPE_PACKED_INT32_ARRAY)
	assert_eq(value_multi as PackedInt32Array, PackedInt32Array([0, 2]))


func test_set_value_updates_range_and_text_controls() -> void:
	var slider: HSlider = HSlider.new()
	slider.set_step(0.1)
	var binder: ControlBinder = _create_binder_for_control(slider)
	binder.set_value(4)
	assert_eq(slider.value, 4.0)
	binder.set_value(2.5)
	assert_eq(slider.value, 2.5)

	var line_edit: LineEdit = LineEdit.new()
	var line_binder: ControlBinder = _create_binder_for_control(line_edit)
	line_binder.set_value("updated")
	assert_eq(line_edit.text, "updated")

	var text_edit: TextEdit = TextEdit.new()
	var text_binder: ControlBinder = _create_binder_for_control(text_edit)
	text_binder.set_value("longer text")
	assert_eq(text_edit.text, "longer text")


func test_set_value_selects_item_list_entries() -> void:
	var item_list: ItemList = ItemList.new()
	item_list.add_item("alpha")
	item_list.add_item("beta")
	item_list.select_mode = ItemList.SELECT_SINGLE
	var binder: ControlBinder = _create_binder_for_control(item_list)
	binder.set_value(0)
	assert_true(item_list.is_selected(0))

	var multi_list: ItemList = ItemList.new()
	multi_list.add_item("one")
	multi_list.add_item("two")
	multi_list.add_item("three")
	multi_list.add_item("four")
	multi_list.add_item("five")
	multi_list.select_mode = ItemList.SELECT_MULTI
	var multi_binder: ControlBinder = _create_binder_for_control(multi_list)
	multi_binder.set_value(PackedInt32Array([1, 2]))
	assert_true(multi_list.is_selected(1))
	assert_true(multi_list.is_selected(2))
	multi_binder.set_value(PackedInt32Array([3, 4]))
	assert_false(multi_list.is_selected(1))
	assert_false(multi_list.is_selected(2))
	assert_true(multi_list.is_selected(3))
	assert_true(multi_list.is_selected(4))

extends "res://sources/gardens/gardens.gd"

const garden_textures_nb: = 20
const flower_types_nb: = 5
const gardens_layout_resource_path: = "user://gardens_layout.tres"


var dragging_element
var drag_data: = {}


func _init_gardens_layout() -> void:
	gardens_layout.gardens.clear()
	for i in lessons.size():
		if i % 4 == 0:
			gardens_layout.gardens.append(GardenLayout.new())
			var garden_layout: = gardens_layout.gardens[-1]
			garden_layout.color = (i / 4) % garden_textures_nb
			for flower_i in 5:
				var flower: = GardenLayout.Flower.new(0, flower_i, Vector2i(0, 0))
				garden_layout.flowers.append(flower)
			garden_layout.flowers = garden_layout.flowers
		var garden_layout: = gardens_layout.gardens[-1]
		garden_layout.lesson_buttons.append(GardenLayout.LessonButton.new(Vector2i(0, 0), Vector2i(0, 0)))
		garden_layout.lesson_buttons = garden_layout.lesson_buttons
	gardens_layout = gardens_layout
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func _ready() -> void:
	if not ResourceLoader.exists(gardens_layout_resource_path):
		gardens_layout = GardensLayout.new()
		gardens_layout.resource_path = gardens_layout_resource_path
		_init_gardens_layout()
	gardens_layout = load(gardens_layout_resource_path)
	super()
	set_up_click_detection()


func set_up_click_detection() -> void:
	for garden_control_ind in garden_parent.get_child_count():
		var garden_control: Control = garden_parent.get_child(garden_control_ind)
		for flower_ind in garden_control.flower_controls.size():
			var flower_control: Control = garden_control.flower_controls[flower_ind]
			flower_control.gui_input.connect(_on_flower_gui_input.bind(garden_control_ind, flower_ind, flower_control))
		for lesson_button_ind in garden_control.lesson_button_controls.size():
			var lesson_button_control: Control = garden_control.lesson_button_controls[lesson_button_ind]
			lesson_button_control.gui_input.connect(_on_lesson_button_gui_input.bind(garden_control_ind, lesson_button_ind, lesson_button_control))
	

func _on_flower_gui_input(event: InputEvent, garden_control_ind: int, flower_ind: int, flower_control: Control) -> void:
	if event.is_action_pressed("left_click"):
		dragging_element = flower_control
		dragging_element.z_index = 10
		drag_data = {
			type = "flower",
			garden_ind = garden_control_ind,
			flower_ind = flower_ind
		}
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("right_click"):
		var flower: = gardens_layout.gardens[garden_control_ind].flowers[flower_ind]
		flower.type += 1
		if flower.type >= flower_types_nb:
			flower.type = 0
		gardens_layout.gardens[garden_control_ind].flowers = gardens_layout.gardens[garden_control_ind].flowers
		garden_parent.get_child(garden_control_ind).set_flowers(gardens_layout.gardens[garden_control_ind].flowers)
		ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func _on_lesson_button_gui_input(event: InputEvent, garden_control_ind: int, lesson_button_ind: int, lesson_button_control: Control) -> void:
	if event.is_action_pressed("left_click"):
		dragging_element = lesson_button_control
		dragging_element.z_index = 10
		drag_data = {
			type = "lesson_button",
			garden_ind = garden_control_ind,
			lesson_button_ind = lesson_button_ind
		}
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	super(delta)
	if dragging_element != null:
		if dragging_element is Control:
			dragging_element.position = dragging_element.get_parent().get_local_mouse_position()
			if drag_data.type == "lesson_button":
				gardens_layout.gardens[drag_data.garden_ind].lesson_buttons[drag_data.lesson_button_ind].position = dragging_element.position
				gardens_layout.gardens[drag_data.garden_ind].lesson_buttons = gardens_layout.gardens[drag_data.garden_ind].lesson_buttons
				garden_parent.get_child(drag_data.garden_ind).set_lesson_buttons(gardens_layout.gardens[drag_data.garden_ind].lesson_buttons)
				set_up_path()
		elif drag_data.type == "path_middle":
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons[drag_data.sub_ind].path_out_position = garden_parent.get_child(drag_data.garden_ind).get_local_mouse_position() - Vector2(gardens_layout.gardens[drag_data.garden_ind].lesson_buttons[drag_data.sub_ind].position)
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons = gardens_layout.gardens[drag_data.garden_ind].lesson_buttons
			garden_parent.get_child(drag_data.garden_ind).set_lesson_buttons(gardens_layout.gardens[drag_data.garden_ind].lesson_buttons)
			set_up_path()


func _input(event: InputEvent) -> void:
	if dragging_element == null:
		return
	if event.is_action_released("left_click"):
		if drag_data.type == "flower":
			dragging_element.z_index = 2
			gardens_layout.gardens[drag_data.garden_ind].flowers[drag_data.flower_ind].position = dragging_element.position
			gardens_layout.gardens[drag_data.garden_ind].flowers = gardens_layout.gardens[drag_data.garden_ind].flowers
			ResourceSaver.save(gardens_layout, gardens_layout.resource_path)
		elif drag_data.type == "lesson_button":
			dragging_element.z_index = 1
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons[drag_data.lesson_button_ind].position = dragging_element.position
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons = gardens_layout.gardens[drag_data.garden_ind].lesson_buttons
			ResourceSaver.save(gardens_layout, gardens_layout.resource_path)
		elif drag_data.type == "path_middle":
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons = gardens_layout.gardens[drag_data.garden_ind].lesson_buttons
			ResourceSaver.save(gardens_layout, gardens_layout.resource_path)
		dragging_element = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		if curve.get_closest_point(line.get_local_mouse_position()).distance_to(line.get_local_mouse_position()) < line.width:
			dragging_element = get_previous_point_on_curve()
			var a: = get_garden_and_sub_ind_from_ind(dragging_element)
			drag_data = {
				type = "path_middle",
				garden_ind = a[0],
				sub_ind = a[1],
			}


func get_previous_point_on_curve() -> int:
	var offset: = curve.get_closest_offset(line.get_local_mouse_position())
	for i in curve.point_count:
		var point_offset = curve.get_closest_offset(curve.get_point_position(i))
		if point_offset > offset:
			return i - 1
	return curve.point_count


func get_garden_and_sub_ind_from_ind(ind: int) -> Array[int]:
	var count: = 0
	for garden_control_ind in garden_parent.get_child_count():
		var garden_control: Control = garden_parent.get_child(garden_control_ind)
		for lesson_button_ind in garden_control.lesson_button_controls.size():
			if count == ind:
				return [garden_control_ind, lesson_button_ind]
			count += 1
	return [-1, -1]


func get_best_showing_garden() -> int:
	for garden_ind in garden_parent.get_child_count():
		var garden_control: Control = garden_parent.get_child(garden_ind)
		if abs(garden_control.global_position.x) < garden_control.size.x / 2:
			return garden_ind
	return -1


func _on_change_flower_color_button_pressed() -> void:
	var garden_ind: = get_best_showing_garden()
	var flowers: = gardens_layout.gardens[garden_ind].flowers
	for flower in flowers:
		flower.color += 1
		if flower.color >= garden_textures_nb:
			flower.color = 0
	gardens_layout.gardens[garden_ind].flowers = flowers
	garden_parent.get_child(garden_ind).set_flowers(flowers)
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func _on_change_flower_color_button_2_pressed() -> void:
	var garden_ind: = get_best_showing_garden()
	var flowers: = gardens_layout.gardens[garden_ind].flowers
	for flower in flowers:
		flower.color -= 1
		if flower.color < 0:
			flower.color = garden_textures_nb - 1
	gardens_layout.gardens[garden_ind].flowers = flowers
	garden_parent.get_child(garden_ind).set_flowers(flowers)
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func _on_reset_garden_button_pressed() -> void:
	var garden_ind: = get_best_showing_garden()
	var flowers: = gardens_layout.gardens[garden_ind].flowers
	for i in flowers.size():
		flowers[i] = GardenLayout.Flower.new()
	gardens_layout.gardens[garden_ind].flowers = flowers
	garden_parent.get_child(garden_ind).set_flowers(flowers)
	var lesson_buttons: = gardens_layout.gardens[garden_ind].lesson_buttons
	for i in lesson_buttons.size():
		lesson_buttons[i] = GardenLayout.LessonButton.new()
	gardens_layout.gardens[garden_ind].lesson_buttons = lesson_buttons
	garden_parent.get_child(garden_ind).set_lesson_buttons(lesson_buttons)
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)

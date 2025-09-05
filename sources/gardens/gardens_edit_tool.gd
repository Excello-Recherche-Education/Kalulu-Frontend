extends Gardens

const MAX_LESSON_NUMBER: int = 80
const GARDEN_TEXTURES_NB: int = 20
const FLOWER_TYPES_NB: int = 5
const GARDENS_LAYOUT_RESOURCE_PATH: String = "res://resources/gardens/gardens_layout.tres"

var dragging_element: Variant
var drag_data: Dictionary = {}


func _ready() -> void:
	MusicManager.stop()
	line_particles.hide()
	back_button.hide()
	
	for index: int in range(MAX_LESSON_NUMBER):
		lessons[index] = index
	
	# Checks if a configuration exists
	if not ResourceLoader.exists(GARDENS_LAYOUT_RESOURCE_PATH):
		gardens_layout = GardensLayout.new()
		gardens_layout.resource_path = GARDENS_LAYOUT_RESOURCE_PATH
		_init_gardens_layout()
	
	gardens_layout = load(GARDENS_LAYOUT_RESOURCE_PATH)
	set_up_click_detection()


func _init_gardens_layout() -> void:
	# Empty the gardens configuration
	gardens_layout.gardens.clear()
	
	for index: int in range(MAX_LESSON_NUMBER):
		
		var garden_layout: GardenLayout
		
		# Create a new garden
		if index % 4 == 0:
			garden_layout = GardenLayout.new()
			gardens_layout.gardens.append(garden_layout)
			
			garden_layout.color = int(index / 4.0) % GARDEN_TEXTURES_NB
			
			# Add the flowers to the garden
			for flower_i: int in range(5):
				var flower: GardenLayout.Flower = GardenLayout.Flower.new(garden_layout.color, flower_i, Vector2i(980 + flower_i * 100, 900))
				garden_layout.flowers.append(flower)
			garden_layout.flowers = garden_layout.flowers
		else:
			garden_layout = gardens_layout.gardens[-1]
		
		# Add a new lesson button to the garden
		garden_layout.lesson_buttons.append(GardenLayout.GardenLayoutLessonButton.new(Vector2i(0, 0), Vector2i(0, 0)))
		garden_layout.lesson_buttons = garden_layout.lesson_buttons
	
	# Save the configuration
	gardens_layout = gardens_layout
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func set_up_click_detection() -> void:
	for garden_control_ind: int in range(garden_parent.get_child_count()):
		var garden_control: Garden = garden_parent.get_child(garden_control_ind)
		
		for flower_ind: int in range(garden_control.flower_controls.size()):
			var flower_control: Control = garden_control.flower_controls[flower_ind]
			flower_control.gui_input.connect(_on_flower_gui_input.bind(garden_control_ind, flower_ind, flower_control))
			
			garden_control.flowers_sizes[flower_ind] = Garden.FlowerSizes.LARGE
			garden_control.update_flowers()
			
		for lesson_button_ind: int in range(garden_control.lesson_button_controls.size()):
			var lesson_button_control: Control = garden_control.lesson_button_controls[lesson_button_ind]
			lesson_button_control.gui_input.connect(_on_lesson_button_gui_input.bind(garden_control_ind, lesson_button_ind, lesson_button_control))


func _process(delta: float) -> void:
	super(delta)
	if dragging_element != null:
		if dragging_element is Control:
			var dragging_control: Control = dragging_element as Control
			dragging_control.position = _correct_position(dragging_control, dragging_control.get_parent_control().get_local_mouse_position() as Vector2)
			if drag_data.type == "lesson_button":
				var garden: Garden = garden_parent.get_child(drag_data.garden_ind as int)
				gardens_layout.gardens[drag_data.garden_ind].lesson_buttons[drag_data.lesson_button_ind].position = dragging_element.position
				garden.set_lesson_buttons(gardens_layout.gardens[drag_data.garden_ind].lesson_buttons)
				set_up_path()
		elif drag_data.type == "path_middle":
			var garden_layout: GardenLayout = gardens_layout.gardens[drag_data.garden_ind]
			var garden: Garden = garden_parent.get_child(drag_data.garden_ind as int)
			
			garden_layout.lesson_buttons[drag_data.sub_ind].path_out_position = garden.get_local_mouse_position() - Vector2(garden_layout.lesson_buttons[drag_data.sub_ind].position)
			garden.set_lesson_buttons(garden_layout.lesson_buttons)
			set_up_path()


func _input(event: InputEvent) -> void:
	if dragging_element == null:
		return
	if event.is_action_released("left_click"):
		if drag_data.type == "flower":
			var dragging_control: Control = dragging_element as Control
			dragging_element.z_index = 2
			gardens_layout.gardens[drag_data.garden_ind].flowers[drag_data.flower_ind].position = dragging_control.get_parent_control().get_local_mouse_position()
			gardens_layout.gardens[drag_data.garden_ind].flowers = gardens_layout.gardens[drag_data.garden_ind].flowers
			ResourceSaver.save(gardens_layout, gardens_layout.resource_path)
		elif drag_data.type == "lesson_button":
			var dragging_control: Control = dragging_element as Control
			dragging_element.z_index = 1
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons[drag_data.lesson_button_ind].position = _correct_position(dragging_control, dragging_control.get_parent_control().get_local_mouse_position())
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons = gardens_layout.gardens[drag_data.garden_ind].lesson_buttons
			ResourceSaver.save(gardens_layout, gardens_layout.resource_path)
		elif drag_data.type == "path_middle":
			gardens_layout.gardens[drag_data.garden_ind].lesson_buttons = gardens_layout.gardens[drag_data.garden_ind].lesson_buttons
			ResourceSaver.save(gardens_layout, gardens_layout.resource_path)
		dragging_element = null


func get_garden_and_sub_ind_from_ind(ind: int) -> Array[int]:
	var count: int = 0
	for garden_control_ind: int in range(garden_parent.get_child_count()):
		var garden_control: Garden = garden_parent.get_child(garden_control_ind)
		for lesson_button_ind: int in range(garden_control.lesson_button_controls.size()):
			if count == ind:
				return [garden_control_ind, lesson_button_ind]
			count += 1
	return [-1, -1]


func get_best_showing_garden() -> int:
	for garden_ind: int in range(garden_parent.get_child_count()):
		var garden_control: Control = garden_parent.get_child(garden_ind)
		if abs(garden_control.global_position.x) < garden_control.size.x / 2:
			return garden_ind
	return -1


func _correct_position(element: Control, pos: Vector2) -> Vector2:
	return Vector2(pos.x - element.size.x/2, pos.y - element.size.y)


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
		var garden: Garden = garden_parent.get_child(garden_control_ind)
		var flower: GardenLayout.Flower = gardens_layout.gardens[garden_control_ind].flowers[flower_ind]
		flower.type += 1
		if flower.type >= FLOWER_TYPES_NB:
			flower.type = 0
		garden.set_flowers(gardens_layout.gardens[garden_control_ind].flowers, Garden.FlowerSizes.LARGE)
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


func _on_change_flower_color_button_pressed() -> void:
	var garden_ind: int = get_best_showing_garden()
	var garden: Garden = garden_parent.get_child(garden_ind)
	var flowers: Array[GardenLayout.Flower] = gardens_layout.gardens[garden_ind].flowers
	for flower: GardenLayout.Flower in flowers:
		flower.color += 1
		if flower.color >= GARDEN_TEXTURES_NB:
			flower.color = 0
	gardens_layout.gardens[garden_ind].flowers = flowers
	
	garden.set_flowers(flowers, Garden.FlowerSizes.LARGE)
	
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func _on_change_flower_color_button_2_pressed() -> void:
	var garden_ind: int = get_best_showing_garden()
	var garden: Garden = garden_parent.get_child(garden_ind)
	
	var flowers: Array[GardenLayout.Flower] = gardens_layout.gardens[garden_ind].flowers
	for flower: GardenLayout.Flower in flowers:
		flower.color -= 1
		if flower.color < 0:
			flower.color = GARDEN_TEXTURES_NB - 1
	gardens_layout.gardens[garden_ind].flowers = flowers
	
	garden.set_flowers(flowers, Garden.FlowerSizes.LARGE)
	
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func _on_reset_garden_button_pressed() -> void:
	var garden_ind: int = get_best_showing_garden()
	var garden: Garden = garden_parent.get_child(garden_ind)
	
	var flowers: Array[GardenLayout.Flower] = gardens_layout.gardens[garden_ind].flowers
	for index: int in range(flowers.size()):
		flowers[index] = GardenLayout.Flower.new()
	gardens_layout.gardens[garden_ind].flowers = flowers
	garden.set_flowers(flowers, Garden.FlowerSizes.LARGE)
	
	var lesson_buttons: Array = gardens_layout.gardens[garden_ind].lesson_buttons
	for index: int in range(lesson_buttons.size()):
		lesson_buttons[index] = GardenLayout.GardenLayoutLessonButton.new()
	gardens_layout.gardens[garden_ind].lesson_buttons = lesson_buttons
	garden.set_lesson_buttons(lesson_buttons)
	
	ResourceSaver.save(gardens_layout, gardens_layout.resource_path)


func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if dragging_element != null:
		return
	super(event)

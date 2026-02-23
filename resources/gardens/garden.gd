@tool
class_name Garden
extends Control

enum FlowerSizes{
	NOT_STARTED,
	SMALL,
	MEDIUM,
	LARGE
}

const FLOWER_PATH_MODEL: String = "res://assets/gardens/flowers/plant_%02d_%02d_%s.png"
const BACKGROUND_PATH_MODEL: String = "res://assets/gardens/gardens/garden_%02d_open.png"
const LESSON_BUTTON_SCENE: PackedScene = preload("res://sources/lesson_screen/lesson_button.tscn")
const FLOWER_MATERIAL_PATH: String = "res://resources/gardens/flower_material.tres"
const FLOWER_Z_INDEX: int = 1

@export var garden_layout: GardenLayout:
	set = set_garden_layout
@export var garden_colors: Array[Color] = []

var flowers: Array[GardenLayout.Flower] = []
var flowers_sizes: Array[FlowerSizes] = []
var flowers_visible: Array[bool] = []
var color: Color
var current_progression: float = 0.0
var max_progression: float = 0.0
var garden_index: int = -1

@onready var buttons: Control = $Buttons
@onready var flowers_container: Control = $Flowers
@onready var flower_material: Material = load(FLOWER_MATERIAL_PATH)
@onready var flower_controls: Array[TextureRect] = []
@onready var background: TextureRect = %Background


func get_button_size() -> Vector2:
	var lesson_buttons: Array[LessonButton] = get_lesson_buttons()
	if lesson_buttons.is_empty():
		return Vector2.ZERO
	return lesson_buttons[0].get_size()


func set_garden_layout(p_garden_layout: GardenLayout) -> void:
	if not p_garden_layout:
		Log.error("Garden: Cannot set garden layout because it is null")
		return
	garden_layout = p_garden_layout
	set_flowers(garden_layout.flowers)
	set_background(garden_layout.color)
	set_lesson_buttons(garden_layout.lesson_buttons)


func set_flowers(p_flowers: Array[GardenLayout.Flower], default_size: FlowerSizes = FlowerSizes.NOT_STARTED) -> void:
	flowers = p_flowers
	flowers_sizes = []
	flowers_visible = []
	for _i: int in range(flowers.size()):
		flowers_sizes.append(default_size)
		flowers_visible.append(true)
	_ensure_flower_controls_count(flowers.size())
	update_flowers()


func update_flowers() -> void:
	for index: int in range(flowers.size()):
		if index >= flower_controls.size():
			break
		var flower: GardenLayout.Flower = flowers[index]
		var flower_scene: TextureRect = flower_controls[index]
		var flower_is_visible: bool = index < flowers_visible.size() and flowers_visible[index]
		flower_scene.visible = flower_is_visible
		if not flower_is_visible:
			continue
		var flower_size: String = FlowerSizes.keys()[flowers_sizes[index]]
		flower_size = flower_size.to_lower()
		flower_scene.texture = load(FLOWER_PATH_MODEL % [flower.color+1, flower.type+1, flower_size])
		flower_scene.size = flower_scene.get_combined_minimum_size() * 3
		flower_scene.pivot_offset = Vector2(flower_scene.size.x / 2, flower_scene.size.y)
		flower_scene.position = Vector2(flower.position.x - flower_scene.size.x / 2, flower.position.y - flower_scene.size.y)


func set_lesson_buttons(p_lesson_buttons: Array[GardenLayout.GardenLayoutLessonButton]) -> void:
	_ensure_button_controls_count(p_lesson_buttons.size())
	var lesson_buttons: Array[LessonButton] = get_lesson_buttons()
	for lesson_button_control: LessonButton in lesson_buttons:
		lesson_button_control.hide()
	for index: int in range(p_lesson_buttons.size()):
		var lesson_button: GardenLayout.GardenLayoutLessonButton = p_lesson_buttons[index]
		var lesson_button_control: LessonButton = lesson_buttons[index]
		lesson_button_control.position = Vector2(lesson_button.position)
		lesson_button_control.show()
		lesson_button_control.pivot_offset = lesson_button_control.size / 2


func set_background(p_color: int) -> void:
	if not background:
		return
	background.texture = load(BACKGROUND_PATH_MODEL % [p_color+1])
	color = garden_colors[p_color]
	for button: LessonButton in get_lesson_buttons():
		button.completed_color = color


func _ensure_button_controls_count(target_count: int) -> void:
	while get_lesson_buttons().size() < target_count:
		var new_button: LessonButton = LESSON_BUTTON_SCENE.instantiate()
		new_button.completed_color = color
		buttons.add_child(new_button)
		new_button.owner = self


func _ensure_flower_controls_count(target_count: int) -> void:
	for child: Node in flowers_container.get_children():
		child.queue_free()
	flower_controls.clear()
	for _i: int in range(target_count):
		var new_flower: TextureRect = _create_flower_control()
		flowers_container.add_child(new_flower)
		new_flower.owner = self
		flower_controls.append(new_flower)


func _create_flower_control() -> TextureRect:
	var flower_control: TextureRect = TextureRect.new()
	flower_control.material = flower_material
	flower_control.z_index = FLOWER_Z_INDEX
	flower_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flower_control


func get_lesson_buttons() -> Array[LessonButton]:
	var lesson_buttons: Array[LessonButton] = []
	for button: Node in buttons.get_children():
		if button is LessonButton:
			lesson_buttons.append(button as LessonButton)
	return lesson_buttons


func set_lesson_label(ind: int, text: String) -> void:
	var lesson_buttons: Array[LessonButton] = get_lesson_buttons()
	assert(ind < lesson_buttons.size())
	lesson_buttons[ind].text = text


func get_progress_ratio() -> float:
	if max_progression <= 0.0:
		return 0.0
	return current_progression / max_progression

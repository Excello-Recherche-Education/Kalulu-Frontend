@tool
extends Control
class_name Garden

# Namespace
const GardenFlower: = preload("res://resources/gardens/garden_flower.gd")
const LessonButton: = preload("res://sources/lesson_screen/lesson_button.gd")

const flower_path_model: = "res://assets/gardens/flowers/Plant_%02d_%02d_%s.png"
const background_path_model: = "res://assets/gardens/gardens/garden_%02d_open.png"

@export var garden_layout: GardenLayout:
	set = set_garden_layout

@export var garden_colors: Array[Color]

@onready var buttons: Control = $Buttons
@onready var flower_controls: Array[TextureRect] = [
	%Flower1,
	%Flower2,
	%Flower3,
	%Flower4,
	%Flower5,
]
@onready var background: TextureRect = %Background
@onready var lesson_button_controls: Array[LessonButton] = [
	%Button1,
	%Button2,
	%Button3,
	%Button4,
]

enum FlowerSizes{
	NotStarted,
	Small,
	Medium,
	Large
}

var flowers: Array[GardenLayout.Flower]
var flowers_sizes: Array[FlowerSizes]
var color: Color


func get_button_size() -> Vector2:
	return lesson_button_controls[0].get_size()


func set_garden_layout(p_garden_layout: GardenLayout) -> void:
	garden_layout = p_garden_layout
	set_flowers(garden_layout.flowers)
	set_background(garden_layout.color)
	set_lesson_buttons(garden_layout.lesson_buttons)


func set_flowers(p_flowers: Array[GardenLayout.Flower], default_size: FlowerSizes = FlowerSizes.NotStarted) -> void:
	flowers = p_flowers
	
	flowers_sizes = []
	for _i in range(flowers.size()):
		flowers_sizes.append(default_size)
	
	update_flowers()


func update_flowers() -> void:
	for i in flowers.size():
		if i >= flower_controls.size():
			break
		var flower: = flowers[i]
		var flower_scene: = flower_controls[i]
		var flower_size: String = FlowerSizes.keys()[flowers_sizes[i]]
		
		flower_scene.texture = load(flower_path_model % [flower.color+1, flower.type+1, flower_size])
		flower_scene.size = flower_scene.get_combined_minimum_size() * 3
		flower_scene.pivot_offset = Vector2(flower_scene.size.x / 2, flower_scene.size.y)
		flower_scene.position = Vector2(flower.position.x - flower_scene.size.x / 2, flower.position.y - flower_scene.size.y)


func set_lesson_buttons(p_lesson_buttons: Array[GardenLayout.LessonButton]) -> void:
	for lesson_button_control in lesson_button_controls:
		lesson_button_control.visible = false
	for i in p_lesson_buttons.size():
		if i >= lesson_button_controls.size():
			break
		var lesson_button: = p_lesson_buttons[i]
		var lesson_button_control: = lesson_button_controls[i]
		lesson_button_control.position = Vector2(lesson_button.position)
		lesson_button_control.visible = true
		lesson_button_control.pivot_offset = lesson_button_control.size / 2


func set_background(p_color: int) -> void:
	if not background:
		return
	background.texture = load(background_path_model % [p_color+1])
	color = garden_colors[p_color]
	
	for button in lesson_button_controls:
		button.completed_color = color


func _ready() -> void:
	set_garden_layout(garden_layout)


func set_lesson_label(ind: int, text: String) -> void:
	assert(ind < lesson_button_controls.size())
	lesson_button_controls[ind].text = text


func pop_animation() -> void:
	var tween: = create_tween()
	tween.set_parallel(true)
	for flower_control in flower_controls:
		tween.tween_property(flower_control, "scale", Vector2(0, 0), 0.1)
	for lesson_button_control in lesson_button_controls:
		tween.tween_property(lesson_button_control, "scale", Vector2(0.7, 0.7), 0.1)
	await tween.finished
	tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	for flower_control in flower_controls:
		tween.tween_property(flower_control, "scale", Vector2(1., 1.), 0.9)
	for lesson_button_control in lesson_button_controls:
		tween.tween_property(lesson_button_control, "scale", Vector2(1., 1.), 0.9)

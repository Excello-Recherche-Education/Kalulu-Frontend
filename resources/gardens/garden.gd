@tool
extends Control

const flower_path_model: = "res://assets/gardens/flowers/Plant_%02d_%02d_%s.png"
const background_path_model: = "res://assets/gardens/gardens/garden_%02d_open.png"
const lesson_button_texture: = preload("res://assets/gardens/buttons/lesson_dot_front.png")

@onready var flower_controls: Array[TextureRect] = [
	%Flower1,
	%Flower2,
	%Flower3,
	%Flower4,
	%Flower5,
]
@onready var background: = %Background
@onready var lesson_button_controls: Array[TextureRect] = [
	%Button1,
	%Button2,
	%Button3,
	%Button4,
]
@onready var lesson_labels: Array[Label] = [
	%LessonLabel1,
	%LessonLabel2,
	%LessonLabel3,
	%LessonLabel4,
]


@export var garden_layout: GardenLayout:
	set = set_garden_layout


func get_button_size() -> Vector2:
	return lesson_button_texture.get_size()


func set_garden_layout(p_garden_layout: GardenLayout) -> void:
	garden_layout = p_garden_layout
	set_flowers(garden_layout.flowers)
	set_background(garden_layout.color)
	set_lesson_buttons(garden_layout.lesson_buttons)


func set_flowers(p_flowers: Array[GardenLayout.Flower]) -> void:
	for flower_control in flower_controls:
		flower_control.texture = null
	for i in p_flowers.size():
		if i >= flower_controls.size():
			break
		var flower: = p_flowers[i]
		var flower_control: = flower_controls[i]
		flower_control.texture = load(flower_path_model % [flower.color+1, flower.type+1, "Large"])
		flower_control.position = flower.position
		flower_control.size = flower_control.get_combined_minimum_size() * 3


func set_lesson_buttons(p_lesson_buttons: Array[GardenLayout.LessonButton]) -> void:
	for lesson_button_control in lesson_button_controls:
		lesson_button_control.texture = null
		lesson_button_control.visible = false
	for i in p_lesson_buttons.size():
		if i >= lesson_button_controls.size():
			break
		var lesson_button: = p_lesson_buttons[i]
		var lesson_button_control: = lesson_button_controls[i]
		lesson_button_control.texture = lesson_button_texture
		lesson_button_control.size = lesson_button_control.get_combined_minimum_size() * 3
		lesson_button_control.position = Vector2(lesson_button.position) - lesson_button_control.size / 4
		lesson_button_control.visible = true


func set_background(p_color: int) -> void:
	if not background:
		return
	background.texture = load(background_path_model % [p_color+1])


func _ready() -> void:
	set_garden_layout(garden_layout)


func set_lesson_label(ind: int, text: String) -> void:
	assert(ind < lesson_labels.size())
	lesson_labels[ind].text = text

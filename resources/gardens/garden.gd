@tool
class_name Garden
extends Control

const BACKGROUND_PATH_MODEL: String = "res://assets/gardens/gardens/Garden_%02d.png"
const MAX_LESSONS: int = 5
const PLANT_COUNT: int = 8

# Maps lesson count → which slot indices to use
const SLOT_SELECTION: Dictionary = {
	1: [2],
	2: [1, 3],
	3: [0, 2, 4],
	4: [0, 1, 3, 4],
	5: [0, 1, 2, 3, 4],
}

@export var garden_layout: GardenLayout:
	set = set_garden_layout
## Title is for developer reference only — not used in-game.
@export var title: String = ""
@export var unlocked_lesson: Color = Color("176d78")
@export var unlocked_lesson_text: Color = Color("9be3ea")
@export var completed_lesson: Color = Color("9be3ea")
@export var completed_lesson_text: Color = Color("0a555b")

var color: Color
var current_progression: float = 0.0
var max_progression: float = 0.0
var garden_index: int = -1
var active_buttons: Array[LessonButton] = []

@onready var all_slots: Array[LessonButton] = [
	$Buttons/Slot1, $Buttons/Slot2, $Buttons/Slot3, $Buttons/Slot4, $Buttons/Slot5
]
@onready var all_plants: Array[TextureRect] = [
	$Plants/Plant1, $Plants/Plant2, $Plants/Plant3, $Plants/Plant4,
	$Plants/Plant5, $Plants/Plant6, $Plants/Plant7, $Plants/Plant8
]
@onready var background: TextureRect = %Background


func set_garden_layout(p_garden_layout: GardenLayout) -> void:
	if not p_garden_layout:
		Log.error("Garden: Cannot set garden layout because it is null")
		return
	garden_layout = p_garden_layout
	set_background(garden_layout.color)
	_configure_slots(garden_layout.lesson_buttons.size())
	_apply_colors_to_buttons()
	_hide_all_plants()


func _configure_slots(lesson_count: int) -> void:
	if not all_slots or all_slots.is_empty():
		return
	if lesson_count > MAX_LESSONS:
		Log.error("Garden: Too many lessons (%d) for garden %d — maximum is %d" % [lesson_count, garden_index, MAX_LESSONS])
		lesson_count = MAX_LESSONS
	for slot: LessonButton in all_slots:
		slot.hide()
		slot.set_button_disabled(true)
	active_buttons.clear()
	var indices: Array = SLOT_SELECTION.get(lesson_count, [])
	for i: int in range(indices.size()):
		var slot: LessonButton = all_slots[indices[i]]
		slot.show()
		active_buttons.append(slot)


func set_background(p_color: int) -> void:
	if not background:
		return
	var path: String = BACKGROUND_PATH_MODEL % [p_color + 1]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else load(BACKGROUND_PATH_MODEL % [1])
	background.texture = texture
	background.modulate = unlocked_lesson
	color = unlocked_lesson


func _apply_colors_to_buttons() -> void:
	for button: LessonButton in active_buttons:
		button.set_garden_colors(unlocked_lesson, unlocked_lesson_text, completed_lesson, completed_lesson_text)


func _hide_all_plants() -> void:
	if not all_plants:
		return
	for plant: TextureRect in all_plants:
		plant.visible = false


func update_plants_visibility(completed_minigames: int, total_minigames: int) -> void:
	if not all_plants or total_minigames <= 0:
		return
	var visible_count: int = 0
	if completed_minigames >= total_minigames:
		visible_count = PLANT_COUNT
	elif completed_minigames > 0:
		visible_count = int(float(completed_minigames) * float(PLANT_COUNT) / float(total_minigames))
		visible_count = clampi(visible_count, 1, PLANT_COUNT - 1)
	for i: int in range(all_plants.size()):
		all_plants[i].visible = i < visible_count


func get_button_size() -> Vector2:
	if all_slots.is_empty():
		return Vector2.ZERO
	return all_slots[0].get_size()


func get_lesson_buttons() -> Array[LessonButton]:
	return active_buttons


func set_lesson_label(ind: int, text: String) -> void:
	assert(ind < active_buttons.size())
	active_buttons[ind].text = text


func get_slot_center(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= all_slots.size():
		return Vector2.ZERO
	var slot: LessonButton = all_slots[slot_index]
	return slot.position + slot.size / 2.0


func get_progress_ratio() -> float:
	if max_progression <= 0.0:
		return 0.0
	return current_progression / max_progression

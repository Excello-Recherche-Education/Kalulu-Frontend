@tool
class_name Garden
extends Control

const BACKGROUND_PATH_MODEL: String = "res://assets/gardens/gardens/garden_%02d.png"
const MAX_LESSONS: int = 5
# Maps lesson count → which slot indices to use
const SLOT_SELECTION: Dictionary = {
	1: [2],
	2: [1, 3],
	3: [0, 2, 4],
	4: [0, 1, 3, 4],
	5: [0, 1, 2, 3, 4],
}
const WHEEL_WEDGE_LOCKED: Color = Color("e6e6e6")
const ANIMAL_LOCKED_COLOR: Color = Color("c9c9c9")
const WHEEL_HIGHLIGHT: Color = Color("fbb03b")

@export var garden_layout: GardenLayout:
	set = set_garden_layout
## Title is for developer reference only — not used in-game.
@export var title: String = ""
@export var unlocked_lesson: Color = Color("0a555b")
@export var unlocked_lesson_text: Color = Color("9be3ea")
@export var completed_lesson: Color = Color("9be3ea")
@export var completed_lesson_text: Color = Color("0a555b")
@export_group("Wheel Colors")
@export var wheel_wedge_unlocked: Color = Color("9be3ea")
@export var wheel_background: Color = Color("0a555b")
## Outline color flagging the next step to play.
@export var animal_unlocked_color: Color = Color.WHITE

var color: Color
var current_progression: float = 0.0
var max_progression: float = 0.0
var garden_index: int = -1
var active_buttons: Array[LessonButton] = []

@onready var all_slots: Array[LessonButton] = [
	$Buttons/Slot1, $Buttons/Slot2, $Buttons/Slot3, $Buttons/Slot4, $Buttons/Slot5
]
@onready var all_victory_assets: Array[TextureRect] = []
@onready var background: TextureRect = %Background


func _ready() -> void:
	all_victory_assets.append_array(%Victory_Assets.get_children().filter(func(node: Node) -> bool:
		return node is TextureRect
	))


func set_garden_layout(p_garden_layout: GardenLayout) -> void:
	if not p_garden_layout:
		Log.error("Garden: Cannot set garden layout because it is null")
		return
	garden_layout = p_garden_layout
	set_background(garden_layout.color)
	_configure_slots(garden_layout.lesson_buttons.size())
	_apply_colors_to_buttons()
	_hide_all_victory_assets()


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
	for index: int in range(indices.size()):
		var slot: LessonButton = all_slots[indices[index]]
		slot.show()
		active_buttons.append(slot)


func set_background(p_color: int) -> void:
	if not background:
		return
	var path: String = BACKGROUND_PATH_MODEL % [p_color + 1]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else load(BACKGROUND_PATH_MODEL % [1])
	background.texture = texture
	color = unlocked_lesson


func _apply_colors_to_buttons() -> void:
	for button: LessonButton in active_buttons:
		button.set_garden_colors(unlocked_lesson, unlocked_lesson_text, completed_lesson, completed_lesson_text)


func _hide_all_victory_assets() -> void:
	if not all_victory_assets:
		return
	for asset: TextureRect in all_victory_assets:
		asset.visible = false


func update_victory_assets_visibility(completed_minigames: int, total_minigames: int) -> void:
	if not all_victory_assets or total_minigames <= 0:
		return
	var visible_count: int = 0
	if completed_minigames >= total_minigames:
		visible_count = all_victory_assets.size()
	elif completed_minigames > 0:
		visible_count = int(float(completed_minigames) * float(all_victory_assets.size()) / float(total_minigames))
		visible_count = clampi(visible_count, 1, all_victory_assets.size() - 1)
	for index: int in range(all_victory_assets.size()):
		all_victory_assets[index].visible = index < visible_count


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

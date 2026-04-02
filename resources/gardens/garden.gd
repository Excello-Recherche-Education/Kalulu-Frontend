@tool
class_name Garden
extends Control

const BACKGROUND_PATH_MODEL: String = "res://assets/gardens/gardens/Garden_%02d.png"
const PLANT_PATH_MODEL: String = "res://assets/gardens/plants/garden_plant_%02d.png"
const PLANT_COUNT: int = 8
const MAX_LESSONS: int = 5

# Maps lesson count → which slot indices to use
const SLOT_SELECTION: Dictionary = {
	1: [2],
	2: [1, 3],
	3: [0, 2, 4],
	4: [0, 1, 3, 4],
	5: [0, 1, 2, 3, 4],
}

# Plant positions and sizes (x, y, w, h) — matching the Explanation.png layout.
# Positions are relative to the garden control (2400x1800).
const PLANT_LAYOUTS: Array[Dictionary] = [
	{x = 280, y = 300, w = 120, h = 950},   # 01: tall seaweed, far left
	{x = 530, y = 1320, w = 210, h = 350},  # 02: short bush, bottom-left
	{x = 1150, y = 1200, w = 440, h = 330}, # 03: fish school, bottom-right
	{x = 820, y = 530, w = 300, h = 420},   # 04: plant cluster, center-left
	{x = 650, y = 820, w = 145, h = 310},   # 05: small plant, left of center
	{x = 1560, y = 720, w = 185, h = 315},  # 06: small seaweed, right side
	{x = 720, y = 1250, w = 130, h = 520},  # 07: medium seaweed, bottom-center
	{x = 1050, y = 480, w = 400, h = 400},  # 08: fish school, upper-center
]

@export var garden_layout: GardenLayout:
	set = set_garden_layout
@export var garden_colors: Array[Color] = []

var color: Color
var current_progression: float = 0.0
var max_progression: float = 0.0
var garden_index: int = -1
var active_buttons: Array[LessonButton] = []
var plant_controls: Array[TextureRect] = []

@onready var all_slots: Array[LessonButton] = [
	$Buttons/Slot1, $Buttons/Slot2, $Buttons/Slot3, $Buttons/Slot4, $Buttons/Slot5
]
@onready var plants_container: Control = $Plants
@onready var background: TextureRect = %Background


func _ready() -> void:
	_create_plants()


func set_garden_layout(p_garden_layout: GardenLayout) -> void:
	if not p_garden_layout:
		Log.error("Garden: Cannot set garden layout because it is null")
		return
	garden_layout = p_garden_layout
	set_background(garden_layout.color)
	_configure_slots(garden_layout.lesson_buttons.size())


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
	background.modulate = LessonButton.UNLOCKED_FILL_COLOR
	color = garden_colors[p_color]


func _create_plants() -> void:
	if not plants_container:
		return
	for i: int in range(PLANT_COUNT):
		var plant: TextureRect = TextureRect.new()
		plant.texture = load(PLANT_PATH_MODEL % [i + 1])
		plant.expand_mode = 1
		plant.stretch_mode = 5
		plant.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var layout: Dictionary = PLANT_LAYOUTS[i]
		plant.position = Vector2(layout.x, layout.y)
		plant.size = Vector2(layout.w, layout.h)
		plant.visible = false
		plants_container.add_child(plant)
		plant_controls.append(plant)


func update_plants_visibility(completed_minigames: int, total_minigames: int) -> void:
	if total_minigames <= 0:
		return
	# Distribute 8 plants across the total minigame count.
	# 0 completed → 0 visible, all completed → all 8 visible.
	var visible_count: int = 0
	if completed_minigames >= total_minigames:
		visible_count = PLANT_COUNT
	elif completed_minigames > 0:
		visible_count = int(float(completed_minigames) * float(PLANT_COUNT) / float(total_minigames))
		visible_count = clampi(visible_count, 1, PLANT_COUNT - 1)
	for i: int in range(plant_controls.size()):
		plant_controls[i].visible = i < visible_count


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

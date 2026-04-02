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
const BACKGROUND_PATH_MODEL: String = "res://assets/gardens/gardens/Garden_%02d.png"
const FLOWER_MATERIAL_PATH: String = "res://resources/gardens/flower_material.tres"
const FLOWER_Z_INDEX: int = 1
const MAX_LESSONS: int = 5

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
@export var garden_colors: Array[Color] = []

var flowers: Array[GardenLayout.Flower] = []
var flowers_sizes: Array[FlowerSizes] = []
var flowers_visible: Array[bool] = []
var color: Color
var current_progression: float = 0.0
var max_progression: float = 0.0
var garden_index: int = -1
# Maps visible button index → slot node
var active_buttons: Array[LessonButton] = []

@onready var all_slots: Array[LessonButton] = [
	$Buttons/Slot1, $Buttons/Slot2, $Buttons/Slot3, $Buttons/Slot4, $Buttons/Slot5
]
@onready var flowers_container: Control = $Flowers
@onready var flower_material: Material = load(FLOWER_MATERIAL_PATH)
@onready var flower_controls: Array[TextureRect] = []
@onready var background: TextureRect = %Background


func get_button_size() -> Vector2:
	if all_slots.is_empty():
		return Vector2.ZERO
	return all_slots[0].get_size()


func set_garden_layout(p_garden_layout: GardenLayout) -> void:
	if not p_garden_layout:
		Log.error("Garden: Cannot set garden layout because it is null")
		return
	garden_layout = p_garden_layout
	set_flowers(garden_layout.flowers)
	set_background(garden_layout.color)
	_configure_slots(garden_layout.lesson_buttons.size())


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


func _configure_slots(lesson_count: int) -> void:
	if not all_slots or all_slots.is_empty():
		return
	if lesson_count > MAX_LESSONS:
		Log.error("Garden: Too many lessons (%d) for garden %d — maximum is %d" % [lesson_count, garden_index, MAX_LESSONS])
		lesson_count = MAX_LESSONS
	# Hide all slots
	for slot: LessonButton in all_slots:
		slot.hide()
		slot.set_button_disabled(true)
	# Show only selected slots
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

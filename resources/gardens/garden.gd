@tool
class_name Garden
extends Control

const GRAYSCALE_SHADER: Shader = preload("res://resources/shaders/grayscale.gdshader")
const RECOLOR_SHADER: Shader = preload("res://resources/shaders/recolor.gdshader")
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

## Title is for developer reference only — not used in-game.
@export var title: String = ""
## The garden's animal sprite(s) (jellyfish, turtle, ...), assigned per garden
## scene. The brain overview desaturates them when the garden has no unlocked
## lesson. See set_greyed_out().
@export var animal_sprites: Array[TextureRect] = []
@export var unlocked_lesson: Color = Color("0a555b")
@export var unlocked_lesson_text: Color = Color("9be3ea")
@export var completed_lesson: Color = Color("9be3ea")
@export var completed_lesson_text: Color = Color("0a555b")
@export_group("Wheel Colors")
@export var wheel_wedge_unlocked: Color = Color("9be3ea")
@export var wheel_background: Color = Color("0a555b")
## Outline color flagging the next step to play.
@export var animal_unlocked_color: Color = Color.WHITE

var current_progression: float = 0.0
var max_progression: float = 0.0
var garden_index: int = -1
var active_buttons: Array[LessonButton] = []
# Background modulate authored in the garden scene, restored when un-greying.
var _default_background_modulate: Color = Color.WHITE
# Shared recolor material driving the brain-screen final-boss purple animation.
var _recolor_material: ShaderMaterial

@onready var all_slots: Array[LessonButton] = [
	$Buttons/Slot1, $Buttons/Slot2, $Buttons/Slot3, $Buttons/Slot4, $Buttons/Slot5
]
@onready var all_victory_assets: Array[TextureRect] = []
@onready var background: TextureRect = %Background


func _ready() -> void:
	all_victory_assets.append_array(%Victory_Assets.get_children().filter(func(node: Node) -> bool:
		return node is TextureRect
	))
	if background:
		_default_background_modulate = background.modulate


# Shows and configures `lesson_count` of the garden's fixed slots (see _configure_slots
# and SLOT_SELECTION). The background and slot positions are authored in the garden
# scene, so nothing else needs to be set here.
func set_lesson_count(lesson_count: int) -> void:
	_configure_slots(lesson_count)
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


# Brain overview only: a garden with no unlocked lesson is shown "asleep" — its
# background drops its color tint (plain white modulate) and its animal(s) are
# desaturated through grayscale.gdshader. A garden with at least one unlocked
# lesson keeps its default colors.
func set_greyed_out(is_greyed_out: bool) -> void:
	if background:
		background.modulate = Color.WHITE if is_greyed_out else _default_background_modulate
	var grayscale: ShaderMaterial = null
	if is_greyed_out:
		grayscale = ShaderMaterial.new()
		grayscale.shader = GRAYSCALE_SHADER
	for animal: TextureRect in animal_sprites:
		animal.material = grayscale


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


func get_reward_color() -> Color:
	return _default_background_modulate if background else wheel_background


func get_reward_rect() -> Rect2:
	return background.get_global_rect() if background else get_global_rect()


#region Reward recolor (brain-screen final-boss animation)

# Assigns a fresh recolor ShaderMaterial (target `color`, mix 0) to the garden's
# art sprites — background, victory-asset plants and animals, but NOT the lesson
# buttons (they stay white and readable). Returns the material so the caller can
# tween its `shader_parameter/mix_amount` 0 -> 1 for a smooth purple transition.
# Mirrors the per-sprite material assignment used by set_greyed_out().
func apply_recolor(color: Color) -> ShaderMaterial:
	_recolor_material = ShaderMaterial.new()
	_recolor_material.shader = RECOLOR_SHADER
	_recolor_material.set_shader_parameter("target_color", color)
	_recolor_material.set_shader_parameter("mix_amount", 0.0)
	for sprite: CanvasItem in _recolorable_sprites():
		sprite.material = _recolor_material
	return _recolor_material


func get_recolor_material() -> ShaderMaterial:
	return _recolor_material


func clear_recolor() -> void:
	for sprite: CanvasItem in _recolorable_sprites():
		sprite.material = null
	_recolor_material = null


func _recolorable_sprites() -> Array[CanvasItem]:
	var sprites: Array[CanvasItem] = []
	if background:
		sprites.append(background)
	for asset: TextureRect in all_victory_assets:
		sprites.append(asset)
	for animal: TextureRect in animal_sprites:
		sprites.append(animal)
	return sprites

#endregion

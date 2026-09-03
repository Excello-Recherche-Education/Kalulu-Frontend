class_name BossUnlock
extends Node
## One boss row of the student progress table.
##
## The bosses are steps of the same linear timeline as the lessons: the boss closing
## a garden comes after that garden's last lesson and before the next garden's first,
## and the final boss after the last lesson of all. So a boss row offers the three
## positions the frontier can take around it, and reads back the one it is in:
##
##   Locked      the garden it closes is unfinished, so the boss is out of reach
##   Unlocked    the garden is finished and the boss is what the child plays next
##   Completed   the boss is beaten, which is what opens the next garden
##
## Marking one completed therefore finishes every garden up to it and opens the one
## after -- see StudentProgression.apply_manual_boss_progression.

signal unlocks_changed()

## Translation key per state, reusing the lesson row's vocabulary.
const STATE_LABELS: Dictionary[int, String] = {
	StudentProgression.Status.LOCKED: "LOCKED",
	StudentProgression.Status.UNLOCKED: "UNLOCKED",
	StudentProgression.Status.COMPLETED: "COMPLETED",
}
const ORDERED_STATES: Array[StudentProgression.Status] = [
	StudentProgression.Status.LOCKED,
	StudentProgression.Status.UNLOCKED,
	StudentProgression.Status.COMPLETED,
]
## The icons, loaded on demand for the same reason GardenIdentity loads its animals
## that way: a screen that never opens this table should not be holding them. They
## carry their own circular background, so they need no badge behind them.
const BOSS_ICON_PATH: String = "res://assets/brain/boss_unlocked.png"
const BOSS_ICON_LOCKED_PATH: String = "res://assets/brain/boss_locked.png"
const FINAL_BOSS_ICON_PATH: String = "res://assets/brain/treasure_opened.png"
const FINAL_BOSS_ICON_LOCKED_PATH: String = "res://assets/brain/treasure_closed.png"

## The last lesson of the garden this boss closes -- for the final boss, the pack's
## last lesson, which is not a gate of its own.
@export var gate_lesson: int = 0
## Which garden this boss closes, counting from zero, or -1 while it is unknown.
@export var garden_index: int = -1
## The final boss stands after every garden rather than between two of them, and is
## recorded apart from the gates (see StudentProgression.final_boss_completed).
@export var is_final: bool = false

var progression: StudentProgression = null

@onready var boss_icon: TextureRect = %BossIcon
@onready var garden_animal: TextureRect = %GardenAnimal
@onready var boss_label: Label = %BossLabel
@onready var status_option_button: OptionButton = %StatusOptionButton


func _ready() -> void:
	status_option_button.item_selected.connect(_on_status_item_selected)
	_sync_items()
	reload()


func get_grid_cells() -> Array[Control]:
	return [boss_icon, garden_animal, boss_label, status_option_button]


func reload() -> void:
	if not boss_icon:
		return
	boss_label.text = tr("FINAL_BOSS" if is_final else "BOSS")
	boss_label.add_theme_color_override("font_color", Design.NAVY)
	# The final boss stands past the last garden rather than inside one, so it wears
	# no animal: it belongs to no garden, and borrowing the last one's would read as
	# the boss that closes it.
	garden_animal.texture = null if is_final else GardenIdentity.animal_texture(garden_index)

	if not progression or not progression.unlocks.has(gate_lesson):
		status_option_button.disabled = true
		status_option_button.select(-1)
		_refresh_icon(StudentProgression.Status.LOCKED)
		return

	status_option_button.disabled = false
	var state: StudentProgression.Status = boss_state()
	_select_state(state)
	_refresh_icon(state)


## Where the student stands with this boss.
func boss_state() -> StudentProgression.Status:
	if not progression:
		return StudentProgression.Status.LOCKED
	return progression.boss_state(gate_lesson, is_final)


func _sync_items() -> void:
	if status_option_button.item_count == ORDERED_STATES.size():
		return
	status_option_button.clear()
	for state: StudentProgression.Status in ORDERED_STATES:
		status_option_button.add_item(tr(STATE_LABELS[state]), state)


func _select_state(state: StudentProgression.Status) -> void:
	for index: int in status_option_button.item_count:
		if status_option_button.get_item_id(index) == state:
			status_option_button.select(index)
			return
	status_option_button.select(-1)


## A beaten boss shows the icon the child sees once it is beaten, so the row reads at
## a glance rather than only through its dropdown.
func _refresh_icon(state: StudentProgression.Status) -> void:
	var beaten: bool = state == StudentProgression.Status.COMPLETED
	var path: String
	if is_final:
		path = FINAL_BOSS_ICON_PATH if beaten else FINAL_BOSS_ICON_LOCKED_PATH
	else:
		path = BOSS_ICON_PATH if beaten else BOSS_ICON_LOCKED_PATH
	boss_icon.texture = load(path) as Texture2D


func _on_status_item_selected(index: int) -> void:
	if not progression or not progression.unlocks.has(gate_lesson):
		return
	var state: StudentProgression.Status = status_option_button.get_item_id(index) as StudentProgression.Status
	progression.apply_manual_boss_progression(gate_lesson, state, is_final)
	Log.info("BossUnlock: Boss at lesson %d set to %s" % [gate_lesson, STATE_LABELS[state]])
	unlocks_changed.emit()

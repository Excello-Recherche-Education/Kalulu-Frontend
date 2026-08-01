class_name LessonUnlock
extends Node
## One row of the student progress table: a lesson and how far into it the
## student is.
##
## Progression is a single linear timeline -- for each lesson its look-and-learn
## then its minigames in order -- so a lesson has one status rather than one per
## step. Unlocking a step already implies every step before it is finished, and
## finishing one implies the next is unlocked, which is what
## StudentProgression.apply_manual_progression enforces. A dropdown per exercise
## could only ever set states the timeline would immediately rewrite.

signal unlocks_changed()

@export var lesson_number: int:
	set = _set_lesson_number
@export var lesson_gps: String:
	set = _set_lesson_gps
@export var unlocks: Dictionary = {}

@onready var lesson_label: Label = %LessonLabel
@onready var gps_label: Label = %GPsLabel
@onready var status_option_button: OptionButton = %StatusOptionButton


func _ready() -> void:
	for status: String in StudentProgression.Status:
		status_option_button.add_item(tr(status))
	status_option_button.item_selected.connect(_on_status_item_selected)
	reload()


func get_grid_cells() -> Array[Control]:
	return [lesson_label, gps_label, status_option_button]


func reload() -> void:
	_set_lesson_number(lesson_number)
	_set_lesson_gps(lesson_gps)


## How far the student is into this lesson, read back from its individual steps.
##
## Every step finished reads as completed and none started reads as locked;
## anything in between is the lesson in progress. The timeline keeps the steps
## consistent, so there is no partial state to disambiguate.
func lesson_status() -> StudentProgression.Status:
	if not unlocks.has(lesson_number):
		return StudentProgression.Status.LOCKED
	var completed: bool = true
	var locked: bool = true
	for step: int in _step_statuses():
		if step != StudentProgression.Status.COMPLETED:
			completed = false
		if step != StudentProgression.Status.LOCKED:
			locked = false
	if completed:
		return StudentProgression.Status.COMPLETED
	if locked:
		return StudentProgression.Status.LOCKED
	return StudentProgression.Status.UNLOCKED


func _step_statuses() -> Array[int]:
	var entry: Dictionary = unlocks[lesson_number]
	var statuses: Array[int] = [entry["look_and_learn"] as int]
	for game: int in entry["games"]:
		statuses.append(game)
	return statuses


func _set_lesson_number(value: int) -> void:
	lesson_number = value

	if not lesson_label:
		return

	lesson_label.text = str(lesson_number)

	# A student's progression can predate a pack that added lessons, and rows are
	# refreshed per student rather than rebuilt, so a missing lesson must not take
	# the panel down.
	if not unlocks.has(lesson_number):
		Log.trace("LessonUnlock: No progression entry for lesson %d" % lesson_number)
		status_option_button.disabled = true
		status_option_button.select(-1)
		return

	status_option_button.disabled = false
	status_option_button.select(lesson_status() as int)


func _set_lesson_gps(value: String) -> void:
	lesson_gps = value
	if not gps_label:
		return

	gps_label.text = value


func _on_status_item_selected(index: int) -> void:
	if not unlocks.has(lesson_number):
		return
	var status: StudentProgression.Status = index as StudentProgression.Status
	# Completing a lesson means its last step is done, so the frontier lands on
	# the next lesson. Locking or unlocking it moves the frontier to its first
	# step instead.
	var slot: int = StudentProgression.LOOK_AND_LEARN_SLOT
	if status == StudentProgression.Status.COMPLETED:
		var games: Array = unlocks[lesson_number]["games"]
		if not games.is_empty():
			slot = games.size() - 1
	StudentProgression.apply_manual_progression(unlocks, lesson_number, slot, status)
	unlocks_changed.emit()

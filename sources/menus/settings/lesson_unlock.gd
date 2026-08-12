class_name LessonUnlock
extends Node
## One row of the student progress table: a lesson and where the student is in it.
##
## Progression is a single linear timeline -- for each lesson its look-and-learn
## followed by its minigames in order -- with one frontier marking what the
## student may play next. A lesson's state names where that frontier sits inside
## it, so the states are exactly the frontier's possible positions:
##
##   Locked          nothing in the lesson is reachable
##   Look and learn  the look-and-learn is playable, nothing else yet
##   Exercise N      the look-and-learn and exercises before N are finished, so
##                   N is playable -- and so is anything before it, again
##   Finished        every step is done, which puts the next lesson on its
##                   look-and-learn
##
## A lesson has one to three minigames, so it offers three to six states. Setting
## one moves the frontier, and StudentProgression.apply_manual_progression
## rewrites the timeline around it.

signal unlocks_changed()

enum State {
	LOCKED,
	LOOK_AND_LEARN,
	EXERCISE_1,
	EXERCISE_2,
	EXERCISE_3,
	FINISHED,
}

## Translation key per state. "Finished" reuses COMPLETED, which already reads as
## exactly that in every locale.
const STATE_LABELS: Dictionary[int, String] = {
	State.LOCKED: "LOCKED",
	State.LOOK_AND_LEARN: "LOOKANDLEARN",
	State.EXERCISE_1: "EXERCISE1",
	State.EXERCISE_2: "EXERCISE2",
	State.EXERCISE_3: "EXERCISE3",
	State.FINISHED: "COMPLETED",
}
const MAX_EXERCISES: int = 3
## Side of the round badges the number and the grapheme sit in.
const BADGE_DIAMETER: int = 96

@export var lesson_number: int:
	set = _set_lesson_number
@export var lesson_gps: String:
	set = _set_lesson_gps
## Which garden hosts this lesson, counting from zero, or -1 while it is unknown.
##
## It colours the row and picks the animal, so a teacher scanning sixty lessons can
## see where each one sits by the same landmarks the child navigates by.
@export var garden_index: int = -1:
	set = _set_garden_index
@export var unlocks: Dictionary = {}

@onready var lesson_badge: Panel = %LessonBadge
@onready var lesson_label: Label = %LessonLabel
@onready var garden_animal: TextureRect = %GardenAnimal
@onready var grapheme_badge: Panel = %GraphemeBadge
@onready var grapheme_label: Label = %GraphemeLabel
@onready var status_option_button: OptionButton = %StatusOptionButton


func _ready() -> void:
	status_option_button.item_selected.connect(_on_status_item_selected)
	reload()


func get_grid_cells() -> Array[Control]:
	return [lesson_badge, garden_animal, grapheme_badge, status_option_button]


func reload() -> void:
	_set_lesson_number(lesson_number)
	_set_lesson_gps(lesson_gps)
	_set_garden_index(garden_index)


## Where the student is in this lesson, read back from its steps.
func lesson_state() -> State:
	if not unlocks.has(lesson_number):
		return State.LOCKED
	var entry: Dictionary = unlocks[lesson_number]
	var look_and_learn: int = entry["look_and_learn"]
	# The frontier is a single position, so the look-and-learn being locked means
	# the whole lesson is, and it being unlocked means nothing past it has started.
	if look_and_learn == StudentProgression.Status.LOCKED:
		return State.LOCKED
	if look_and_learn == StudentProgression.Status.UNLOCKED:
		return State.LOOK_AND_LEARN
	var games: Array = entry["games"]
	for index: int in games.size():
		if games[index] != StudentProgression.Status.COMPLETED:
			return (State.EXERCISE_1 + index) as State
	return State.FINISHED


## The states this lesson can be in, which depends on how many minigames it has.
func offered_states() -> Array[int]:
	var states: Array[int] = [State.LOCKED, State.LOOK_AND_LEARN]
	for index: int in mini(_minigame_count(), MAX_EXERCISES):
		states.append(State.EXERCISE_1 + index)
	states.append(State.FINISHED)
	return states


func _minigame_count() -> int:
	if not unlocks.has(lesson_number):
		return 0
	return (unlocks[lesson_number]["games"] as Array).size()


## Refills the dropdown when the number of exercises offered has changed.
##
## Only the minigame count varies, so comparing item counts is enough. It matters
## that this is cheap: sixty rows are refreshed every time a student is opened,
## and repopulating each dropdown was most of the two seconds that used to cost.
func _sync_items() -> void:
	var states: Array[int] = offered_states()
	if status_option_button.item_count == states.size():
		return
	status_option_button.clear()
	for state: int in states:
		status_option_button.add_item(tr(STATE_LABELS[state]), state)


func _select_state(state: int) -> void:
	for index: int in status_option_button.item_count:
		if status_option_button.get_item_id(index) == state:
			status_option_button.select(index)
			return
	status_option_button.select(-1)


func _set_lesson_number(value: int) -> void:
	lesson_number = value

	if not lesson_label:
		return

	lesson_label.text = str(lesson_number)
	_sync_items()

	# A student's progression can predate a pack that added lessons, and rows are
	# refreshed per student rather than rebuilt, so a missing lesson must not take
	# the panel down.
	if not unlocks.has(lesson_number):
		Log.trace("LessonUnlock: No progression entry for lesson %d" % lesson_number)
		status_option_button.disabled = true
		status_option_button.select(-1)
		return

	status_option_button.disabled = false
	_select_state(lesson_state())


func _set_lesson_gps(value: String) -> void:
	lesson_gps = value
	if not grapheme_label:
		return

	grapheme_label.text = first_grapheme(value)


## The grapheme a lesson is known by: the first of the ones it teaches.
##
## The same one the child reads on the garden button, which takes it from the
## database in this order. The rest follow from it -- a lesson on "a" also teaches
## "à" and "â" -- and a table of sixty rows is not where to list them.
static func first_grapheme(gps: String) -> String:
	# The pairs arrive already joined, "a-a à-a â-a", so the first grapheme is cut
	# back out: up to the first space, then up to the dash that starts its phoneme.
	return gps.get_slice(" ", 0).get_slice("-", 0)


func _set_garden_index(value: int) -> void:
	garden_index = value
	if not lesson_badge:
		return

	_paint_badge(lesson_badge, lesson_label)
	_paint_badge(grapheme_badge, grapheme_label)
	garden_animal.texture = GardenIdentity.animal_texture(garden_index)


## Puts the garden's colours on one badge.
func _paint_badge(badge: Panel, label: Label) -> void:
	# A style box per badge rather than one shared in the scene: sub-resources are
	# shared between instances, so every row would end up the colour of whichever
	# garden was painted last.
	var circle: StyleBoxFlat = StyleBoxFlat.new()
	circle.bg_color = GardenIdentity.badge_color(garden_index)
	circle.set_corner_radius_all(floori(float(BADGE_DIAMETER) / 2.0))
	badge.add_theme_stylebox_override("panel", circle)
	label.add_theme_color_override("font_color", GardenIdentity.badge_text_color(garden_index))


func _on_status_item_selected(index: int) -> void:
	if not unlocks.has(lesson_number):
		return
	var state: int = status_option_button.get_item_id(index)
	var games: Array = unlocks[lesson_number]["games"]
	var slot: int = StudentProgression.LOOK_AND_LEARN_SLOT
	var status: StudentProgression.Status = StudentProgression.Status.UNLOCKED
	match state:
		State.LOCKED:
			# Frontier before the lesson, so it and everything after it locks.
			status = StudentProgression.Status.LOCKED
		State.LOOK_AND_LEARN:
			pass # Frontier on the look-and-learn, which is the default above.
		State.FINISHED:
			# Frontier past the lesson's last step, which lands it on the next
			# lesson's look-and-learn.
			status = StudentProgression.Status.COMPLETED
			if not games.is_empty():
				slot = games.size() - 1
		_:
			# Frontier on that exercise, so the steps before it read as finished.
			slot = state - State.EXERCISE_1
	StudentProgression.apply_manual_progression(unlocks, lesson_number, slot, status)
	unlocks_changed.emit()

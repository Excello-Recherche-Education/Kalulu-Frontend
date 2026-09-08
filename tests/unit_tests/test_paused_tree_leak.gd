extends GutTest
## The pause a minigame takes must never outlive the minigame.
##
## Two things in minigame_ui pause the whole tree: the pause menu, and Kalulu
## talking. Both can be walked out of, because the back and restart buttons sit
## under a CanvasLayer whose process_mode is ALWAYS and so keep working while
## everything else is frozen. And get_tree().paused is global: it survives the
## scene change.
##
## What that costs is out of all proportion, and it is why this file exists rather
## than a note somewhere. The gardens' _ready() raises a full-screen Lock, then
## waits on a timer, a curtain and a tween -- every one of them paused too. It never
## reaches _unlock(). The player lands on a garden that looks completely normal,
## opens a lesson (opening the wheel is the one path the lock does not guard), and
## then nothing responds: not a wedge, not the look-and-learn button, not even
## clicking outside to close the wheel again. Every one of those handlers begins
## with `if is_locked: return`.

const GARDENS: String = "res://sources/gardens/gardens.tscn"
const MINIGAME: String = "res://sources/minigames/jellyfish/jellyfish_minigame.tscn"


func before_each() -> void:
	get_tree().paused = false


func after_each() -> void:
	get_tree().paused = false


func _sign_in() -> String:
	var student_on_open: String = UserDataManager.student
	if UserDataManager.student_progression:
		return student_on_open
	var settings: TeacherSettings = UserDataManager.teacher_settings
	if settings:
		for device: int in settings.students.keys():
			for student: StudentData in settings.students[device]:
				# Set directly rather than through login_student, which would also
				# open a session and call the server.
				UserDataManager.student = str(student.code)
				return student_on_open
	return student_on_open


# --- The leak itself -------------------------------------------------------------
func test_a_minigame_gives_the_tree_back_when_it_leaves() -> void:
	if not Database.is_open:
		pending("needs an installed language pack")
		return
	var student_on_open: String = _sign_in()
	Minigame.transition_data = {
		current_lesson_number = 12,
		current_garden_index = 0,
		minigame_number = 0,
		minigame_completed = false,
	}
	var game: Node = (load(MINIGAME) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	# However the screen came to be paused -- Kalulu talking, or the pause menu --
	# walking out of it must not take the pause along.
	get_tree().paused = true

	game.free()
	await get_tree().process_frame

	assert_false(get_tree().paused, "a minigame must not pause the screen after it")
	UserDataManager.student = student_on_open
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


# --- What the leak used to do ----------------------------------------------------
func test_a_paused_tree_would_leave_the_gardens_locked() -> void:
	# Not a wish, a demonstration: this is the state the leak produced, and it is
	# what makes the test above worth having. Read on a paused tree on purpose.
	if not Database.is_open:
		pending("needs an installed language pack")
		return
	var student_on_open: String = _sign_in()
	if not UserDataManager.student_progression:
		pending("needs a registered student")
		return
	# Coming back out of a minigame, which is how a leaked pause is met in practice
	# -- and the path whose _ready() waits on a timer before it unlocks.
	Gardens.transition_data = {
		current_lesson_number = UserDataManager.student_progression.get_max_unlocked_lesson_index() + 1,
		current_garden_index = 0,
		minigame_number = 0,
		minigame_completed = true,
		first_clear = false,
	}
	get_tree().paused = true
	var gardens: Gardens = (load(GARDENS) as PackedScene).instantiate()
	add_child(gardens)
	for _index: int in 60:
		await get_tree().process_frame

	assert_true(gardens.is_locked,
		"the lock _ready() raises is never lifted, because everything it waits on is paused")
	assert_true(gardens.lock.visible, "and the lock is what swallows every click")

	# And with the pause lifted the gardens finish opening on their own.
	get_tree().paused = false
	for _index: int in 600:
		await get_tree().process_frame
		if not gardens.is_locked:
			break

	assert_false(gardens.is_locked, "given a running tree the gardens unlock themselves")
	Gardens.transition_data = {}
	gardens.free()
	UserDataManager.student = student_on_open
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


# --- Skipping cannot strand the speech -------------------------------------------
func test_skipping_before_the_speech_starts_does_not_strand_kalulu() -> void:
	# The skip button works by forging audio_player.finished. Pressed during the
	# show animation -- where the sound playing is the whoosh, not the speech -- it
	# used to emit into nothing, and the await that came afterwards waited forever
	# on a sound that had already stopped. speech_ended never fired, so the pause
	# was never lifted.
	var helper: Node = (load(
		"res://sources/minigames/base/kalulu_ingame.tscn") as PackedScene).instantiate()
	add_child_autofree(helper)
	await get_tree().process_frame
	var ended: Array[bool] = [false]
	helper.speech_ended.connect(func() -> void: ended[0] = true)

	# Tapped before anything is waiting on a speech.
	helper._on_pass_button_pressed()
	helper.play_kalulu_speech(null, false, false)
	for _index: int in 600:
		await get_tree().process_frame
		if ended[0]:
			break

	assert_true(ended[0], "the speech has to end, or the tree stays paused")
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true

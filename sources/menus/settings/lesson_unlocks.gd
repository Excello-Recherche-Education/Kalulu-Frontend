class_name LessonUnlocks
extends Control

signal student_deleted(code: int)

const DEVICE_BUTTON_SCENE: PackedScene = preload("res://sources/menus/main/device_button.tscn")
const LESSON_UNLOCK_SCENE: PackedScene = preload("res://sources/menus/settings/lesson_unlock.tscn")
const BOSS_UNLOCK_SCENE: PackedScene = preload("res://sources/menus/settings/boss_unlock.tscn")

@export var device: int:
	set = _on_device_changed
@export var student: int:
	set = _on_student_changed

var progression: StudentProgression
var teacher_settings: SettingsTeacherSettings = null
# Snapshot taken when a student is loaded, so closing the panel without editing
# anything does not bump `last_modified`. A stale bump makes the local copy look
# newer than the server's and gets it pushed on the next synchronization.
var _unlocks_on_open: Dictionary = {}
var _highest_boss_on_open: int = 0

@onready var lessons_grid: GridContainer = %LessonsGrid
@onready var lesson_rows_store: Node = %LessonRowsStore
@onready var boss_rows_store: Node = %BossRowsStore
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var device_selection_container: PanelContainer = %DeviceSelectionContainer
@onready var container: GridContainer = %GridContainer
@onready var close_button: TextureButton = %CloseButton
@onready var delete_button: TextureButton = %DeleteButton


func _ready() -> void:
	# The icon assets are white so they can be tinted per surface; on this card
	# they would otherwise be invisible.
	close_button.self_modulate = Design.NAVY
	delete_button.self_modulate = Design.NAVY
	name_line_edit.connect("text_submitted", _on_name_changed)
	device_selection_container.hide()


## Builds the lesson rows ahead of any student being chosen.
##
## The rows are the expensive part: a lesson is six controls, four of them
## dropdowns that populate themselves, so sixty lessons cost about two seconds.
## They depend only on the language pack, so settings calls this while it is
## already loading and opening a student stays instant.
func prepare_lesson_rows() -> void:
	if not Database.is_open:
		Log.trace("LessonUnlocks: Database closed, lesson rows will be built on first use")
		return
	var lessons: Array = _query_lessons()
	if lesson_rows_store.get_child_count() != lessons.size():
		_build_lesson_rows(lessons)


func _query_lessons() -> Array:
	Database.db.query("SELECT LessonNb, group_concat(Grapheme || '-' || Phoneme, ' ') GPs FROM Lessons
INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
GROUP BY LessonNb
ORDER BY LessonNb")
	return Database.db.query_result


func _create_lessons() -> void:
	if not progression:
		Log.trace("LessonUnlocks: User selected a student with no progression data")
		return

	var lessons: Array = _query_lessons()
	if lesson_rows_store.get_child_count() != lessons.size():
		_build_lesson_rows(lessons)
	_apply_progression()


func _build_lesson_rows(lessons: Array) -> void:
	_clear_lessons_grid()
	# Worked out once for the table rather than per row: which garden a lesson falls
	# in depends on how many lessons the pack has, which is the same for all of them.
	var distribution: Array[int] = Gardens.compute_lessons_distribution(lessons.size())
	# The bosses stand between the gardens, so a row goes in after the lesson each one
	# closes -- the same place the child meets it on the map.
	var gate_lessons: Array[int] = StudentProgression.get_boss_gate_lessons()
	var last_lesson_number: int = 0
	var last_garden_index: int = -1
	for element: Dictionary in lessons:
		var student_unlock: LessonUnlock = LESSON_UNLOCK_SCENE.instantiate()
		var lesson_number: int = element.LessonNb
		var garden_index: int = Gardens.garden_index_for_lesson(lesson_number, distribution)
		student_unlock.lesson_gps = element.GPs
		student_unlock.lesson_number = lesson_number
		student_unlock.garden_index = garden_index
		student_unlock.unlocks = progression.unlocks if progression else {}
		lesson_rows_store.add_child(student_unlock)
		# Refill rather than rebuild: a teacher changing one dropdown used to pay
		# for the whole grid again.
		student_unlock.unlocks_changed.connect(_on_row_edited)
		_add_row_to_grid(student_unlock)
		if gate_lessons.has(lesson_number):
			_build_boss_row(lesson_number, garden_index, false)
		last_lesson_number = lesson_number
		last_garden_index = garden_index
	# And the final boss after all of them, which is where the treasure sits.
	if last_lesson_number > 0:
		_build_boss_row(last_lesson_number, last_garden_index, true)


func _build_boss_row(gate_lesson: int, garden_index: int, is_final: bool) -> void:
	var boss_unlock: BossUnlock = BOSS_UNLOCK_SCENE.instantiate()
	boss_unlock.gate_lesson = gate_lesson
	boss_unlock.garden_index = garden_index
	boss_unlock.is_final = is_final
	boss_unlock.progression = progression
	boss_rows_store.add_child(boss_unlock)
	boss_unlock.unlocks_changed.connect(_on_row_edited)
	_add_row_to_grid(boss_unlock)


## Refreshes the table after a teacher edit.
##
## Any edit can move a boss: finishing a garden opens its boss, and pulling a lesson
## back closes the ones behind it, so the recorded victories are put back in step
## before the rows are read again.
func _on_row_edited() -> void:
	if progression:
		progression.derive_boss_progression()
	_apply_progression()


## Points every row at the current student's progression and refreshes it.
func _apply_progression() -> void:
	if not progression:
		return
	for row: LessonUnlock in lesson_rows_store.get_children():
		row.unlocks = progression.unlocks
		row.reload()
	for boss_row: BossUnlock in boss_rows_store.get_children():
		boss_row.progression = progression
		boss_row.reload()


func _clear_lessons_grid() -> void:
	# Freed rather than queued: a rebuild in the same frame would otherwise add
	# its rows alongside the old ones, and the grid doubled on every open.
	for child: Node in lessons_grid.get_children():
		if child.get_meta("lesson_grid_cell", false):
			lessons_grid.remove_child(child)
			child.free()
	for store: Node in [lesson_rows_store, boss_rows_store]:
		for child: Node in store.get_children():
			store.remove_child(child)
			child.free()


func _add_row_to_grid(row: Node) -> void:
	@warning_ignore("UNSAFE_METHOD_ACCESS")
	for cell: Control in row.get_grid_cells():
		cell.set_meta("lesson_grid_cell", true)
		cell.reparent(lessons_grid)


func _on_device_changed(value: int)-> void:
	device = value


func _on_student_changed(value: int)-> void:
	student = value
	progression = UserDataManager.get_student_progression_for_code(device, student)
	if progression:
		_unlocks_on_open = progression.unlocks.duplicate(true)
		_highest_boss_on_open = progression.highest_boss_defeated
	else:
		_unlocks_on_open = {}
		_highest_boss_on_open = 0
	_create_lessons()
	(%PasswordVisualizer as PasswordVisualizer).password = str(value)
	Log.info("LessonUnlocks: Loaded student %d for device %d" % [student, device])
	var all_students: Array = UserDataManager.teacher_settings.students[device]
	for student_data: StudentData in all_students:
		if student_data.code == value:
			name_line_edit.text = student_data.name
			break


func _on_back_button_pressed() -> void:
	if not progression:
		hide()
		return
	# Only touch the timestamp when the teacher actually changed something. Note
	# that lowering the progression is a legitimate edit: it is saved and pushed
	# like any other, because the timestamp genuinely moves forward.
	if progression.unlocks == _unlocks_on_open and progression.highest_boss_defeated == _highest_boss_on_open:
		Log.trace("LessonUnlocks: Progression unchanged for student %d on device %d, nothing to save" % [student, device])
		hide()
		return
	progression.last_modified = Time.get_datetime_string_from_system(true)
	UserDataManager.save_student_progression_for_code(device, student, progression)
	Log.info("LessonUnlocks: Saved progression for student %d on device %d" % [student, device])
	_unlocks_on_open = progression.unlocks.duplicate(true)
	_highest_boss_on_open = progression.highest_boss_defeated
	hide()


func _on_delete_button_pressed() -> void:
	Log.warn("LessonUnlocks: Delete requested for student %d on device %d" % [student, device])
	student_deleted.emit(int(student))


func _on_device_change_button_pressed() -> void:
	Log.trace("LessonUnlocks: Device change requested for student %d" % student)
	_device_selection_refresh()
	device_selection_container.show()


func _on_name_changed(new_name: String) -> void:
	UserDataManager.teacher_settings.update_student_name(student, new_name)
	teacher_settings.update_student_name(student, new_name)
	Log.info("LessonUnlocks: Updated student %d name to %s" % [student, new_name])


func _device_selection_refresh() -> void:
	if not UserDataManager.teacher_settings:
		return
	
	for child: Node in container.get_children():
		child.queue_free()
	
	for device_id: int in UserDataManager.teacher_settings.students.keys():
		var button: DeviceButton = DEVICE_BUTTON_SCENE.instantiate()
		button.number = device_id
		button.background_color = Globals.device_colors[(device_id - 1) % Globals.device_colors.size()]
		container.add_child(button)
		button.pressed.connect(_device_button_pressed.bind(device_id))


func _device_button_pressed(device_id: int) -> void:
	device_selection_container.hide()
	UserDataManager.teacher_settings.update_student_device(student, device_id)
	teacher_settings.refresh_devices()
	device = device_id
	Log.info("LessonUnlocks: Updated student %d to device %d" % [student, device_id])
	var res_set: Dictionary = await ServerManager.set_student_data(student, {"device_id": device_id})
	if not res_set.success:
		Log.trace("LessonUnlocks: Device was updated locally for the student, but the network update failed.")

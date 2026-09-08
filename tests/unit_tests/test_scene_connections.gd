extends GutTest
## The signals a scene authors have to still be there.
##
## A dropped `[connection]` line is the quietest breakage in the project. The
## control still draws, still highlights, still reports itself as the node under
## the cursor -- the click arrives and simply lands on nobody. Nothing errors, and
## no other test noticed: asserting that a click *reaches* a control says nothing
## about whether anything is listening.
##
## It happened for real. A script that removed the cloud sprites from gardens.tscn
## split the file into node blocks and dropped the last one, and the trailing
## `[connection]` lines belong to no node -- so all eight went with it. The gardens'
## lesson buttons are wired in code and kept working, which made it look like a
## click-blocking problem for three rounds: the wheel opened, and then the wheel,
## the look-and-learn button, the back, brain and Kalulu buttons were all inert.

## The connections the gardens cannot work without, as (node path, signal, method).
const GARDENS_SCENE: String = "res://sources/gardens/gardens.tscn"
const GARDENS_CONNECTIONS: Array[Array] = [
	["ScrollContainer", "gui_input", "_on_scroll_container_gui_input"],
	["CanvasLayer/MinigameSelection/BackgroundRect", "gui_input", "_on_background_rect_gui_input"],
	["CanvasLayer/MinigameSelection/LessonButton", "pressed", "_on_lesson_button_pressed"],
	["CanvasLayer/BackButton", "button_down", "_on_back_button_button_down"],
	["CanvasLayer/BackButton", "button_up", "_on_back_button_button_up"],
	["CanvasLayer/BrainButton", "pressed", "_on_brain_button_pressed"],
	["CanvasLayer/KaluluButton", "pressed", "_on_kalulu_button_pressed"],
	["CanvasLayer/Area2D", "input_event", "_on_area_2d_input_event"],
]
## Where to sweep for connections that point at nothing.
const SCENE_DIRECTORIES: Array[String] = ["res://sources", "res://resources"]
## Connections that were already dangling before this test existed, as
## "<scene>::<method>". Every one is a handler that was renamed or removed with the
## `[connection]` line left behind, so the signal fires into nothing:
##
##   water_ring / highlight   the FX never learn their particles or animation ended
##   the two Prof Tool lists  their plus button does nothing
##
## Listed rather than quietly skipped: they are real, they are somebody's next
## small fix, and the sweep stays strict for anything new.
const KNOWN_DANGLING: Array[String] = [
	"res://sources/utils/fx/water_ring.tscn::_on_gpu_particles_2d_finished",
	"res://sources/utils/fx/highlight.tscn::_on_animation_player_animation_finished",
	"res://sources/language_tool/gp_image_and_sound_descriptions.tscn::_on_plus_button_pressed",
	"res://sources/language_tool/gp_video_descriptions.tscn::_on_plus_button_pressed",
]


func test_the_gardens_still_listen_to_everything_they_wire_up() -> void:
	var gardens: Node = (load(GARDENS_SCENE) as PackedScene).instantiate()
	autofree(gardens)

	for wiring: Array in GARDENS_CONNECTIONS:
		var node: Node = gardens.get_node_or_null(wiring[0] as String)
		assert_not_null(node, "%s should be in the scene" % wiring[0])
		if not node:
			continue
		assert_true(node.is_connected(wiring[1] as String, Callable(gardens, wiring[2] as String)),
			"%s.%s should reach %s -- a click that lands on nobody looks like a blocked click"
				% [wiring[0], wiring[1], wiring[2]])


func test_no_scene_wires_a_signal_to_a_method_that_is_not_there() -> void:
	# The other half: a connection that survived but points at a renamed handler is
	# just as silent. Read out of the scene files, so nothing has to be built.
	var checked: int = 0
	for scene_path: String in _every_scene():
		var scene: PackedScene = load(scene_path) as PackedScene
		if not scene:
			continue
		var state: SceneState = scene.get_state()
		for index: int in state.get_connection_count():
			var target: Node = null
			var script: Script = _script_for(state, state.get_connection_target(index))
			if not script:
				continue
			var method: StringName = state.get_connection_method(index)
			if "%s::%s" % [scene_path, method] in KNOWN_DANGLING:
				continue
			checked += 1
			assert_true(_has_method(script, method),
				"%s wires %s to %s, which does not exist" % [scene_path,
					state.get_connection_signal(index), method])
			target = null
	assert_gt(checked, 0, "the sweep should have found some connections to check")


## The script a connection's target node carries, or null when the scene does not
## say (an inherited or instanced target, whose script lives in another file).
func _script_for(state: SceneState, target: NodePath) -> Script:
	var wanted: String = str(target)
	for index: int in state.get_node_count():
		if str(state.get_node_path(index)) != wanted:
			continue
		for property: int in state.get_node_property_count(index):
			if state.get_node_property_name(index, property) == "script":
				return state.get_node_property_value(index, property) as Script
		return null
	return null


func _has_method(script: Script, method: StringName) -> bool:
	var current: Script = script
	while current:
		for entry: Dictionary in current.get_script_method_list():
			if entry.get("name", "") == method:
				return true
		current = current.get_base_script()
	return false


func _every_scene() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for directory: String in SCENE_DIRECTORIES:
		_collect_scenes(directory, found)
	return found


func _collect_scenes(directory: String, found: PackedStringArray) -> void:
	for entry: String in DirAccess.get_directories_at(directory):
		_collect_scenes(directory.path_join(entry), found)
	for entry: String in DirAccess.get_files_at(directory):
		if entry.ends_with(".tscn"):
			found.append(directory.path_join(entry))


## And the wiring does what it is for: a tap outside the wheel closes it.
##
## The behaviour the dropped connection actually cost, driven through real input
## rather than by calling the handler -- which is the mistake that let this hide.
## Opening the wheel goes through a connection made in code and kept working all
## along; closing it goes through the one that was missing.
func test_a_tap_outside_the_wheel_closes_it() -> void:
	if not Database.is_open:
		pending("needs an installed language pack")
		return
	var student_on_open: String = UserDataManager.student
	if not UserDataManager.student_progression:
		UserDataManager.student = str(_any_student_code())
	if not UserDataManager.student_progression:
		pending("needs a registered student")
		return
	# Past the intro speeches, which would otherwise be over the gardens.
	var speeches_on_open: Array[String] = []
	if UserDataManager._student_speeches:
		speeches_on_open = (UserDataManager._student_speeches.speeches_played as Array[String]).duplicate()
		UserDataManager._student_speeches.speeches_played = ["brain", "gardens"] as Array[String]
	Gardens.transition_data = {}
	get_tree().paused = false
	var gardens: Gardens = (load(GARDENS_SCENE) as PackedScene).instantiate()
	add_child(gardens)
	for _frame: int in 240:
		await get_tree().process_frame
	var lesson: int = UserDataManager.student_progression.get_max_unlocked_lesson_index() + 1
	var button: LessonButton = gardens._get_current_lesson_button(lesson)
	assert_not_null(button, "the student should have a lesson to open")
	if button:
		_tap(gardens.get_viewport(), button.get_global_rect().get_center())
		for _frame: int in 90:
			await get_tree().process_frame
		assert_true(gardens.in_minigame_selection, "tapping a lesson opens the wheel")

		_tap(gardens.get_viewport(), Vector2(150.0, 150.0))
		for _frame: int in 120:
			await get_tree().process_frame
			if not gardens.in_minigame_selection:
				break
		assert_false(gardens.in_minigame_selection, "and tapping outside it closes it again")

	gardens.free()
	if UserDataManager._student_speeches:
		UserDataManager._student_speeches.speeches_played = speeches_on_open
	UserDataManager.student = student_on_open
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func _tap(viewport: Viewport, point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var tap: InputEventMouseButton = InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.position = point
		tap.pressed = pressed
		# Local coordinates: a headless window is 64x64, and the canvas transform
		# would otherwise put the tap somewhere else entirely.
		viewport.push_input(tap, true)


func _any_student_code() -> int:
	var settings: TeacherSettings = UserDataManager.teacher_settings
	if not settings:
		return 0
	for device: int in settings.students.keys():
		for student: StudentData in settings.students[device]:
			return student.code
	return 0

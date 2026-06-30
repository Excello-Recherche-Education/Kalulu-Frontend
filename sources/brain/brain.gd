extends Control

const GARDENS_SCENE_PATH: String = "res://sources/gardens/gardens.tscn"
const BOSS_BUTTON_SCENE: PackedScene = preload("res://sources/gardens/boss_button.tscn")
# Path-trace styling. The gardens screen uses width 20 (locked) / 50 (unlocked) over
# full-size 240 px buttons; the brain shows the gardens at ~0.2 scale, so the lines are
# scaled down to stay proportionate. Colors match the gardens screen. Tune in-editor.
const LOCKED_LINE_WIDTH: float = 6.0
const UNLOCKED_LINE_WIDTH: float = 12.0
const LOCKED_LINE_COLOR: Color = Color(0.356863, 0.356863, 0.356863)
const UNLOCKED_LINE_COLOR: Color = Color.WHITE
# Boss buttons are authored at 512 px; the gardens show them at ~0.2 scale, and the
# brain shows them 20% smaller again so they sit better between the small gardens.
const BOSS_BUTTON_BASE_SIZE: float = 512.0
const BOSS_BUTTON_SCALE: float = 0.16

# Lesson grapheme data keyed by lesson number (1-based), same shape as Gardens.lessons.
var lessons: Dictionary = {}
# How many lessons each garden hosts, from Gardens.compute_lessons_distribution().
var lesson_distribution: Array[int] = []
# The embedded garden scenes (GardenRoot01..GardenRoot12), in display order.
var gardens: Array[Garden] = []
# Lesson-button centres in Brain-local space, in lesson order (1..N). Drives the
# path-trace and the boss-button placement between gardens.
var lesson_centers: Array[Vector2] = []
# Path/boss nodes, created in code so their geometry lives in Brain-local space.
var locked_line: Line2D
var unlocked_line: Line2D
var boss_buttons_container: Control

@onready var progress_label: Label = %ProgressLabel
@onready var brain_map: TextureRect = $Brain


func _ready() -> void:
	_update_progress_label()
	_collect_gardens()
	_load_lessons_from_database()
	_configure_gardens()
	_apply_progression_to_gardens()
	_create_path_nodes()
	# Let the layout settle so button global transforms are final before reading them.
	await get_tree().process_frame
	_build_progression_path()
	_set_up_boss_buttons()
	await (OpeningCurtain as OpeningCurtainClass).open()


func _update_progress_label() -> void:
	var player_name: String = UserDataManager.get_current_student_name()
	var progress_text: String
	if player_name.is_empty():
		progress_text = tr("BRAIN_PLAYER_PROGRESS_NO_NAME")
	else:
		progress_text = tr("BRAIN_PLAYER_PROGRESS").format({"name": player_name})

	progress_label.text = progress_text


# Collects the embedded garden scenes in tree order, which matches the lesson
# ordering used by the gardens screen (garden 1 first, then 2, ...).
func _collect_gardens() -> void:
	gardens.clear()
	for child: Node in brain_map.get_children():
		if child is Garden:
			gardens.append(child as Garden)


# Same query and grouping the gardens screen uses: one entry per lesson number,
# each a list of its grapheme-phoneme pairs.
func _load_lessons_from_database() -> void:
	Database.db.query("SELECT Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		ORDER BY LessonNb")
	for element: Dictionary in Database.db.query_result:
		if not lessons.has(element.LessonNb):
			lessons[element.LessonNb] = []
		var lesson_content: Array = lessons[element.LessonNb]
		lesson_content.append({grapheme = element.Grapheme, phoneme = element.Phoneme, gp_id = element.GPID})


# Distributes the lessons across gardens with Gardens.compute_lessons_distribution()
# (front-loaded ceiling division, e.g. 37 lessons → 4 in the first garden, 3 in each
# of the 11 others), then hands each garden its count through Garden.set_garden_layout().
# That runs Garden._configure_slots(), which uses Garden.SLOT_SELECTION to pick WHICH
# of the 5 fixed slots are shown (3 lessons → slots 0, 2, 4 — not 0, 1, 2) and hides
# the rest, so the brain map shows the exact same buttons as the playable garden
# screen. No button or victory-asset position is ever modified.
func _configure_gardens() -> void:
	var capacity_layouts: Array[GardenLayout] = []
	for garden: Garden in gardens:
		var capacity_layout: GardenLayout = GardenLayout.new()
		capacity_layout.lesson_buttons.resize(garden.all_slots.size())
		capacity_layouts.append(capacity_layout)
	lesson_distribution = Gardens.compute_lessons_distribution(lessons.size(), capacity_layouts)
	for garden_index: int in range(gardens.size()):
		var garden: Garden = gardens[garden_index]
		garden.garden_index = garden_index
		var lesson_count: int = lesson_distribution[garden_index] if garden_index < lesson_distribution.size() else 0
		var garden_layout: GardenLayout = GardenLayout.new()
		# color drives Garden.set_background(); garden N keeps its own garden_NN.png.
		garden_layout.color = garden_index
		garden_layout.lesson_buttons.resize(lesson_count)
		garden.garden_layout = garden_layout


# Fills each active button with its lesson grapheme and applies the player's
# progression (locked / unlocked / completed). The single unlocked-but-not-completed
# button keeps its golden border, marking the current progression point. Victory
# assets are then revealed proportionally to completed minigames. Mirrors
# Gardens._set_up_lessons() + Gardens._apply_progression_to_gardens(), minus the
# transition/unlock animations (the brain is a static overview).
func _apply_progression_to_gardens() -> void:
	var progression: StudentProgression = UserDataManager.student_progression
	if not progression:
		Log.error("Brain: No data for student progression")
	var lesson_number: int = 1
	for garden: Garden in gardens:
		var lesson_buttons: Array[LessonButton] = garden.get_lesson_buttons()
		var total_minigames: int = 0
		var completed_minigames_total: int = 0
		for index: int in range(lesson_buttons.size()):
			if not lesson_number in lessons:
				break
			var button: LessonButton = lesson_buttons[index]
			button.text = lessons[lesson_number][0].grapheme as String
			if progression:
				var lesson_unlocks: Dictionary = progression.unlocks[lesson_number]
				var is_blocked_by_boss: bool = progression.is_lesson_blocked_by_boss(lesson_number)
				var is_lesson_unlocked: bool = lesson_unlocks["look_and_learn"] != StudentProgression.Status.LOCKED and not is_blocked_by_boss
				button.set_button_disabled(not is_lesson_unlocked)
				button.completed = progression.is_lesson_completed(lesson_number) and not is_blocked_by_boss
				if not is_blocked_by_boss:
					completed_minigames_total += _count_completed_minigames(lesson_number)
					total_minigames += (lesson_unlocks["games"] as Array).size()
			lesson_number += 1
		if progression:
			garden.current_progression = float(completed_minigames_total)
			garden.max_progression = float(total_minigames)
			garden.update_victory_assets_visibility(completed_minigames_total, total_minigames)


func _count_completed_minigames(lesson_number: int) -> int:
	var progression: StudentProgression = UserDataManager.student_progression
	if not progression or not progression.unlocks.has(lesson_number):
		return 0
	var completed: int = 0
	for game_status: int in progression.unlocks[lesson_number]["games"]:
		if game_status == StudentProgression.Status.COMPLETED:
			completed += 1
	return completed


#region Path-trace and boss buttons

# Creates the two path Line2Ds and the boss-button container as children of the Brain
# map, so their points/positions live in Brain-local space. They are slotted right
# after the gardens in the tree: drawn above the garden backgrounds but below the
# lesson buttons (z 1) and boss buttons (z 2), mirroring the gardens screen's layering.
func _create_path_nodes() -> void:
	locked_line = _make_path_line(LOCKED_LINE_WIDTH, LOCKED_LINE_COLOR)
	unlocked_line = _make_path_line(UNLOCKED_LINE_WIDTH, UNLOCKED_LINE_COLOR)
	boss_buttons_container = Control.new()
	boss_buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brain_map.add_child(locked_line)
	brain_map.add_child(unlocked_line)
	brain_map.add_child(boss_buttons_container)
	if not gardens.is_empty():
		var after_gardens: int = gardens[gardens.size() - 1].get_index() + 1
		brain_map.move_child(locked_line, after_gardens)
		brain_map.move_child(unlocked_line, after_gardens + 1)
		brain_map.move_child(boss_buttons_container, after_gardens + 2)


func _make_path_line(width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line


# Traces the lesson path like the gardens screen: a full grey curve through every
# lesson button (locked_line) plus a white curve over the portion the player has
# already reached (unlocked_line, up to the current progression — which naturally
# stops before any undefeated boss gate).
func _build_progression_path() -> void:
	lesson_centers = _collect_lesson_centers()
	if lesson_centers.size() < 2:
		return
	locked_line.points = _build_smooth_curve(lesson_centers, lesson_centers.size()).get_baked_points()
	unlocked_line.clear_points()
	var progression: StudentProgression = UserDataManager.student_progression
	if not progression:
		return
	var unlocked_count: int = clampi(progression.get_max_unlocked_lesson_index() + 1, 0, lesson_centers.size())
	if unlocked_count >= 2:
		unlocked_line.points = _build_smooth_curve(lesson_centers, unlocked_count).get_baked_points()


# Centre of every active lesson button, in lesson order, expressed in Brain-local
# space (the gardens are scaled children, so we go through global transforms).
func _collect_lesson_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var brain_inverse: Transform2D = brain_map.get_global_transform().affine_inverse()
	for garden: Garden in gardens:
		for button: LessonButton in garden.get_lesson_buttons():
			var global_center: Vector2 = button.get_global_transform() * (button.size * 0.5)
			centers.append(brain_inverse * global_center)
	return centers


# Smooth Curve2D through the first `count` centres, each control point's tangents set
# to half the vector to its neighbours (a Catmull-Rom-like fit).
func _build_smooth_curve(centers: Array[Vector2], count: int) -> Curve2D:
	var curve: Curve2D = Curve2D.new()
	var point_count: int = mini(count, centers.size())
	for index: int in range(point_count):
		var point: Vector2 = centers[index]
		var point_in: Vector2 = (centers[index - 1] - point) * 0.5 if index > 0 else Vector2.ZERO
		var point_out: Vector2 = (centers[index + 1] - point) * 0.5 if index < point_count - 1 else Vector2.ZERO
		curve.add_point(point, point_in, point_out)
	return curve


# Places a boss button between two gardens for each boss gate the pack actually uses
# (StudentProgression.get_boss_gate_lessons() — only garden boundaries with enough
# pseudowords). Same locked / unlocked / completed states as the gardens screen.
# Bosses are non-interactive here: the brain is an overview.
func _set_up_boss_buttons() -> void:
	for child: Node in boss_buttons_container.get_children():
		child.queue_free()
	var total_lessons: int = lessons.size()
	if total_lessons <= 0 or lesson_centers.size() < total_lessons:
		return
	var progression: StudentProgression = UserDataManager.student_progression
	for gate_lesson: int in StudentProgression.get_boss_gate_lessons():
		if gate_lesson <= 0 or gate_lesson >= total_lessons:
			continue
		# Midway between the gate's last lesson and the first lesson of the next garden.
		var center: Vector2 = (lesson_centers[gate_lesson - 1] + lesson_centers[gate_lesson]) * 0.5
		var boss: BossButton = BOSS_BUTTON_SCENE.instantiate()
		boss_buttons_container.add_child(boss)
		boss.size = Vector2(BOSS_BUTTON_BASE_SIZE, BOSS_BUTTON_BASE_SIZE)
		boss.pivot_offset = boss.size * 0.5
		boss.scale = Vector2(BOSS_BUTTON_SCALE, BOSS_BUTTON_SCALE)
		boss.position = center - boss.size * 0.5
		if progression:
			var is_completed: bool = progression.is_boss_completed(gate_lesson)
			var is_blocked_by_boss: bool = progression.is_lesson_blocked_by_boss(gate_lesson)
			var is_unlocked: bool = progression.is_lesson_completed(gate_lesson) and not is_blocked_by_boss
			boss.set_button_disabled(not is_unlocked and not is_completed)
			boss.completed = is_completed
		else:
			boss.set_button_disabled(true)

#endregion


func _on_back_button_pressed() -> void:
	await (OpeningCurtain as OpeningCurtainClass).close()
	SceneLoader.change_scene(GARDENS_SCENE_PATH)

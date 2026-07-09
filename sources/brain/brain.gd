class_name Brain
extends Control

# Set by base_minigame.gd right before navigating here after a final-boss win, so
# _ready() knows to auto-play the reward animation once. Mirrors Gardens/Minigame.
static var transition_data: Dictionary = {}

const GARDENS_SCENE_PATH: String = "res://sources/gardens/gardens.tscn"
const BOSS_BUTTON_SCENE: PackedScene = preload("res://sources/gardens/boss_button.tscn")
# Boss buttons are authored at 512 px; the gardens show them at ~0.2 scale, and the
# brain shows them 20% smaller again so they sit better between the small gardens.
const BOSS_BUTTON_BASE_SIZE: float = 512.0
const BOSS_BUTTON_SCALE: float = 0.16
# The treasure stands in for the final boss: it opens once the final boss has
# actually been beaten.
const TREASURE_CLOSED_TEXTURE: Texture2D = preload("res://assets/brain/treasure_closed.png")
const TREASURE_OPENED_TEXTURE: Texture2D = preload("res://assets/brain/treasure_opened.png")

# Lesson grapheme data keyed by lesson number (1-based), same shape as Gardens.lessons.
var lessons: Dictionary = {}
# How many lessons each garden hosts, from Gardens.compute_lessons_distribution().
var lesson_distribution: Array[int] = []
# The embedded garden scenes (GardenRoot01..GardenRoot12), in display order.
var gardens: Array[Garden] = []
# Lesson-button centres in Brain-local space, in lesson order (1..N). Drives the
# boss-button placement between gardens.
var lesson_centers: Array[Vector2] = []
# Boss-button container, created in code so its geometry lives in Brain-local space.
var boss_buttons_container: Control

@onready var progress_label: Label = %ProgressLabel
@onready var brain_map: TextureRect = $Brain
@onready var treasure: TextureRect = $Brain/Treasure
@onready var treasure_button: Button = $Brain/Treasure/TreasureButton
@onready var reward: BrainReward = $Reward
@onready var ui_layer: CanvasLayer = $CanvasLayer


func _ready() -> void:
	_update_progress_label()
	_collect_gardens()
	_load_lessons_from_database()
	_configure_gardens()
	_apply_progression_to_gardens()
	_create_boss_buttons_container()
	# Let the layout settle so button global transforms are final before reading them.
	await get_tree().process_frame
	lesson_centers = _collect_lesson_centers()
	_set_up_boss_buttons()
	_update_treasure()
	reward.setup(brain_map, treasure, gardens, ui_layer)
	treasure_button.pressed.connect(_on_treasure_button_pressed)
	await (OpeningCurtain as OpeningCurtainClass).open()
	# Auto-play the reward once when arriving straight from a final-boss win.
	if transition_data.get("final_boss_just_beaten", false):
		transition_data = {}
		reward.play(true)


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
# of the 11 others), then hands each garden its count through Garden.set_lesson_count().
# That runs Garden._configure_slots(), which uses Garden.SLOT_SELECTION to pick WHICH
# of the 5 fixed slots are shown (3 lessons → slots 0, 2, 4 — not 0, 1, 2) and hides
# the rest, so the brain map shows the exact same buttons as the playable garden
# screen. No button or victory-asset position is ever modified.
func _configure_gardens() -> void:
	lesson_distribution = Gardens.compute_lessons_distribution(lessons.size())
	for garden_index: int in range(gardens.size()):
		var garden: Garden = gardens[garden_index]
		garden.garden_index = garden_index
		var lesson_count: int = lesson_distribution[garden_index] if garden_index < lesson_distribution.size() else 0
		garden.set_lesson_count(lesson_count)


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
		var has_unlocked_lesson: bool = false
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
				if is_lesson_unlocked:
					has_unlocked_lesson = true
				if not is_blocked_by_boss:
					completed_minigames_total += _count_completed_minigames(lesson_number)
					total_minigames += (lesson_unlocks["games"] as Array).size()
			lesson_number += 1
		if progression:
			garden.current_progression = float(completed_minigames_total)
			garden.max_progression = float(total_minigames)
			garden.update_victory_assets_visibility(completed_minigames_total, total_minigames)
			# Grey out gardens the player hasn't reached yet (no unlocked lesson).
			garden.set_greyed_out(not has_unlocked_lesson)


func _count_completed_minigames(lesson_number: int) -> int:
	var progression: StudentProgression = UserDataManager.student_progression
	if not progression or not progression.unlocks.has(lesson_number):
		return 0
	var completed: int = 0
	for game_status: int in progression.unlocks[lesson_number]["games"]:
		if game_status == StudentProgression.Status.COMPLETED:
			completed += 1
	return completed


#region Boss buttons and treasure

# Creates the boss-button container as a child of the Brain map, so its positions
# live in Brain-local space. It is slotted right after the gardens in the tree,
# mirroring the gardens screen's layering.
func _create_boss_buttons_container() -> void:
	boss_buttons_container = Control.new()
	boss_buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brain_map.add_child(boss_buttons_container)
	if not gardens.is_empty():
		var after_gardens: int = gardens[gardens.size() - 1].get_index() + 1
		brain_map.move_child(boss_buttons_container, after_gardens)


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


# Swaps the treasure texture: opened once the final boss has been beaten, closed
# otherwise (tracked via StudentProgression.highest_boss_defeated).
func _update_treasure() -> void:
	var progression: StudentProgression = UserDataManager.student_progression
	var final_done: bool = progression != null and progression.is_final_boss_completed()
	if final_done:
		treasure.texture = TREASURE_OPENED_TEXTURE
	else:
		treasure.texture = TREASURE_CLOSED_TEXTURE
	# The chest replays the reward, but only once it has been opened for real.
	treasure_button.disabled = not final_done

#endregion

func _on_treasure_button_pressed() -> void:
	reward.play(false)


func _on_back_button_pressed() -> void:
	await (OpeningCurtain as OpeningCurtainClass).close()
	SceneLoader.change_scene(GARDENS_SCENE_PATH)


func _on_treasure_button_button_up() -> void:
	reward.play(true)

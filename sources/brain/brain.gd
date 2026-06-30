extends Control

const GARDENS_SCENE_PATH: String = "res://sources/gardens/gardens.tscn"

# Lesson grapheme data keyed by lesson number (1-based), same shape as Gardens.lessons.
var lessons: Dictionary = {}
# How many lessons each garden hosts, from Gardens.compute_lessons_distribution().
var lesson_distribution: Array[int] = []
# The embedded garden scenes (GardenRoot01..GardenRoot12), in display order.
var gardens: Array[Garden] = []

@onready var progress_label: Label = %ProgressLabel
@onready var brain_map: TextureRect = $Brain


func _ready() -> void:
	_update_progress_label()
	_collect_gardens()
	_load_lessons_from_database()
	_configure_gardens()
	_apply_progression_to_gardens()
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


func _on_back_button_pressed() -> void:
	await (OpeningCurtain as OpeningCurtainClass).close()
	SceneLoader.change_scene(GARDENS_SCENE_PATH)

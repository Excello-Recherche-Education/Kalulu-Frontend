class_name Gardens
extends Control

signal minigame_layout_opened()

const KALULU: GDScript = preload("res://sources/minigames/base/kalulu_ingame.gd")
const GARDEN_SCENES: Array[PackedScene] = [
	preload("res://resources/gardens/garden_01.tscn"),
	preload("res://resources/gardens/garden_02.tscn"),
	preload("res://resources/gardens/garden_03.tscn"),
	preload("res://resources/gardens/garden_04.tscn"),
	preload("res://resources/gardens/garden_05.tscn"),
	preload("res://resources/gardens/garden_06.tscn"),
	preload("res://resources/gardens/garden_07.tscn"),
	preload("res://resources/gardens/garden_08.tscn"),
	preload("res://resources/gardens/garden_09.tscn"),
	preload("res://resources/gardens/garden_10.tscn"),
	preload("res://resources/gardens/garden_11.tscn"),
	preload("res://resources/gardens/garden_12.tscn"),
]
const LOOK_AND_LEARN_SCENE: PackedScene = preload("res://sources/look_and_learn/look_and_learn.tscn")
const BOSS_BUTTON_SCENE: PackedScene = preload("res://sources/gardens/boss_button.tscn")
const BOSS_MINIGAME_SCENE_PATH: String = "res://sources/minigames/boss/boss_minigame.tscn"
const GARDEN_SIZE: int = 2400
const GARDENS_COUNT: int = 12
const MIN_LESSONS: int = 12
const MAX_LESSONS: int = 60
const GARDEN_CENTER_Y: float = 900.0
const GARDEN_CIRCLE_RADIUS: float = 850.0
const FINAL_BOSS_PADDING: float = 120.0
const BACK_BUTTON_HOLD_DURATION_SECONDS: float = 1.0
const LAYOUT_VERSION: int = 14
# Centers of the 5 fixed button slots (must match garden_XX.tscn positions)
const SLOT_CENTERS: Array[Vector2i] = [
	Vector2i(704, 1186), Vector2i(987, 1000), Vector2i(1290, 920),
	Vector2i(1565, 748), Vector2i(1864, 598)
]

static var transition_data: Dictionary = {}
static var cached_gardens_layout: GardensLayout
static var cached_layout_session_id: int = -1
static var cached_layout_lessons: int = 0

@export_category("Layout")
@export var gardens_layout: GardensLayout:
	set(value):
		set_gardens_layout(value)
	get:
		return _gardens_layout
@export var starting_garden: int = -1
@export_category("Colors")
@export var unlocked_color: Color = Color("1c2662")
@export var locked_color: Color = Color("1d2229")
@export_group("Minigames")
@export var minigame_scene_paths: PackedStringArray = PackedStringArray()
@export var minigames_icons: Array[Texture] = []

var _minigame_scene_cache: Dictionary = {}
var lessons: Dictionary = {}
var _gardens_layout: GardensLayout
var points: Array[Array] = []
var lesson_distribution: Array[int] = []
var is_scrolling: bool = false
var scroll_beginning_garden: int = 0
var is_locked: bool = false
var in_minigame_selection: bool = false
var current_lesson_number: int = -1
var current_garden: Garden
var current_button_global_position: Vector2 = Vector2.ZERO
var current_button: LessonButton
var scroll_end_base_width: float = 0.0
var back_button_hold_progress_seconds: float = 0.0
var is_back_button_hold_active: bool = false

@onready var garden_parent: HBoxContainer = %GardenParent
@onready var locked_line: Line2D = $LockedLine
@onready var unlocked_line: Line2D = $UnlockedLine
@onready var line_particles: GPUParticles2D = %LineParticles
@onready var line_audio_stream_player: AudioStreamPlayer2D = %LineAudioStreamPlayer
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var parallax_background: ParallaxBackground = %ParallaxBackground
@onready var clouds: CloudManager = %Clouds
@onready var scroll_end_spacer: Control = $"ScrollContainer/HBoxContainer/Control2"
@onready var boss_buttons_container: Control = %BossButtons
@onready var minigame_selection: Control = %MinigameSelection
@onready var lesson_button: LessonButton = %LessonButton
@onready var lesson_button_particles: GPUParticles2D = %LessonButtonParticles
@onready var back_button: BackButton = %BackButton
@onready var right_audio_stream_player: AudioStreamPlayer = $RightAudioStreamPlayer
@onready var left_audio_stream_player: AudioStreamPlayer = $LeftAudioStreamPlayer
@onready var feedback_audio_stream_player: AudioStreamPlayer = $FeedBackAudioStreamPlayer
@onready var feedback_audio_stream_player2: AudioStreamPlayer = $FeedBackAudioStreamPlayer2
@onready var minigame_layout_1: MinigameLayout = %MinigameBackground1
@onready var minigame_layout_2: MinigameLayout = %MinigameBackground2
@onready var minigame_layout_3: MinigameLayout = %MinigameBackground3
@onready var minigame_background: TextureRect = %MinigameBackground
@onready var minigame_background_center: TextureRect = %MinigameBackgroundCenter
@onready var lock: Control = %Lock
@onready var kalulu: KALULU = %Kalulu
@onready var kalulu_button: CanvasItem = %KaluluButton
# TODO: Rename / Move those audio inside the language packs to remove all references to brain_screen which does not exists anymore
@onready var brain_tutorial_speeches: Array[AudioStream] = [
	Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "intro_1")),
	Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "intro_2")),
	Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "intro_3"))
]
@onready var intro_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "intro"))
@onready var help_few_plants_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "help_few_plants"))
@onready var help_many_plants_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "help_many_plants"))


func _init() -> void:
	Log.trace("Gardens: _init()")


func _enter_tree() -> void:
	Log.trace("Gardens: _enter_tree()")

#region Data loading and progression

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


func _build_transition_context() -> Dictionary:
	var max_unlocked_lesson_index: int = UserDataManager.student_progression.get_max_unlocked_lesson_index()
	var max_unlocked_lesson_number: int = max_unlocked_lesson_index + 1
	var minigame_number: int = transition_data.get("minigame_number", -1) as int
	var is_current_lesson: bool = transition_data and transition_data.current_lesson_number == max_unlocked_lesson_index + 1
	var is_minigame_completed: bool = transition_data.has("minigame_completed") and transition_data.minigame_completed
	var is_first_clear: bool = transition_data and transition_data.has("first_clear") and transition_data.first_clear
	var new_lesson_unlocked: bool = transition_data and transition_data.current_lesson_number == max_unlocked_lesson_index and is_minigame_completed and is_first_clear and UserDataManager.student_progression.is_lesson_completed(transition_data.current_lesson_number as int)
	var newly_unlocked_lesson_number: int = -1
	if new_lesson_unlocked:
		newly_unlocked_lesson_number = max_unlocked_lesson_number
	var pending_boss_gate_lesson: int = -1
	if transition_data and transition_data.has("current_lesson_number"):
		var current_transition_lesson_number: int = transition_data.current_lesson_number as int
		var is_boss_gate: bool = StudentProgression.get_boss_gate_lessons().has(current_transition_lesson_number)
		if is_boss_gate and is_minigame_completed and is_first_clear and UserDataManager.student_progression.is_lesson_completed(current_transition_lesson_number):
			if not UserDataManager.student_progression.is_boss_completed(current_transition_lesson_number):
				pending_boss_gate_lesson = current_transition_lesson_number
	var most_advanced_unlocked_lesson_index: int = max_unlocked_lesson_index
	if new_lesson_unlocked:
		most_advanced_unlocked_lesson_index -= 1
	return {
		max_unlocked_lesson_index = max_unlocked_lesson_index,
		max_unlocked_lesson_number = max_unlocked_lesson_number,
		is_current_lesson = is_current_lesson,
		is_minigame_completed = is_minigame_completed,
		is_first_clear = is_first_clear,
		new_lesson_unlocked = new_lesson_unlocked,
		newly_unlocked_lesson_number = newly_unlocked_lesson_number,
		pending_boss_gate_lesson = pending_boss_gate_lesson,
		most_advanced_unlocked_lesson_index = most_advanced_unlocked_lesson_index,
		last_played_minigame_number = minigame_number
	}


func _apply_progression_to_gardens(transition_context: Dictionary) -> void:
	var lesson_index: int = 1
	for garden_control: Garden in garden_parent.get_children():
		var total_minigames: int = 0
		var completed_minigames_total: int = 0
		var lesson_buttons: Array[LessonButton] = garden_control.get_lesson_buttons()
		for button_index: int in range(lesson_buttons.size()):
			var button: LessonButton = lesson_buttons[button_index]
			if not lesson_index in lessons:
				button.set_button_disabled(true)
				continue

			var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[lesson_index]
			var is_blocked_by_boss: bool = UserDataManager.student_progression.is_lesson_blocked_by_boss(lesson_index)
			var is_lesson_unlocked: bool = lesson_unlocks["look_and_learn"] != StudentProgression.Status.LOCKED and not is_blocked_by_boss
			button.set_button_disabled(not is_lesson_unlocked)

			if transition_context.new_lesson_unlocked and lesson_index == transition_context.newly_unlocked_lesson_number:
				button.set_button_disabled(true)

			if not(transition_context.new_lesson_unlocked and lesson_index == transition_context.newly_unlocked_lesson_number - 1):
				button.completed = UserDataManager.student_progression.is_lesson_completed(lesson_index) and not is_blocked_by_boss

			var completed_minigames: int = 0 if is_blocked_by_boss else _count_completed_minigames(lesson_index)
			if not is_blocked_by_boss:
				completed_minigames_total += completed_minigames
				total_minigames += (lesson_unlocks["games"] as Array).size()

			garden_control.current_progression = float(completed_minigames_total)
			garden_control.max_progression = float(total_minigames)
			lesson_index += 1

		garden_control.update_victory_assets_visibility(completed_minigames_total, total_minigames)
	_set_up_boss_buttons()

#endregion

#region Scene setup and ready sequence

func _configure_clouds_for_gardens() -> void:
	if not clouds or not garden_parent:
		return
	# Spread clouds across the full scrollable garden width so they remain
	# visible regardless of which garden the player scrolls to.
	var garden_count: int = garden_parent.get_child_count()
	if garden_count <= 0:
		return
	var content_world_width: float = float(garden_count * GARDEN_SIZE)
	# max_scroll is what the parent will actually pass through scroll_offset.
	# The CloudsManager needs this (not just world_width) to position clouds
	# inside their reachable drift_x range when parallax_factor < 1.0.
	var viewport_w: float = scroll_container.size.x
	if viewport_w <= 0.0:
		viewport_w = float(get_viewport_rect().size.x)
	var max_scroll: float = maxf(0.0, content_world_width - viewport_w)
	clouds.configure_world(content_world_width, max_scroll)


func _scroll_to_starting_garden(_transition_context: Dictionary) -> void:
	if transition_data:
		if transition_data.has("current_garden_index"):
			starting_garden = transition_data.current_garden_index
		else:
			Log.error("Gardens: Ready: The transition_data exists but does not contains the needed current_garden_index")
			starting_garden = 0
	elif starting_garden == -1:
		if UserDataManager.student_progression:
			var max_unlocked_lesson_number: int = UserDataManager.student_progression.get_max_unlocked_lesson_index() + 1
			starting_garden = _get_garden_index_for_lesson(max_unlocked_lesson_number)

	if starting_garden == -1:
		starting_garden = 0
	scroll_container.scroll_horizontal = GARDEN_SIZE * starting_garden
	if transition_data:
		if transition_data.has("boss_gate_lesson"):
			var boss_center: Vector2 = Vector2.ZERO
			if transition_data.get("is_final_boss", false):
				boss_center = _get_final_boss_center_position()
			if boss_center == Vector2.ZERO:
				boss_center = _get_boss_button_position(transition_data.boss_gate_lesson as int)
			if boss_center != Vector2.ZERO:
				_center_scroll_on_x(boss_center.x)
		elif transition_data.has("current_lesson_number"):
			var lesson_number: int = transition_data.current_lesson_number as int
			var garden_index: int = _get_garden_index_for_lesson(lesson_number)
			if garden_index >= 0 and garden_index < garden_parent.get_child_count():
				var garden_control: Garden = garden_parent.get_child(garden_index)
				var garden_center_x: float = garden_parent.position.x + garden_control.position.x + GARDEN_SIZE * 0.5
				_center_scroll_on_x(garden_center_x)
	scroll_beginning_garden = clampi(int(float(scroll_container.scroll_horizontal) / GARDEN_SIZE), 0, garden_parent.get_child_count() - 1)
	current_garden = garden_parent.get_child(scroll_beginning_garden)


func _center_scroll_on_x(target_x: float) -> void:
	if not scroll_container:
		return
	var view_width: float = scroll_container.size.x
	var desired_scroll: float = target_x - view_width * 0.5
	var max_scroll: float = 0.0
	var h_scroll_bar: ScrollBar = scroll_container.get_h_scroll_bar()
	if h_scroll_bar:
		max_scroll = h_scroll_bar.max_value
	scroll_container.scroll_horizontal = int(roundf(clampf(desired_scroll, 0.0, max_scroll)))

#endregion

#region Transitions and animations

func _handle_transition_sequences(transition_context: Dictionary) -> void:
	await get_tree().create_timer(1).timeout
	if transition_data.has("current_lesson_number") and not transition_data.get("skip_minigame_layout", false):
		await _open_minigames_layout(_get_current_lesson_button(transition_data.current_lesson_number as int), transition_data.current_lesson_number as int)
	if transition_context.new_lesson_unlocked:
		await _play_new_lesson_unlock_sequence()
	elif transition_context.pending_boss_gate_lesson > 0:
		await _play_boss_unlock_sequence(transition_context.pending_boss_gate_lesson as int)


func _play_new_lesson_unlock_sequence() -> void:
	var max_lesson: int = UserDataManager.student_progression.get_max_unlocked_lesson_index()
	await get_tree().create_timer(2).timeout
	await _close_minigames_layout()

	# Path towards the next lesson
	var lesson_index: int = 1
	var last_lesson_button: LessonButton
	var new_lesson_button: LessonButton
	var is_last_lesson_of_garden: bool = false
	for garden_control: Garden in garden_parent.get_children():
		for button_index: int in range(garden_control.get_lesson_buttons().size()):
			if lesson_index == max_lesson + 1:
				new_lesson_button = garden_control.get_lesson_buttons()[button_index]
			if lesson_index == max_lesson:
				last_lesson_button = garden_control.get_lesson_buttons()[button_index]
				if button_index == garden_control.get_lesson_buttons().size() -1:
					is_last_lesson_of_garden = true
			if last_lesson_button and new_lesson_button:
				break
			lesson_index += 1
		if last_lesson_button and new_lesson_button:
			break

	# Play an animation on the completed lesson
	if last_lesson_button:
		last_lesson_button.completed = true
		await last_lesson_button.right()

	# Fill in the path towards the next lesson
	var animation_curve: Curve2D = Curve2D.new()
	for index: int in range(max_lesson-1, max_lesson + 1):
		animation_curve.add_point(points[index][0] as Vector2, points[index][1] as Vector2, points[index][2] as Vector2)

	# Check if we need to scroll to the next garden
	if is_last_lesson_of_garden:
		scroll_beginning_garden = int(float(scroll_container.scroll_horizontal) / GARDEN_SIZE)
		var target_scroll: int = scroll_beginning_garden * GARDEN_SIZE + GARDEN_SIZE
		var tween: Tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 4)
		scroll_beginning_garden = clampi(int(float(target_scroll) / GARDEN_SIZE), 0, garden_parent.get_child_count() - 1)
		current_garden = garden_parent.get_child(scroll_beginning_garden)

	line_audio_stream_player.pitch_scale = 0.95
	var baked_points: PackedVector2Array = animation_curve.get_baked_points()
	for point: Vector2 in baked_points:
		if not line_audio_stream_player.playing:
			line_audio_stream_player.pitch_scale += 0.05
			line_audio_stream_player.play()
		unlocked_line.add_point(point)
		line_particles.position = point
		await get_tree().create_timer(0.01).timeout

	# Enable the next lesson button
	if new_lesson_button:
		new_lesson_button.set_button_disabled(false)

#endregion

#region Godot lifecycle

func _ready() -> void:
	UserDataManager.start_synchronization_timer()
	_load_lessons_from_database()
	var lesson_count: int = lessons.size()
	if lesson_count < MIN_LESSONS or lesson_count > MAX_LESSONS:
		Log.alert("Gardens: Lesson count must be between %d and %d, got %d" % [MIN_LESSONS, MAX_LESSONS, lesson_count])
		return
	if scroll_end_spacer:
		scroll_end_base_width = scroll_end_spacer.custom_minimum_size.x
	gardens_layout = get_session_layout(lesson_count)
	_set_up_lessons()
	_configure_clouds_for_gardens()

	# If there is no data, skips the rest
	if not UserDataManager.student_progression:
		Log.error("Gardens: Ready: No data for student progression")
		await (OpeningCurtain as OpeningCurtainClass).open()
		return
	await get_tree().process_frame
	
	_lock()
	
	var transition_context: Dictionary = _build_transition_context()
	_set_unlocked_path(transition_context.most_advanced_unlocked_lesson_index as int, (transition_context.pending_boss_gate_lesson <= 0) as bool)
	_apply_progression_to_gardens(transition_context)
	_scroll_to_starting_garden(transition_context)

	await (OpeningCurtain as OpeningCurtainClass).open()
	(MusicManager as MusicManagerClass).play((MusicManager as MusicManagerClass).Track.GARDEN)
	
	# Handles all the animation played when entering the gardens
	if transition_data:
		# Wait for the next frame to avoid glittering
		await get_tree().process_frame
		await _handle_transition_sequences(transition_context)
	
	_unlock()
	transition_data = {}

	if not UserDataManager.is_speech_played("brain"):
		await _play_brain_tutorial()
	
	# Play the tutorial if needed
	if not UserDataManager.is_speech_played("gardens"):
		kalulu_button.hide()
		await kalulu.play_kalulu_speech(intro_speech)
		kalulu_button.show()
		UserDataManager.mark_speech_as_played("gardens")

#endregion

func _play_brain_tutorial() -> void:
	kalulu_button.hide()
	for speech_index: int in range(brain_tutorial_speeches.size()):
		if speech_index == 0:
			await kalulu.play_kalulu_speech(brain_tutorial_speeches[speech_index], true, false)
		elif speech_index == brain_tutorial_speeches.size() - 1:
			await kalulu.play_kalulu_speech(brain_tutorial_speeches[speech_index], false, true)
		else:
			await kalulu.play_kalulu_speech(brain_tutorial_speeches[speech_index], false, false)
		await get_tree().create_timer(0.5).timeout

	UserDataManager.mark_speech_as_played("brain")
	kalulu_button.show()

#region Garden layout helpers

static func _get_lesson_button_half_size() -> Vector2:
	return Vector2(120, 120)


static func _get_layout_cache_base_dir() -> String:
	if UserDataManager and UserDataManager.has_method("get_student_folder"):
		var student_folder: String = UserDataManager.get_student_folder()
		if student_folder != "":
			return student_folder.path_join("gardens_layout_cache")
	return "user://gardens_layout_cache"


static func _get_layout_cache_path(session_id: int, total_lessons: int) -> String:
	return _get_layout_cache_base_dir().path_join("layout_v%s_%s_%s.tres" % [str(LAYOUT_VERSION), str(session_id), str(total_lessons)])


static func _load_layout_from_cache(session_id: int, total_lessons: int) -> GardensLayout:
	var cache_path: String = _get_layout_cache_path(session_id, total_lessons)
	if not FileAccess.file_exists(cache_path):
		return null
	if not ResourceLoader.exists(cache_path):
		return null
	var cached_layout: Resource = ResourceLoader.load(cache_path)
	if cached_layout is GardensLayout and not (cached_layout as GardensLayout).gardens.is_empty():
		Log.info("Gardens: Loaded cached layout from %s" % cache_path)
		return cached_layout as GardensLayout
	Log.warn("Gardens: Cached layout at %s was invalid, regenerating" % cache_path)
	return null


static func _save_layout_to_cache(layout: GardensLayout, session_id: int, total_lessons: int) -> void:
	if not layout:
		return
	var base_dir: String = _get_layout_cache_base_dir()
	DirAccess.make_dir_recursive_absolute(base_dir)
	var cache_path: String = _get_layout_cache_path(session_id, total_lessons)
	var error: Error = ResourceSaver.save(layout, cache_path)
	if error != OK:
		Log.warn("Gardens: Failed to save layout cache at %s: %s" % [cache_path, error_string(error)])


static func _find_valid_position_on_garden(_garden_color_index: int, tested_position: Vector2, _garden_dimensions: Vector2, _probe_half_size: Vector2 = Vector2.ZERO) -> Vector2:
	var center: Vector2 = Vector2(float(GARDEN_SIZE) / 2.0, GARDEN_CENTER_Y)
	var distance: float = tested_position.distance_to(center)
	if distance <= GARDEN_CIRCLE_RADIUS:
		return tested_position
	# Clamp to circle boundary
	var direction: Vector2 = (tested_position - center).normalized()
	return center + direction * GARDEN_CIRCLE_RADIUS


static func _find_overlapping_position_index(tested_position: Vector2, placed_positions: Array[Vector2], min_distance: float, ignore_index: int = -1) -> int:
	for index: int in range(placed_positions.size()):
		if index == ignore_index:
			continue
		if tested_position.distance_to(placed_positions[index]) < min_distance:
			return index
	return -1


static func _separate_lesson_position(tested_position: Vector2, garden_color_index: int, garden_dimensions: Vector2, placed_positions: Array[Vector2], half_size: Vector2) -> Vector2:
	var adjusted: Vector2 = tested_position
	var minimum_spacing: float = maxf(half_size.x, half_size.y) * 2.0 + 8.0
	for _attempt: int in range(8):
		var overlap_index: int = _find_overlapping_position_index(adjusted, placed_positions, minimum_spacing)
		if overlap_index == -1:
			return adjusted
		var overlap_gap: float = minimum_spacing - adjusted.distance_to(placed_positions[overlap_index])
		var vertical_offset: float = overlap_gap + half_size.y
		var lifted: Vector2 = _find_valid_position_on_garden(garden_color_index, adjusted + Vector2(0.0, -vertical_offset), garden_dimensions, half_size)
		if _find_overlapping_position_index(lifted, placed_positions, minimum_spacing) == -1:
			adjusted = lifted
			continue
		var shifted_previous: Vector2 = _find_valid_position_on_garden(garden_color_index, placed_positions[overlap_index] + Vector2(-minimum_spacing, 0.0), garden_dimensions, half_size)
		if _find_overlapping_position_index(shifted_previous, placed_positions, minimum_spacing, overlap_index) == -1:
			placed_positions[overlap_index] = shifted_previous
			continue
		var shifted_right: Vector2 = _find_valid_position_on_garden(garden_color_index, adjusted + Vector2(minimum_spacing, 0.0), garden_dimensions, half_size)
		if _find_overlapping_position_index(shifted_right, placed_positions, minimum_spacing) == -1:
			adjusted = shifted_right
			continue
		break
	return adjusted


static func compute_lessons_distribution(total_lessons: int, garden_layouts: Array[GardenLayout]) -> Array[int]:
	Log.info("Gardens: Computing lessons distribution")
	Log.trace("Gardens: ComputeLessonsDistribution: Parameters total_lessons = %s, garden_layouts count = %s" % [str(total_lessons), str(garden_layouts.size())])
	var total_capacity: int = 0
	for layout: GardenLayout in garden_layouts:
		total_capacity += layout.lesson_buttons.size()
	if total_lessons > total_capacity:
		# This should not be even possible. If this log is triggered, there is a bug on layout generation.
		Log.error("Gardens: Not enough lesson slots in provided layouts (capacity: %s, requested: %s). Some lessons will be left undistributed." % [str(total_capacity), str(total_lessons)])
	var distribution: Array[int] = []
	var lessons_left: int = total_lessons
	var gardens_left: int = garden_layouts.size()
	for layout_index: int in range(garden_layouts.size()):
		var max_lessons: int = garden_layouts[layout_index].lesson_buttons.size()
		Log.trace("Gardens: Garden index %s can host up to %s lessons" % [str(layout_index), str(max_lessons)])
		var lessons_for_garden: int = 0
		if gardens_left > 0:
			lessons_for_garden = int(ceili(float(lessons_left) / float(gardens_left)))
		lessons_for_garden = min(lessons_for_garden, max_lessons)
		if lessons_for_garden > lessons_left:
			lessons_for_garden = lessons_left
		distribution.append(lessons_for_garden)
		Log.trace("Gardens: Assigning %s lessons to garden index %s (lessons left before assignment: %s)" % [str(lessons_for_garden), str(layout_index), str(lessons_left)])
		lessons_left -= lessons_for_garden
		gardens_left -= 1
		Log.trace("Gardens: Lessons left after assignment: %s, gardens left: %s" % [str(lessons_left), str(gardens_left)])
	if lessons_left > 0:
		Log.error("Gardens: %s lessons could not be assigned to any garden layout" % str(lessons_left))
	return distribution


static func get_lessons_distribution(total_lessons: int, garden_layouts: Array[GardenLayout]) -> Array[int]:
	var distribution: Array[int] = []
	var lessons_from_layout: int = 0
	var has_cached_distribution: bool = true
	for layout: GardenLayout in garden_layouts:
		if layout.lesson_buttons.is_empty():
			has_cached_distribution = false
			break
		distribution.append(layout.lesson_buttons.size())
		lessons_from_layout += layout.lesson_buttons.size()
	if has_cached_distribution and lessons_from_layout == total_lessons:
		Log.trace("Gardens: Using lesson distribution from provided layout")
		return distribution
	if has_cached_distribution:
		Log.warn("Gardens: Layout lesson count mismatch (layout lessons: %s, expected: %s), recomputing distribution" % [str(lessons_from_layout), str(total_lessons)])
	return compute_lessons_distribution(total_lessons, garden_layouts)


static func get_session_layout(total_lessons: int) -> GardensLayout:
	var session_id: int = UserDataManager.get_student_session_id()
	var has_cached_layout: bool = cached_gardens_layout != null
	var session_changed: bool = cached_layout_session_id != session_id
	var lessons_changed: bool = cached_layout_lessons != total_lessons
	if session_changed or lessons_changed:
		if has_cached_layout:
			Log.info("Gardens: Session or lesson count changed, regenerating gardens layout")
		cached_gardens_layout = null
	if not cached_gardens_layout:
		var disk_cached_layout: GardensLayout = _load_layout_from_cache(session_id, total_lessons)
		if disk_cached_layout:
			cached_gardens_layout = disk_cached_layout
			cached_layout_session_id = session_id
			cached_layout_lessons = total_lessons
			return cached_gardens_layout
		cached_gardens_layout = generate_gardens_layout(total_lessons)
		cached_layout_session_id = session_id
		cached_layout_lessons = total_lessons
		_save_layout_to_cache(cached_gardens_layout, session_id, total_lessons)
	else:
		Log.trace("Gardens: Reusing cached layout for session %s" % str(session_id))
	return cached_gardens_layout


static func generate_gardens_layout(total_lessons: int) -> GardensLayout:
	var layout: GardensLayout = GardensLayout.new()
	if total_lessons <= 0:
		return layout
	Log.info("Gardens: Generating dynamic gardens layout")
	Log.trace("Gardens: Total lessons to layout: %s" % str(total_lessons))
	var lessons_left: int = total_lessons
	var garden_index: int = 0
	while lessons_left > 0 and garden_index < GARDENS_COUNT:
		var gardens_left: int = GARDENS_COUNT - garden_index
		var lessons_for_garden: int = int(ceili(float(lessons_left) / float(gardens_left)))
		Log.trace("Gardens: Generating layout for garden %s with %s lessons left" % [str(garden_index), str(lessons_left)])
		layout.gardens.append(_generate_single_garden_layout(garden_index, lessons_for_garden))
		lessons_left -= lessons_for_garden
		Log.trace("Gardens: Lessons left after garden %s generation: %s" % [str(garden_index), str(lessons_left)])
		garden_index += 1
	Log.info("Gardens: Completed layout generation with %s gardens" % str(layout.gardens.size()))
	return layout


static func _generate_single_garden_layout(garden_index: int, lessons_for_garden: int) -> GardenLayout:
	Log.info("Gardens: Generating single garden layout for garden %s" % str(garden_index))
	Log.trace("Gardens: Garden %s will include %s lessons" % [str(garden_index), str(lessons_for_garden)])
	var garden_layout: GardenLayout = GardenLayout.new()
	garden_layout.color = garden_index % GARDENS_COUNT
	Log.trace("Gardens: Garden %s color index set to %s" % [str(garden_index), str(garden_layout.color)])
	var garden_dimensions: Vector2 = Vector2(GARDEN_SIZE, GARDEN_CENTER_Y * 2.0)
	var half_size: Vector2 = _get_lesson_button_half_size()
	
	# Initial path positions
	var raw_positions: Array[Vector2i] = _get_slot_positions_for_count(lessons_for_garden)
	
	# Clamp to texture + avoid overlaps
	var resolved_positions: Array[Vector2] = []
	for lesson_index: int in range(lessons_for_garden):
		var pos: Vector2 = Vector2(raw_positions[lesson_index])
		var valid: Vector2 = _find_valid_position_on_garden(garden_layout.color, pos, garden_dimensions, half_size)
		var separated: Vector2 = _separate_lesson_position(valid, garden_layout.color, garden_dimensions, resolved_positions, half_size)
		if not separated.is_equal_approx(valid):
			Log.trace("Gardens: Separated lesson %s position from %s to %s to avoid overlap" % [str(lesson_index), str(valid), str(separated)])
		resolved_positions.append(separated)
		var rounded: Vector2i = Utils.round_vec2(separated)
		if not (rounded as Vector2).is_equal_approx(raw_positions[lesson_index]):
			Log.trace("Gardens: Adjusted lesson %s position from %s to %s to stay on background" % [str(lesson_index), str(raw_positions[lesson_index]), str(rounded)])
			raw_positions[lesson_index] = rounded
		Log.trace("Gardens: Garden %s lesson %s position calculated at %s" % [str(garden_index), str(lesson_index), str(rounded)])
	
	# Build lesson buttons with tangents
	var lesson_buttons: Array[GardenLayout.GardenLayoutLessonButton] = []
	for lesson_index: int in range(resolved_positions.size()):
		var lesson_position: Vector2i = Utils.round_vec2(resolved_positions[lesson_index])
		var path_out: Vector2i = Vector2i.ZERO
		if lesson_index + 1 < resolved_positions.size():
			var next_position: Vector2 = resolved_positions[lesson_index + 1]
			var tangent: Vector2 = (next_position - resolved_positions[lesson_index]) * 0.5
			Log.trace("Gardens: Garden %s lesson %s tangent to next lesson: %s" % [str(garden_index), str(lesson_index), str(tangent)])
			path_out = Vector2i(int(tangent.x), int(tangent.y))
		else:
			path_out = Vector2i(int(GARDEN_SIZE * 0.15), int((-1.0 if (garden_index % 2) == 0 else 1.0) * 60))
			Log.trace("Gardens: Garden %s last lesson %s path out set to %s" % [str(garden_index), str(lesson_index), str(path_out)])
		lesson_buttons.append(GardenLayout.GardenLayoutLessonButton.new(lesson_position, path_out))
	garden_layout.lesson_buttons = lesson_buttons

	Log.info("Gardens: Finished generating garden layout for garden %s" % str(garden_index))
	return garden_layout


static func _get_slot_positions_for_count(lesson_count: int) -> Array[Vector2i]:
	var indices: Array = Garden.SLOT_SELECTION.get(lesson_count, [])
	var positions: Array[Vector2i] = []
	for index: int in indices:
		positions.append(SLOT_CENTERS[index])
	return positions

#endregion

#region Runtime interactions

func _process(_delta: float) -> void:
	_process_back_button_hold(_delta)
	locked_line.position.x = - scroll_container.scroll_horizontal
	unlocked_line.position.x = - scroll_container.scroll_horizontal
	boss_buttons_container.position.x = - scroll_container.scroll_horizontal
	parallax_background.scroll_offset.x = - scroll_container.scroll_horizontal
	clouds.scroll_offset = scroll_container.scroll_horizontal


func _process_back_button_hold(delta: float) -> void:
	if not is_back_button_hold_active:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not back_button.get_global_rect().has_point(get_global_mouse_position()):
		_cancel_back_button_hold()
		return
	back_button_hold_progress_seconds += delta
	var progress_ratio: float = clampf(back_button_hold_progress_seconds / BACK_BUTTON_HOLD_DURATION_SECONDS, 0.0, 1.0)
	back_button.set_hold_progress_ratio(progress_ratio)
	if progress_ratio >= 1.0:
		_cancel_back_button_hold()
		_confirm_back_button_pressed()


func _get_minigame_layouts() -> Array[MinigameLayout]:
	return [minigame_layout_1, minigame_layout_2, minigame_layout_3]


func _open_minigames_layout(button: LessonButton, lesson_number: int) -> void:
	if in_minigame_selection or not UserDataManager.student_progression:
		return
	feedback_audio_stream_player2.pitch_scale = 1.1
	feedback_audio_stream_player2.play()
	in_minigame_selection = true
	# Gets the correct exercises for the lesson
	var exercises: Array[int] = Database.get_exercise_for_lesson(lesson_number)
	if not exercises or exercises.size() < 3:
		return
	# Sets the variables for the current garden and lesson
	current_lesson_number = lesson_number
	var garden_index_for_lesson: int = _get_garden_index_for_lesson(lesson_number)
	if garden_index_for_lesson >= 0 and garden_index_for_lesson < garden_parent.get_child_count():
		current_garden = garden_parent.get_child(garden_index_for_lesson)
	if button:
		current_button = button
		current_button.show_placeholder(true)
	current_button_global_position = button.global_position
	# Gets the current lesson unlocks
	var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[current_lesson_number]
	var are_minigames_locked: bool = lesson_unlocks["games"][0] == StudentProgression.Status.LOCKED and lesson_unlocks["games"][1] == StudentProgression.Status.LOCKED and lesson_unlocks["games"][2] == StudentProgression.Status.LOCKED
	# Deactivate the mouse filters on the buttons behind the layout
	for lesson_button_item: LessonButton in current_garden.get_lesson_buttons():
		lesson_button_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Background
	if are_minigames_locked:
		minigame_background_center.modulate = locked_color
	else:
		minigame_background_center.modulate = current_garden.color
	# Lesson button
	_handle_lesson_button(current_lesson_number, lesson_unlocks["look_and_learn"] as StudentProgression.Status)
	# Minigames
	var minigame_layouts: Array[MinigameLayout] = _get_minigame_layouts()
	for layout_index: int in minigame_layouts.size():
		_fill_minigame_choice(minigame_layouts[layout_index], exercises[layout_index], lesson_unlocks["games"][layout_index] as StudentProgression.Status, layout_index)
	# Animations
	minigame_selection.show()
	back_button.hide()
	kalulu_button.hide()
	line_particles.hide()
	minigame_background.size = 300.0 * Vector2.ONE
	minigame_background.global_position = current_button_global_position
	minigame_background.show()
	minigame_background_center.size = 300.0 * Vector2.ONE
	minigame_background_center.global_position = current_button_global_position
	minigame_background_center.show()
	var tween: Tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(minigame_background_center, "scale", (1800.0 / 300.0) * Vector2.ONE, 0.25)
	tween.tween_property(minigame_background_center, "global_position", Vector2(380.0, 0), 0.25)
	tween.tween_property(minigame_background, "scale", (1800.0 / 300.0) * Vector2.ONE, 0.25)
	tween.tween_property(minigame_background, "global_position", Vector2(380.0, 0), 0.25)
	tween.chain().tween_property(minigame_selection, "modulate:a", 1.0, 0.25)
	await tween.finished
	minigame_layout_opened.emit()


func _handle_lesson_button(lesson_number: int, status: StudentProgression.Status) -> void:
	lesson_button.text = lessons[lesson_number][0].grapheme
	lesson_button.set_button_disabled(status == StudentProgression.Status.LOCKED)
	lesson_button.completed = status == StudentProgression.Status.COMPLETED
	lesson_button_particles.emitting = status == StudentProgression.Status.UNLOCKED
	if status == StudentProgression.Status.COMPLETED:
		if transition_data and transition_data.has("look_and_learn_completed") and transition_data.look_and_learn_completed:
			await minigame_layout_opened
			lesson_button.right()


func _fill_minigame_choice(minigame_layout: MinigameLayout, exercise_type: int, status: StudentProgression.Status, minigame_number: int) -> void:
	minigame_layout.icon.texture = minigames_icons[exercise_type-1]
	minigame_layout.is_disabled = status == StudentProgression.Status.LOCKED
	if status == StudentProgression.Status.COMPLETED:
		if transition_data and transition_data.has("minigame_completed") and transition_data.minigame_completed and transition_data.has("minigame_number") and transition_data.minigame_number == minigame_number and transition_data.has("first_clear") and transition_data.first_clear:
			minigame_layout.self_modulate = unlocked_color
			await minigame_layout_opened
			create_tween().tween_property(minigame_layout, "self_modulate:a", 0, 0.5)
			minigame_layout.right()
		else:
			minigame_layout.self_modulate.a = 0
	elif status == StudentProgression.Status.LOCKED:
		minigame_layout.self_modulate = locked_color
	else:
		minigame_layout.self_modulate = unlocked_color
	minigame_layout.pressed.connect(_on_minigame_button_pressed.bind(exercise_type - 1, minigame_number))


func _get_minigame_scene(scene_index: int) -> PackedScene:
	if scene_index < 0 or scene_index >= minigame_scene_paths.size():
		return null
	if _minigame_scene_cache.has(scene_index):
		return _minigame_scene_cache[scene_index] as PackedScene
	var scene_path: String = minigame_scene_paths[scene_index]
	if scene_path.is_empty():
		return null
	var scene_resource: Resource = load(scene_path)
	if scene_resource is PackedScene:
		var packed_scene: PackedScene = scene_resource as PackedScene
		_minigame_scene_cache[scene_index] = packed_scene
		return packed_scene
	return null


func _count_completed_minigames(lesson_number: int) -> int:
	if not UserDataManager.student_progression or not UserDataManager.student_progression.unlocks.has(lesson_number):
		return 0
	var completed: int = 0
	for game_status: int in UserDataManager.student_progression.unlocks[lesson_number]["games"]:
		if game_status == StudentProgression.Status.COMPLETED:
			completed += 1
	return completed


func _close_minigames_layout() -> void:
	if not in_minigame_selection:
		return
	in_minigame_selection = false
	feedback_audio_stream_player2.pitch_scale = 0.75
	feedback_audio_stream_player2.play()
	var tween: Tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(minigame_selection, "modulate:a", 0.0, 0.25)
	var other_tween: Tween = tween.chain()
	other_tween.tween_property(minigame_background_center, "scale", Vector2.ONE, 0.25)
	other_tween.tween_property(minigame_background_center, "global_position", current_button_global_position, 0.25)
	other_tween.tween_property(minigame_background, "scale", Vector2.ONE, 0.25)
	other_tween.tween_property(minigame_background, "global_position", current_button_global_position, 0.25)
	await tween.finished
	if current_button:
		current_button.show_placeholder(false)
	minigame_selection.hide()
	minigame_background.hide()
	minigame_background_center.hide()
	back_button.show()
	kalulu_button.show()
	line_particles.show()
	for button: LessonButton in current_garden.get_lesson_buttons():
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	for layout: MinigameLayout in _get_minigame_layouts():
		layout.pressed.disconnect(_on_minigame_button_pressed)


#region Lesson setup and path
func _set_up_lessons() -> void:
	var lesson_number: int = 1
	for garden_ind: int in range(garden_parent.get_child_count()):
		var garden_control: Garden = garden_parent.get_child(garden_ind)
		var button_count: int = garden_control.garden_layout.lesson_buttons.size()
		var lesson_buttons: Array[LessonButton] = garden_control.get_lesson_buttons()
		for index: int in range(button_count):
			if not lesson_number in lessons:
				break
			garden_control.set_lesson_label(index, lessons[lesson_number][0].grapheme as String)
			lesson_buttons[index].pressed.connect(_on_garden_lesson_button_pressed.bind(lesson_buttons[index], lesson_number))
			lesson_number += 1


func set_gardens_layout(p_gardens_layout: GardensLayout) -> void:
	Log.info("Gardens: Setting gardens layout")
	_gardens_layout = p_gardens_layout
	Log.trace("Gardens: Layout contains %s gardens" % str(_gardens_layout.gardens.size()))
	add_gardens()
	if garden_parent:
		Log.trace("Gardens: Yielding a frame to ensure garden controls are ready before setting up the path")
		await get_tree().process_frame
	set_up_path()
	_set_up_boss_buttons()


func add_gardens() -> void:
	if not garden_parent:
		return
	Log.info("Gardens: Clearing existing gardens before generation")
	for child: Node in garden_parent.get_children():
		child.free()
	Log.info("Gardens: Computing lesson distribution for new gardens")
	lesson_distribution = get_lessons_distribution(lessons.size(), gardens_layout.gardens)
	var garden_index: int = 0
	for layout_index: int in range(gardens_layout.gardens.size()):
		Log.trace("Gardens: Preparing garden %s with layout index %s" % [str(garden_index), str(layout_index)])
		var garden_layout: GardenLayout = gardens_layout.gardens[layout_index]
		var garden: Garden = GARDEN_SCENES[layout_index].instantiate()
		garden_parent.add_child(garden)
		garden.garden_index = garden_index
		garden_index += 1
		var lessons_for_garden: int = lesson_distribution[layout_index]
		Log.trace("Gardens: Garden %s will host %s lessons" % [str(garden.garden_index), str(lessons_for_garden)])
		garden_layout.lesson_buttons.resize(lessons_for_garden)
		Log.trace("Gardens: Assigning layout to garden %s" % str(garden.garden_index))
		garden.garden_layout = garden_layout
	_sync_boss_buttons_container()


func set_up_path() -> void:
	if not garden_parent:
		return
	points = []
	var curve: Curve2D = Curve2D.new()
	for index: int in range(garden_parent.get_child_count()):
		var garden_control: Garden = garden_parent.get_child(index)
		var lesson_buttons: Array[LessonButton] = garden_control.get_lesson_buttons()
		for button_index: int in range(lesson_buttons.size()):
			var button: LessonButton = lesson_buttons[button_index]
			var button_center: Vector2 = button.position + button.size / 2.0
			var point_position: Vector2 = garden_parent.position + garden_control.position + button_center
			var path_out: Vector2 = Vector2.ZERO
			if button_index + 1 < lesson_buttons.size():
				var next_button: LessonButton = lesson_buttons[button_index + 1]
				var next_center: Vector2 = next_button.position + next_button.size / 2.0
				path_out = (next_center - button_center) * 0.5
			else:
				path_out = Vector2(GARDEN_SIZE * 0.15, (-1.0 if (index % 2) == 0 else 1.0) * 60)
			var point_in: Vector2 = Vector2.ZERO
			if curve.point_count > 0:
				point_in = curve.get_point_position(curve.point_count - 1) + curve.get_point_out(curve.point_count - 1) - point_position
			curve.add_point(point_position, point_in, path_out)
			points.append([point_position, point_in, path_out])
	locked_line.points = curve.get_baked_points()


func _set_unlocked_path(max_unlocked_lesson_index: int, include_boss_segment: bool = true) -> void:
	unlocked_line.clear_points()
	if max_unlocked_lesson_index < 0 or points.is_empty():
		return
	var clamped_lesson_index: int = clamp(max_unlocked_lesson_index, 0, points.size() - 1)
	var progress_curve: Curve2D = Curve2D.new()
	for index: int in range(clamped_lesson_index + 1):
		var point_data: Array = points[index]
		progress_curve.add_point(point_data[0] as Vector2, point_data[1] as Vector2, point_data[2] as Vector2)
	var baked_points: PackedVector2Array = progress_curve.get_baked_points()
	var final_points: PackedVector2Array = baked_points
	var pending_boss_gate: int = -1
	if include_boss_segment:
		pending_boss_gate = _get_pending_boss_gate_lesson(clamped_lesson_index)
	if pending_boss_gate > 0:
		var boss_segment_points: PackedVector2Array = _get_boss_segment_points(pending_boss_gate)
		if boss_segment_points.size() > 0:
			final_points = PackedVector2Array()
			for point: Vector2 in baked_points:
				final_points.append(point)
			for point: Vector2 in boss_segment_points:
				if final_points.size() == 0 or final_points[final_points.size() - 1] != point:
					final_points.append(point)
	unlocked_line.points = final_points
	if _should_show_final_boss():
		_extend_unlocked_path_to_final_boss()
	if final_points.size() > 0:
		line_particles.position = final_points[final_points.size() - 1]


func _play_boss_unlock_sequence(gate_lesson: int) -> void:
	var boss_segment_points: PackedVector2Array = _get_boss_segment_points(gate_lesson)
	if boss_segment_points.size() == 0:
		return
	var existing_points: PackedVector2Array = unlocked_line.points
	var last_point: Vector2 = Vector2.ZERO
	if existing_points.size() > 0:
		last_point = existing_points[existing_points.size() - 1]
	line_audio_stream_player.pitch_scale = 0.95
	for point: Vector2 in boss_segment_points:
		if point == last_point:
			continue
		if not line_audio_stream_player.playing:
			line_audio_stream_player.pitch_scale += 0.05
			line_audio_stream_player.play()
		unlocked_line.add_point(point)
		line_particles.position = point
		last_point = point
		await get_tree().create_timer(0.01).timeout

#endregion

func _sync_boss_buttons_container() -> void:
	if not boss_buttons_container or not garden_parent:
		return
	boss_buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_buttons_container.position = Vector2.ZERO
	boss_buttons_container.size = scroll_container.size


func _clear_boss_buttons() -> void:
	if not boss_buttons_container:
		return
	for child: Node in boss_buttons_container.get_children():
		child.queue_free()


func _set_up_boss_buttons() -> void:
	_clear_boss_buttons()
	if not boss_buttons_container:
		return
	_sync_boss_buttons_container()
	_reset_final_boss_scroll_space()
	if lesson_distribution.is_empty() or points.is_empty():
		return
	var total_lessons: int = lessons.size()
	if total_lessons <= 0:
		return
	var gate_lessons: Array[int] = StudentProgression.get_boss_gate_lessons()
	for gate_lesson: int in gate_lessons:
		if gate_lesson <= 0 or gate_lesson >= total_lessons:
			continue
		if gate_lesson - 1 >= points.size() or gate_lesson >= points.size():
			continue
		var boss_position: Vector2 = _get_boss_button_position(gate_lesson)
		if boss_position == Vector2.ZERO:
			continue
		var boss_button: BossButton = BOSS_BUTTON_SCENE.instantiate()
		boss_buttons_container.add_child(boss_button)
		var boss_size: Vector2 = boss_button.get_combined_minimum_size()
		if boss_size == Vector2.ZERO:
			boss_size = boss_button.size
		boss_button.position = boss_position - boss_size * 0.5
		if UserDataManager.student_progression:
			var is_completed: bool = UserDataManager.student_progression.is_boss_completed(gate_lesson)
			var is_blocked_by_boss: bool = UserDataManager.student_progression.is_lesson_blocked_by_boss(gate_lesson)
			var is_unlocked: bool = UserDataManager.student_progression.is_lesson_completed(gate_lesson) and not is_blocked_by_boss
			boss_button.set_button_disabled(not is_unlocked and not is_completed)
			boss_button.completed = is_completed
		else:
			boss_button.set_button_disabled(true)
		var garden_index: int = _get_garden_index_for_lesson(gate_lesson)
		boss_button.pressed.connect(_on_boss_button_pressed.bind(gate_lesson, garden_index))
	_set_up_final_boss_button()


func _set_up_final_boss_button() -> void:
	if not boss_buttons_container or not garden_parent:
		return
	if not _should_show_final_boss():
		return
	if points.is_empty():
		return
	var final_lesson_number: int = lessons.size()
	if final_lesson_number <= 0:
		return
	var final_boss_center: Vector2 = _get_final_boss_center_position()
	if final_boss_center == Vector2.ZERO:
		return
	var last_garden_index: int = max(0, garden_parent.get_child_count() - 1)
	var final_boss_size: Vector2 = _get_final_boss_size()
	var boss_button: BossButton = BOSS_BUTTON_SCENE.instantiate()
	boss_buttons_container.add_child(boss_button)
	boss_button.custom_minimum_size = final_boss_size
	boss_button.size = final_boss_size
	boss_button.pivot_offset = final_boss_size * 0.5
	boss_button.position = final_boss_center - final_boss_size * 0.5
	boss_button.set_button_disabled(false)
	boss_button.pressed.connect(_on_final_boss_button_pressed.bind(final_lesson_number, last_garden_index))
	_update_final_boss_scroll_space(final_boss_center, final_boss_size)


func _reset_final_boss_scroll_space() -> void:
	if scroll_end_spacer:
		scroll_end_spacer.custom_minimum_size.x = scroll_end_base_width


func _update_final_boss_scroll_space(final_boss_center: Vector2, final_boss_size: Vector2) -> void:
	if not scroll_end_spacer or not garden_parent:
		return
	if final_boss_center == Vector2.ZERO:
		return
	var last_garden_index: int = max(0, garden_parent.get_child_count() - 1)
	var last_garden: Garden = garden_parent.get_child(last_garden_index)
	var last_garden_right_edge: float = garden_parent.position.x + last_garden.position.x + GARDEN_SIZE
	var final_boss_right_edge: float = final_boss_center.x + final_boss_size.x * 0.5
	var extra_width: float = max(0.0, final_boss_right_edge - last_garden_right_edge)
	scroll_end_spacer.custom_minimum_size.x = scroll_end_base_width + extra_width


func _extend_unlocked_path_to_final_boss() -> void:
	if not unlocked_line or points.is_empty():
		return
	var final_boss_center: Vector2 = _get_final_boss_center_position()
	if final_boss_center == Vector2.ZERO:
		return
	var last_point: Vector2 = points[points.size() - 1][0] as Vector2
	if last_point == final_boss_center:
		return
	var extension_curve: Curve2D = Curve2D.new()
	extension_curve.add_point(last_point)
	extension_curve.add_point(final_boss_center)
	var extension_points: PackedVector2Array = extension_curve.get_baked_points()
	if extension_points.size() == 0:
		return
	for index: int in range(extension_points.size()):
		if index == 0:
			continue
		unlocked_line.add_point(extension_points[index])
	if line_particles:
		line_particles.position = final_boss_center


func _get_final_boss_center_position() -> Vector2:
	if not garden_parent or points.is_empty():
		return Vector2.ZERO
	var last_point_data: Array = points[points.size() - 1]
	var last_point: Vector2 = last_point_data[0] as Vector2
	var final_boss_size: Vector2 = _get_final_boss_size()
	var last_garden_index: int = max(0, garden_parent.get_child_count() - 1)
	var last_garden: Garden = garden_parent.get_child(last_garden_index)
	var last_garden_right_edge: float = garden_parent.position.x + last_garden.position.x + GARDEN_SIZE
	var min_center_x: float = last_garden_right_edge + final_boss_size.x * 0.5 + FINAL_BOSS_PADDING
	var desired_center_x: float = last_point.x + final_boss_size.x * 0.5 + FINAL_BOSS_PADDING
	return Vector2(maxf(min_center_x, desired_center_x), last_point.y)


func _get_final_boss_size() -> Vector2:
	return _get_lesson_button_half_size() * 4.0


func _should_show_final_boss() -> bool:
	if not UserDataManager.student_progression:
		return false
	var total_lessons: int = lessons.size()
	if total_lessons <= 0:
		return false
	for lesson_number: int in range(1, total_lessons + 1):
		if not UserDataManager.student_progression.is_lesson_completed(lesson_number):
			return false
	var gate_lessons: Array[int] = StudentProgression.get_boss_gate_lessons()
	for gate_lesson: int in gate_lessons:
		if not UserDataManager.student_progression.is_boss_completed(gate_lesson):
			return false
	return true


func _get_boss_button_position(gate_lesson: int) -> Vector2:
	var segment_points: PackedVector2Array = _get_boss_segment_points(gate_lesson)
	if segment_points.size() == 0:
		return Vector2.ZERO
	return segment_points[segment_points.size() - 1]


func _get_pending_boss_gate_lesson(max_unlocked_lesson_index: int) -> int:
	if not UserDataManager.student_progression:
		return -1
	var gate_lessons: Array[int] = StudentProgression.get_boss_gate_lessons()
	for gate_lesson: int in gate_lessons:
		if gate_lesson - 1 != max_unlocked_lesson_index:
			continue
		if UserDataManager.student_progression.is_lesson_completed(gate_lesson) and not UserDataManager.student_progression.is_boss_completed(gate_lesson):
			return gate_lesson
	return -1


func _get_boss_segment_points(gate_lesson: int, segment_ratio: float = 0.5) -> PackedVector2Array:
	if gate_lesson <= 0 or gate_lesson >= points.size():
		return PackedVector2Array()
	var clamped_ratio: float = clamp(segment_ratio, 0.0, 1.0)
	var start_data: Array = points[gate_lesson - 1]
	var end_data: Array = points[gate_lesson]
	var start_point: Vector2 = start_data[0] as Vector2
	var end_point: Vector2 = end_data[0] as Vector2
	var curve: Curve2D = Curve2D.new()
	curve.add_point(start_point, start_data[1] as Vector2, start_data[2] as Vector2)
	curve.add_point(end_point, end_data[1] as Vector2, end_data[2] as Vector2)
	var baked_points: PackedVector2Array = curve.get_baked_points()
	if baked_points.size() < 2:
		var fallback_points: PackedVector2Array = PackedVector2Array()
		fallback_points.append(start_point.lerp(end_point, clamped_ratio))
		return fallback_points
	var total_length: float = 0.0
	for index: int in range(1, baked_points.size()):
		total_length += baked_points[index - 1].distance_to(baked_points[index])
	if total_length <= 0.0:
		var fallback_points2: PackedVector2Array = PackedVector2Array()
		fallback_points2.append(start_point.lerp(end_point, clamped_ratio))
		return fallback_points2
	var target_length: float = total_length * clamped_ratio
	var walked_length: float = 0.0
	var segment_points: PackedVector2Array = PackedVector2Array()
	segment_points.append(baked_points[0])
	for index: int in range(1, baked_points.size()):
		var segment_length: float = baked_points[index - 1].distance_to(baked_points[index])
		if walked_length + segment_length >= target_length:
			var segment_progress: float = 0.0
			if segment_length > 0.0:
				segment_progress = (target_length - walked_length) / segment_length
			segment_points.append(baked_points[index - 1].lerp(baked_points[index], segment_progress))
			break
		segment_points.append(baked_points[index])
		walked_length += segment_length
	return segment_points


func _get_garden_index_for_lesson(lesson_number: int) -> int:
	var lesson_index: int = 0
	for garden_index: int in range(lesson_distribution.size()):
		lesson_index += lesson_distribution[garden_index]
		if lesson_number <= lesson_index:
			return garden_index
	return max(0, lesson_distribution.size() - 1)


func _lock() -> void:
	is_locked = true
	lock.show()


func _unlock() -> void:
	is_locked = false
	lock.hide()


func _get_current_lesson_button(lesson: int) -> LessonButton:
	var lesson_number: int = 1
	for garden_control: Garden in garden_parent.get_children():
		for index: int in range(garden_control.get_lesson_buttons().size()):
			if lesson_number == lesson:
				return garden_control.get_lesson_buttons()[index]
			lesson_number += 1
	return null


func _on_garden_lesson_button_pressed(button: LessonButton, lesson_number: int) -> void:
	_open_minigames_layout(button, lesson_number)


func _on_lesson_button_pressed() -> void:
	if is_locked:
		return
	feedback_audio_stream_player.play()
	await (OpeningCurtain as OpeningCurtainClass).close()
	LookAndLearn.transition_data = {
		current_button_global_position = current_button_global_position,
		current_lesson_number = current_lesson_number,
		current_garden_index = current_garden.garden_index,
		look_and_learn_completed = false
	}
	get_tree().change_scene_to_packed(LOOK_AND_LEARN_SCENE)


func _on_boss_button_pressed(lesson_number: int, garden_index: int) -> void:
	if is_locked:
		return
	feedback_audio_stream_player.play()
	await (OpeningCurtain as OpeningCurtainClass).close()
	Minigame.transition_data = {
		current_lesson_number = lesson_number,
		current_garden_index = garden_index,
		minigame_number = -1,
		minigame_completed = false,
		skip_minigame_layout = true,
		boss_gate_lesson = lesson_number
	}
	get_tree().change_scene_to_file(BOSS_MINIGAME_SCENE_PATH)


func _on_final_boss_button_pressed(lesson_number: int, garden_index: int) -> void:
	if is_locked:
		return
	feedback_audio_stream_player.play()
	await (OpeningCurtain as OpeningCurtainClass).close()
	Minigame.transition_data = {
		current_lesson_number = lesson_number,
		current_garden_index = garden_index,
		minigame_number = -1,
		minigame_completed = false,
		skip_minigame_layout = true,
		boss_gate_lesson = lesson_number,
		is_final_boss = true
	}
	get_tree().change_scene_to_file(BOSS_MINIGAME_SCENE_PATH)


func _on_minigame_button_pressed(scene_index: int, minigame_number: int) -> void:
	if is_locked:
		return
	var minigame_scene: PackedScene = _get_minigame_scene(scene_index)
	if not minigame_scene:
		Log.error("Gardens: Missing minigame scene for index %d" % scene_index)
		return
	feedback_audio_stream_player.play()
	await (OpeningCurtain as OpeningCurtainClass).close()
	Minigame.transition_data = {
		current_button_global_position = current_button_global_position,
		current_lesson_number = current_lesson_number,
		current_garden_index = current_garden.garden_index,
		minigame_number = minigame_number,
		minigame_completed = false
	}
	get_tree().change_scene_to_packed(minigame_scene)


func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if in_minigame_selection:
		return
	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event
		if mouse_button_event.pressed:
			var direction: int = 0
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				direction = -1
			elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				direction = 1
			elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				direction = -1
			elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				direction = 1
			if direction != 0:
				_scroll_by_garden(direction)
				return
	if event.is_action_pressed("left_click"):
		is_scrolling = true
	elif event.is_action_released("left_click"):
		is_scrolling = false
		return
	if is_scrolling and event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		scroll_container.scroll_horizontal -= int(motion_event.relative.x)


func _scroll_by_garden(p_direction: int) -> void:
	var target_scroll: int = scroll_container.scroll_horizontal + p_direction * 200
	scroll_container.scroll_horizontal = target_scroll


func _confirm_back_button_pressed() -> void:
	UserDataManager.logout_student()
	await (OpeningCurtain as OpeningCurtainClass).close()
	get_tree().change_scene_to_file("res://sources/menus/login/login.tscn")


func _on_back_button_button_down() -> void:
	if is_back_button_hold_active:
		return
	is_back_button_hold_active = true
	back_button_hold_progress_seconds = 0.0
	back_button.begin_hold()


func _on_back_button_button_up() -> void:
	_cancel_back_button_hold()


func _cancel_back_button_hold() -> void:
	is_back_button_hold_active = false
	back_button_hold_progress_seconds = 0.0
	back_button.cancel_hold()


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_locked:
		return
	if event.is_action_pressed("left_click") and in_minigame_selection:
		_close_minigames_layout()


func _on_kalulu_button_pressed() -> void:
	kalulu_button.hide()
	if current_garden.get_progress_ratio() > 0.75:
		await kalulu.play_kalulu_speech(help_many_plants_speech)
	else:
		await kalulu.play_kalulu_speech(help_few_plants_speech)
	kalulu_button.show()

#endregion

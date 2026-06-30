class_name Gardens
extends Control

signal minigame_layout_opened()

const KALULU: GDScript = preload("res://sources/minigames/base/kalulu_ingame.gd")
const MINIGAME_WEDGE_SCENE: PackedScene = preload("res://sources/gardens/minigame_wedge.tscn")
# Wheel geometry, in MinigameSelection-local coords (canvas 2560×1800).
const WHEEL_CENTER: Vector2 = Vector2(1280, 900)
# Matches the inner edge of big_button.png; past this the gray ring hides everything.
const WHEEL_RADIUS: float = 815.0
const WHEEL_ARC_SEGMENTS: int = 48
const WHEEL_ICON_DISTANCE_RATIO: float = 0.55
const WHEEL_DIVIDER_WIDTH: float = 12.0
const WHEEL_HIGHLIGHT_WIDTH: float = 24.0
# Outline around the central Look-and-Learn button. Drawn at the button's visible
# edge. Colored dark by default, gold when L&L is the next-to-play step.
const LESSON_BUTTON_OUTLINE_RADIUS: float = 192.0
# Top inset of the wheel's central label so the grapheme text sits just below the
# button center, mirroring the movie icon just above it. The 384x384 button has
# its center at y=192; the label (vertical-centered) then centers at y=(this+384)/2.
const LESSON_BUTTON_LABEL_TOP_OFFSET: float = 104.0
# Loaded on demand instead of preloaded: this script never unloads (it has
# static variables), so preloaded constants would pin every garden's assets in
# memory for the whole app lifetime — including while minigames run, which
# OOM-crashes low-memory devices.
const GARDEN_SCENE_PATHS: Array[String] = [
	"res://resources/gardens/garden_01.tscn",
	"res://resources/gardens/garden_02.tscn",
	"res://resources/gardens/garden_03.tscn",
	"res://resources/gardens/garden_04.tscn",
	"res://resources/gardens/garden_05.tscn",
	"res://resources/gardens/garden_06.tscn",
	"res://resources/gardens/garden_07.tscn",
	"res://resources/gardens/garden_08.tscn",
	"res://resources/gardens/garden_09.tscn",
	"res://resources/gardens/garden_10.tscn",
	"res://resources/gardens/garden_11.tscn",
	"res://resources/gardens/garden_12.tscn",
]
const LOOK_AND_LEARN_SCENE_PATH: String = "res://sources/look_and_learn/look_and_learn.tscn"
const BOSS_BUTTON_SCENE: PackedScene = preload("res://sources/gardens/boss_button.tscn")
const BOSS_MINIGAME_SCENE_PATH: String = "res://sources/minigames/boss/boss_minigame.tscn"
const BRAIN_SCENE_PATH: String = "res://sources/brain/brain.tscn"
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
@export_category("Minigames")
@export var minigame_scene_paths: PackedStringArray = PackedStringArray()
## Animal body (colored by the garden) and face (kept as-is for eyes/mouth details).
## Both arrays must be the same length and aligned with `minigame_scene_paths`.
@export var minigames_body_icons: Array[Texture] = []
@export var minigames_face_icons: Array[Texture] = []

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
@onready var lesson_button_outline: Line2D = %LessonButtonOutline
@onready var lesson_button_movie_icon: TextureRect = %MovieIcon
@onready var lesson_button_particles: GPUParticles2D = %LessonButtonParticles
@onready var back_button: BackButton = %BackButton
@onready var right_audio_stream_player: AudioStreamPlayer = $RightAudioStreamPlayer
@onready var left_audio_stream_player: AudioStreamPlayer = $LeftAudioStreamPlayer
@onready var feedback_audio_stream_player: AudioStreamPlayer = $FeedBackAudioStreamPlayer
@onready var feedback_audio_stream_player2: AudioStreamPlayer = $FeedBackAudioStreamPlayer2
@onready var wedges_container: Control = %WedgesContainer
@onready var background_rect: ColorRect = %BackgroundRect
@onready var lock: Control = %Lock
@onready var kalulu: KALULU = %Kalulu
@onready var kalulu_button: CanvasItem = %KaluluButton
@onready var brain_button: TextureButton = %BrainButton
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

func _compute_cloud_world_bounds() -> Vector2:
	if not garden_parent:
		return Vector2.ZERO
	var garden_count: int = garden_parent.get_child_count()
	if garden_count <= 0:
		return Vector2.ZERO
	var trailing_spacer_width: float = 0.0
	if scroll_end_spacer:
		trailing_spacer_width = scroll_end_spacer.custom_minimum_size.x
	var content_world_width: float = float(garden_count * GARDEN_SIZE) + trailing_spacer_width
	var viewport_w: float = scroll_container.size.x
	if viewport_w <= 0.0:
		viewport_w = float(get_viewport_rect().size.x)
	var max_scroll: float = maxf(0.0, content_world_width - viewport_w)
	return Vector2(content_world_width, max_scroll)


func _configure_clouds_for_gardens() -> void:
	if not clouds:
		return
	var bounds: Vector2 = _compute_cloud_world_bounds()
	if bounds == Vector2.ZERO:
		return
	clouds.configure_world(bounds.x, bounds.y)


func _refresh_cloud_world_bounds() -> void:
	if not clouds:
		return
	var bounds: Vector2 = _compute_cloud_world_bounds()
	if bounds == Vector2.ZERO:
		return
	clouds.set_world_bounds(bounds.x, bounds.y)


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


# Single source of truth for wedge geometry. Returns the pie-slice's start/end
# angles and the bisector angle along which the icon sits, for wedge `wedge_index`
# of a wheel showing `minigame_count` wedges (1..3).
#   N=1: full disc, icon to the left of the L&L button.
#   N=2: game 0 left half, game 1 right half.
#   N=3: game 0 top-right, game 1 bottom, game 2 top-left.
static func _get_wedge_angles(minigame_count: int, wedge_index: int) -> Dictionary:
	if minigame_count == 1:
		return {start = 0.0, end = TAU, icon = PI}
	if minigame_count == 2:
		if wedge_index == 0:
			return {start = PI / 2.0, end = 3.0 * PI / 2.0, icon = PI}
		return {start = -PI / 2.0, end = PI / 2.0, icon = 0.0}
	if wedge_index == 0:
		return {start = -PI / 2.0, end = PI / 6.0, icon = -PI / 6.0}
	if wedge_index == 1:
		return {start = PI / 6.0, end = 5.0 * PI / 6.0, icon = PI / 2.0}
	return {start = 5.0 * PI / 6.0, end = 3.0 * PI / 2.0, icon = 7.0 * PI / 6.0}


static func _get_wedge_layout(minigame_count: int, wedge_index: int) -> Dictionary:
	var angles: Dictionary = _get_wedge_angles(minigame_count, wedge_index)
	var polygon: PackedVector2Array = _generate_full_disc_polygon() if minigame_count == 1 \
			else _generate_pie_slice_polygon(angles.start as float, angles.end as float)
	return {polygon = polygon, icon_center = _wedge_icon_position(angles.icon as float)}


static func _generate_pie_slice_polygon(start_angle: float, end_angle: float, radius: float = WHEEL_RADIUS) -> PackedVector2Array:
	var wheel_points: PackedVector2Array = PackedVector2Array()
	wheel_points.append(WHEEL_CENTER)
	var span: float = end_angle - start_angle
	for index: int in range(WHEEL_ARC_SEGMENTS + 1):
		var angle: float = start_angle + span * (float(index) / float(WHEEL_ARC_SEGMENTS))
		wheel_points.append(WHEEL_CENTER + Vector2(cos(angle), sin(angle)) * radius)
	return wheel_points


static func _generate_full_disc_polygon(radius: float = WHEEL_RADIUS) -> PackedVector2Array:
	var wheel_points: PackedVector2Array = PackedVector2Array()
	for index: int in range(WHEEL_ARC_SEGMENTS):
		var angle: float = TAU * float(index) / float(WHEEL_ARC_SEGMENTS)
		wheel_points.append(WHEEL_CENTER + Vector2(cos(angle), sin(angle)) * radius)
	return wheel_points


# Wedge polygon with outer arc inset by half the stroke width so the gold line
# stays inside the wedge. Radial edges keep their angles (fall on the dividers).
static func _generate_wedge_highlight_polygon(minigame_count: int, wedge_index: int) -> PackedVector2Array:
	var inset_radius: float = WHEEL_RADIUS - WHEEL_HIGHLIGHT_WIDTH * 0.5
	if minigame_count == 1:
		return _generate_full_disc_polygon(inset_radius)
	var angles: Dictionary = _get_wedge_angles(minigame_count, wedge_index)
	return _generate_pie_slice_polygon(angles.start as float, angles.end as float, inset_radius)


static func _wedge_icon_position(angle_rad: float) -> Vector2:
	return WHEEL_CENTER + Vector2(cos(angle_rad), sin(angle_rad)) * (WHEEL_RADIUS * WHEEL_ICON_DISTANCE_RATIO)


static func _get_divider_segments(minigame_count: int) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if minigame_count < 2:
		return segments
	for wedge_index: int in range(minigame_count):
		var start_angle: float = _get_wedge_angles(minigame_count, wedge_index).start as float
		var edge: Vector2 = WHEEL_CENTER + Vector2(cos(start_angle), sin(start_angle)) * WHEEL_RADIUS
		segments.append(PackedVector2Array([WHEEL_CENTER, edge]))
	return segments


func _clear_wheel() -> void:
	for child: Node in wedges_container.get_children():
		child.queue_free()


func _build_wheel(exercises: Array[int], lesson_unlocks: Dictionary) -> void:
	_clear_wheel()
	var minigame_count: int = exercises.size()
	for wedge_index: int in range(minigame_count):
		var layout: Dictionary = _get_wedge_layout(minigame_count, wedge_index)
		var exercise_type: int = exercises[wedge_index]
		var icon_index: int = exercise_type - 1
		# Guard against exercise types with no matching wheel icon (e.g. the
		# removed fish minigame, type 10): fall back to the highest available one
		# so we never index past the icon arrays.
		var max_icon_index: int = minigames_body_icons.size() - 1
		if icon_index < 0 or icon_index > max_icon_index:
			Log.error("Gardens: Exercise type %d has no wheel icon (%d available); using the highest available minigame instead." % [exercise_type, minigames_body_icons.size()])
			icon_index = clampi(icon_index, 0, max_icon_index)
		var status: StudentProgression.Status = lesson_unlocks["games"][wedge_index] as StudentProgression.Status
		var wedge: MinigameWedge = MINIGAME_WEDGE_SCENE.instantiate()
		wedges_container.add_child(wedge)
		var is_wedge_locked: bool = status == StudentProgression.Status.LOCKED
		wedge.configure(
			layout.polygon as PackedVector2Array,
			layout.icon_center as Vector2,
			minigames_body_icons[icon_index],
			minigames_face_icons[icon_index],
			_wedge_color_for_status(status),
			_body_color_for_status(status),
			is_wedge_locked,
		)
		wedge.is_disabled = is_wedge_locked
		wedge.pressed.connect(_on_minigame_button_pressed.bind(icon_index, wedge_index))
		_apply_wedge_status_effects(wedge, status, wedge_index)

	for line_points: PackedVector2Array in _get_divider_segments(minigame_count):
		var divider: Line2D = Line2D.new()
		divider.width = WHEEL_DIVIDER_WIDTH
		divider.default_color = current_garden.wheel_background
		divider.points = line_points
		wedges_container.add_child(divider)

	_draw_next_to_play_highlight(lesson_unlocks, minigame_count)


func _next_to_play_wedge_index(lesson_unlocks: Dictionary) -> int:
	if lesson_unlocks["look_and_learn"] != StudentProgression.Status.COMPLETED:
		return -1
	var games: Array = lesson_unlocks["games"]
	for index: int in range(games.size()):
		if games[index] == StudentProgression.Status.UNLOCKED:
			return index
	return -1


func _draw_next_to_play_highlight(lesson_unlocks: Dictionary, minigame_count: int) -> void:
	# L&L's "next to play" cue is the lesson-button outline color swap, handled
	# in _configure_lesson_button_outline(). Wedges get a separate gold ring here.
	var wedge_index: int = _next_to_play_wedge_index(lesson_unlocks)
	if wedge_index < 0:
		return
	_draw_wedge_highlight(minigame_count, wedge_index)


func _draw_wedge_highlight(minigame_count: int, wedge_index: int) -> void:
	_add_highlight_line(_generate_wedge_highlight_polygon(minigame_count, wedge_index))


# Adds a gold outline tracing the given polygon to the wheel. The polyline is
# closed automatically. z_index lifts the line above Branches; LessonButton's
# higher z_index keeps it on top in turn.
func _add_highlight_line(polygon_points: PackedVector2Array) -> void:
	if polygon_points.is_empty():
		return
	var outline: PackedVector2Array = PackedVector2Array(polygon_points)
	outline.append(polygon_points[0])
	var line: Line2D = Line2D.new()
	line.width = WHEEL_HIGHLIGHT_WIDTH
	line.default_color = Garden.WHEEL_HIGHLIGHT
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = outline
	line.z_index = 5
	wedges_container.add_child(line)


func _wedge_color_for_status(status: StudentProgression.Status) -> Color:
	match status:
		StudentProgression.Status.LOCKED:
			return Garden.WHEEL_WEDGE_LOCKED
		_:
			return current_garden.wheel_wedge_unlocked


# Animal body tint: gray when locked, garden's signature color otherwise.
func _body_color_for_status(status: StudentProgression.Status) -> Color:
	if status == StudentProgression.Status.LOCKED:
		return Garden.ANIMAL_LOCKED_COLOR
	return current_garden.animal_unlocked_color


func _apply_wedge_status_effects(wedge: MinigameWedge, status: StudentProgression.Status, wedge_index: int) -> void:
	if status != StudentProgression.Status.COMPLETED:
		return
	if not transition_data \
			or not transition_data.get("minigame_completed", false) \
			or transition_data.get("minigame_number", -1) != wedge_index \
			or not transition_data.get("first_clear", false):
		return
	await minigame_layout_opened
	wedge.right()


func _open_minigames_layout(button: LessonButton, lesson_number: int) -> void:
	if in_minigame_selection or not UserDataManager.student_progression:
		return
	var exercises: Array[int] = Database.get_exercise_for_lesson(lesson_number)
	if exercises.is_empty():
		Log.error("Gardens: Cannot open minigame layout for lesson %d: no minigames defined" % lesson_number)
		return
	feedback_audio_stream_player2.pitch_scale = 1.1
	feedback_audio_stream_player2.play()
	in_minigame_selection = true
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
	# Deactivate the mouse filters on the buttons behind the layout
	for lesson_button_item: LessonButton in current_garden.get_lesson_buttons():
		lesson_button_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ll_status: StudentProgression.Status = lesson_unlocks["look_and_learn"] as StudentProgression.Status
	background_rect.color = current_garden.wheel_background
	_configure_lesson_button_outline(ll_status)
	_center_lesson_button_label()
	_handle_lesson_button(current_lesson_number, ll_status)
	_build_wheel(exercises, lesson_unlocks)
	# Animations
	minigame_selection.show()
	back_button.hide()
	kalulu_button.hide()
	brain_button.hide()
	line_particles.hide()
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(minigame_selection, "modulate:a", 1.0, 0.25)
	await tween.finished
	minigame_layout_opened.emit()


# Perfectly centers the grapheme label horizontally and drops it just below the
# button center, so it pairs with the movie icon sitting just above. Done in code
# because instanced-scene property overrides on the inherited Label don't survive
# Godot re-saves. This LessonButton is a dedicated wheel instance, so it doesn't
# affect the garden lesson buttons.
func _center_lesson_button_label() -> void:
	var label: Label = lesson_button.label
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = LESSON_BUTTON_LABEL_TOP_OFFSET
	label.offset_bottom = 0.0


func _configure_lesson_button_outline(ll_status: StudentProgression.Status) -> void:
	# Gold when L&L is the next-to-play step (UNLOCKED but not yet COMPLETED),
	# divider color otherwise. Replaces the separate gold ring we used to draw.
	var color: Color = Garden.WHEEL_HIGHLIGHT if ll_status == StudentProgression.Status.UNLOCKED else current_garden.wheel_background
	lesson_button_outline.default_color = color
	var circle_points: PackedVector2Array = _generate_full_disc_polygon(LESSON_BUTTON_OUTLINE_RADIUS)
	if circle_points.size() > 0:
		circle_points.append(circle_points[0])
	lesson_button_outline.points = circle_points


func _handle_lesson_button(lesson_number: int, status: StudentProgression.Status) -> void:
	lesson_button.text = lessons[lesson_number][0].grapheme
	# Center stays the unlocked-wedge color across all states; pair it with the
	# garden's dark color so the label and icon stay readable on it.
	lesson_button.set_garden_colors(
		current_garden.wheel_wedge_unlocked,
		current_garden.unlocked_lesson,
		current_garden.wheel_wedge_unlocked,
		current_garden.unlocked_lesson,
	)
	lesson_button.set_button_disabled(status == StudentProgression.Status.LOCKED)
	lesson_button.completed = status == StudentProgression.Status.COMPLETED
	# Override the hardcoded gray LessonButton uses when disabled, so the L&L
	# center button keeps a uniform background regardless of progression state.
	lesson_button.center.modulate = current_garden.wheel_wedge_unlocked
	lesson_button_particles.emitting = status == StudentProgression.Status.UNLOCKED
	lesson_button_movie_icon.modulate = _lesson_button_label_color(status)
	if status == StudentProgression.Status.COMPLETED:
		if transition_data and transition_data.has("look_and_learn_completed") and transition_data.look_and_learn_completed:
			await minigame_layout_opened
			lesson_button.right()


# Mirrors LessonButton._update_visual_state() so the movie icon tracks the label.
func _lesson_button_label_color(status: StudentProgression.Status) -> Color:
	if status == StudentProgression.Status.LOCKED:
		return LessonButton.LOCKED_LABEL_COLOR
	if status == StudentProgression.Status.COMPLETED:
		return lesson_button.completed_label_color
	return lesson_button.unlocked_label_color


func _get_minigame_scene_path(scene_index: int) -> String:
	if scene_index < 0 or scene_index >= minigame_scene_paths.size():
		return ""
	var scene_path: String = minigame_scene_paths[scene_index]
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return ""
	return scene_path


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
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(minigame_selection, "modulate:a", 0.0, 0.25)
	await tween.finished
	if current_button:
		current_button.show_placeholder(false)
	minigame_selection.hide()
	back_button.show()
	kalulu_button.show()
	brain_button.show()
	line_particles.show()
	for button: LessonButton in current_garden.get_lesson_buttons():
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_wheel()


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
		var garden_scene: PackedScene = load(GARDEN_SCENE_PATHS[layout_index]) as PackedScene
		var garden: Garden = garden_scene.instantiate()
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
	_refresh_cloud_world_bounds()


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
	_refresh_cloud_world_bounds()


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
	SceneLoader.change_scene(LOOK_AND_LEARN_SCENE_PATH)


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
	SceneLoader.change_scene(BOSS_MINIGAME_SCENE_PATH)


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
	SceneLoader.change_scene(BOSS_MINIGAME_SCENE_PATH)


func _on_minigame_button_pressed(scene_index: int, minigame_number: int) -> void:
	if is_locked:
		return
	var scene_path: String = _get_minigame_scene_path(scene_index)
	if scene_path.is_empty():
		Log.error("Gardens: Missing minigame scene for index %d" % scene_index)
		return
	# Block a second wedge click during the curtain-close await below.
	_lock()
	feedback_audio_stream_player.play()
	await (OpeningCurtain as OpeningCurtainClass).close()
	Minigame.transition_data = {
		current_button_global_position = current_button_global_position,
		current_lesson_number = current_lesson_number,
		current_garden_index = current_garden.garden_index,
		minigame_number = minigame_number,
		minigame_completed = false
	}
	SceneLoader.change_scene(scene_path)


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
	SceneLoader.change_scene("res://sources/menus/login/login.tscn")


func _on_brain_button_pressed() -> void:
	await (OpeningCurtain as OpeningCurtainClass).close()
	SceneLoader.change_scene(BRAIN_SCENE_PATH)


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


# BackgroundRect spans the wheel screen with mouse_filter=STOP so it absorbs
# every click that doesn't hit the L&L button (which is on top of it). We
# dispatch the click to the matching wedge via point-in-polygon, or close the
# wheel if the click falls outside every wedge.
func _on_background_rect_gui_input(event: InputEvent) -> void:
	if is_locked or not in_minigame_selection:
		return
	if not event.is_action_pressed("left_click"):
		return
	var click_pos: Vector2 = (event as InputEventMouseButton).position
	for child: Node in wedges_container.get_children():
		if child is MinigameWedge:
			var wedge: MinigameWedge = child
			if Geometry2D.is_point_in_polygon(click_pos, wedge.polygon.polygon):
				# Hit on a wedge — enabled ones launch the minigame; disabled
				# ones play the wrong-click feedback. Either way the click is
				# consumed so the wheel stays open.
				if wedge.is_disabled:
					wedge.wrong()
				else:
					wedge.pressed.emit()
				return
	_close_minigames_layout()


func _on_kalulu_button_pressed() -> void:
	kalulu_button.hide()
	if current_garden.get_progress_ratio() > 0.75:
		await kalulu.play_kalulu_speech(help_many_plants_speech)
	else:
		await kalulu.play_kalulu_speech(help_few_plants_speech)
	kalulu_button.show()

#endregion

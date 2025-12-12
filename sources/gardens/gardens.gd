class_name Gardens
extends Control

signal minigame_layout_opened()

const KALULU: GDScript = preload("res://sources/minigames/base/kalulu.gd")
const GARDEN_SCENE: PackedScene = preload("res://resources/gardens/garden.tscn")
const LOOK_AND_LEARN_SCENE: PackedScene = preload("res://sources/look_and_learn/look_and_learn.tscn")
const FLOWER_VFX: PackedScene = preload("res://sources/gardens/flower_particle.tscn")
const GARDEN_SIZE: int = 2400
const GARDEN_TEXTURES_NB: int = 20
const FLOWER_TYPES_NB: int = 5
const FLOWER_COLORS_NB: int = 20
const FLOWER_OFFSET_FROM_LESSON: float = 200.0
const LESSON_VERTICAL_BASE: float = 920.0
const LESSON_VERTICAL_RANGE: float = 300.0

static var transition_data: Dictionary = {}

@export_category("Layout")
@export var gardens_layout: GardensLayout:
	set = set_gardens_layout
@export var starting_garden: int = -1
@export_category("Colors")
@export var unlocked_color: Color = Color("1c2662") #blue
@export var locked_color: Color = Color("1d2229") #black
@export_group("Minigames")
@export var minigames_scenes: Array[PackedScene] = []
@export var minigames_icons: Array[Texture] = []

var lessons: Dictionary = {}
var points: Array[Array] = []
var is_scrolling: bool = false
var scroll_beginning_garden: int = 0
var scroll_tween: Tween
var is_locked: bool = false
var in_minigame_selection: bool = false
var current_lesson_number: int = -1
var current_garden: Garden
var current_button_global_position: Vector2 = Vector2.ZERO
var current_button: LessonButton
var lesson_to_flower_index: Dictionary = {}

@onready var garden_parent: HBoxContainer = %GardenParent
@onready var locked_line: Line2D = $ScrollContainer/LockedLine
@onready var unlocked_line: Line2D = $ScrollContainer/UnlockedLine
@onready var line_particles: GPUParticles2D = %LineParticles
@onready var line_audio_stream_player: AudioStreamPlayer2D = %LineAudioStreamPlayer
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var parallax_background: ParallaxBackground = %ParallaxBackground
@onready var minigame_selection: Control = %MinigameSelection
@onready var lesson_button: LessonButton = %LessonButton
@onready var lesson_button_particles: GPUParticles2D = %LessonButtonParticles
@onready var back_button: TextureButton = %BackButton
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
@onready var intro_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "intro"))
@onready var help_few_plants_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "help_few_plants"))
@onready var help_many_plants_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "help_many_plants"))


func _ready() -> void:
	
	# Gets the lessons of the current language pack
	Database.db.query("SELECT Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		ORDER BY LessonNb")
	for element: Dictionary in Database.db.query_result:
		if not lessons.has(element.LessonNb):
			lessons[element.LessonNb] = []
		var lesson_array: Array = lessons[element.LessonNb]
		lesson_array.append({grapheme = element.Grapheme, phoneme = element.Phoneme, gp_id = element.GPID})
	
	gardens_layout = generate_gardens_layout(lessons.size())
	set_gardens_layout(gardens_layout)
	
	# Setups the lessons
	_set_up_lessons()
	
	# If there is no data, skips the rest
	if not UserDataManager.student_progression:
		await OpeningCurtain.open()
		return
	
	await get_tree().process_frame
	
	_lock()
	
	lesson_to_flower_index.clear()
	
	# Transition variables #
	
	# The maximum unlocked lesson by the player
	var max_unlocked_lesson: int = UserDataManager.student_progression.get_max_unlocked_lesson_index() + 1
	
	# Defines if the last played minigame or lookandlearn is of the last available lesson
	var is_current_lesson: bool = transition_data and transition_data.current_lesson_number == max_unlocked_lesson
	
	# Defines if a minigame was just completed
	var is_minigame_completed: bool = transition_data.has("minigame_completed") and transition_data.minigame_completed
	
	# Defines if the minigame or lookandlearn cleared is for the first time
	var is_first_clear: bool = transition_data and transition_data.has("first_clear") and transition_data.first_clear
	
	# Defines if a new lesson has been unlocked by the player, setups to play the right animation
	var new_lesson_unlocked: bool = transition_data and transition_data.current_lesson_number == UserDataManager.student_progression.get_max_unlocked_lesson_index() and transition_data.has("minigame_completed") and transition_data.minigame_completed and UserDataManager.student_progression.is_lesson_completed(transition_data.current_lesson_number as int)
	
#region Progression

	# Loads the progression of the player without the newly unlocked stuff from the transition data
	var lesson_ind: int = 1
	
	# Go through each garden
	for garden_control: Garden in garden_parent.get_children():
		
		# Handles the lesson buttons and calculate the progression of the garden
		for index: int in range(garden_control.get_lesson_buttons().size()):
			var button: LessonButton = garden_control.get_lesson_buttons()[index]
			if not lesson_ind in lessons:
				button.set_disabled(true)
				if index < garden_control.flowers_visible.size():
					garden_control.flowers_visible[index] = false
				continue
			
			lesson_to_flower_index[lesson_ind] = {"garden": garden_control, "index": index}
			var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[lesson_ind]
			var is_lesson_unlocked: bool = lesson_unlocks["look_and_learn"] != StudentProgression.Status.Locked
			button.set_disabled(not is_lesson_unlocked)
			if index < garden_control.flowers_visible.size():
				garden_control.flowers_visible[index] = is_lesson_unlocked
			
			# If we just unlocked the new lesson, leave the button disabled
			if new_lesson_unlocked and lesson_ind == max_unlocked_lesson:
				button.set_disabled(true)
			
			if not(new_lesson_unlocked and lesson_ind == max_unlocked_lesson - 1):
				button.completed = UserDataManager.student_progression.is_lesson_completed(lesson_ind)
			
			var completed_minigames: int = _count_completed_minigames(lesson_ind)
			if is_current_lesson and is_first_clear and is_minigame_completed and transition_data.has("minigame_number") and transition_data.minigame_number < (lesson_unlocks["games"] as Array).size():
				if lesson_unlocks["games"][transition_data.minigame_number] == StudentProgression.Status.Completed:
					completed_minigames = max(0, completed_minigames - 1)

			if index < garden_control.flowers_sizes.size():
				garden_control.flowers_sizes[index] = _get_flower_size_for_completion(completed_minigames)
			
			lesson_ind += 1
		
		garden_control.update_flowers()
#endregion

#region Scroll

	# Scrolls to the right garden
	if not transition_data:
		if starting_garden == -1:
			lesson_ind = 1
			for garden_ind: int in range(garden_parent.get_child_count()):
				var garden_control: Garden = garden_parent.get_child(garden_ind)
				if starting_garden != -1:
					break
				if not lesson_ind in lessons:
					break
				for index: int in range(garden_control.get_lesson_buttons().size()):
					if not lesson_ind in lessons:
						break
					
					if UserDataManager.student_progression:
						var unlock: Dictionary = UserDataManager.student_progression.unlocks[lesson_ind]
						
						var look_and_learn_unlocked: bool = unlock["look_and_learn"] == StudentProgression.Status.Unlocked
						var exercise_unlock_1: bool = unlock["games"][0] == StudentProgression.Status.Unlocked
						var exercise_unlock_2: bool = unlock["games"][1] == StudentProgression.Status.Unlocked
						var exercise_unlock_3: bool = unlock["games"][2] == StudentProgression.Status.Unlocked
						if look_and_learn_unlocked or exercise_unlock_1 or exercise_unlock_2 or exercise_unlock_3:
							starting_garden = garden_ind
							break
	else:
		if transition_data.has("current_garden_index"):
			starting_garden = transition_data.current_garden_index
		else:
			Log.error("Gardens: Ready: The transition_data exists but does not contains the needed current_garden_index")
			starting_garden = 0
	
	scroll_container.scroll_horizontal = GARDEN_SIZE * starting_garden
	scroll_beginning_garden = int(float(scroll_container.scroll_horizontal) / GARDEN_SIZE)
	
	current_garden = garden_parent.get_child(starting_garden)
	
#endregion

	await OpeningCurtain.open()
	MusicManager.play(MusicManager.Track.Garden)
	
	# Handles all the animation played when entering the gardens
	if transition_data:
		
		# Wait for the next frame to avoid glittering
		await get_tree().process_frame
		
#region Flowers animation

		# Play the flowers animation if needed
		if is_current_lesson and is_first_clear and is_minigame_completed and transition_data.has("current_lesson_number"):
			
			# Wait a bit before any action to smooth the animations
			await get_tree().create_timer(1).timeout
			var lesson_number: int = transition_data.current_lesson_number as int
			var flower_info: Dictionary = lesson_to_flower_index.get(lesson_number, {})
			if flower_info and flower_info.has("garden") and flower_info.has("index"):
				var target_garden: Garden = flower_info.garden
				var target_index: int = flower_info.index
				var new_completed_count: int = _count_completed_minigames(lesson_number)
				var target_size: Garden.FlowerSizes = _get_flower_size_for_completion(new_completed_count)
				var current_size: Garden.FlowerSizes = target_garden.flowers_sizes[target_index]
				target_garden.flowers_visible[target_index] = true

				if target_size != current_size:
			
					var flower_vfx: FlowerVFX = FLOWER_VFX.instantiate()
					target_garden.flower_controls[target_index].add_child(flower_vfx)
					flower_vfx.anchor_bottom = 0.5
					flower_vfx.anchor_top = 0.5
					flower_vfx.anchor_left = 0.5
					flower_vfx.anchor_right = 0.5
					
					flower_vfx.play()
					await get_tree().create_timer(0.5).timeout
					target_garden.flowers_sizes[target_index] = target_size
					target_garden.update_flowers()
#endregion
		
		# Wait a bit before any action to smooth the animations
		await get_tree().create_timer(1).timeout
		
		# Re-open the minigames layout
		await _open_minigames_layout(_get_current_lesson_button(transition_data.current_lesson_number as int), transition_data.current_lesson_number as int)
		
#region New lesson unlocked

		if new_lesson_unlocked:
			var max_lesson: int = UserDataManager.student_progression.get_max_unlocked_lesson_index()
			# Close the layout
			await get_tree().create_timer(2).timeout
			await _close_minigames_layout()
			
			# Path towards the next lesson
			lesson_ind = 1
			var last_lesson_button: LessonButton
			var new_lesson_button: LessonButton
			var is_last_lesson_of_garden: bool = false
			for garden_control: Garden in garden_parent.get_children():
				for index: int in range(garden_control.get_lesson_buttons().size()):
					if lesson_ind == max_lesson + 1:
						new_lesson_button = garden_control.get_lesson_buttons()[index]
					if lesson_ind == max_lesson:
						last_lesson_button = garden_control.get_lesson_buttons()[index]
						if index == garden_control.get_lesson_buttons().size() -1:
							is_last_lesson_of_garden = true
					if last_lesson_button and new_lesson_button:
						break
					lesson_ind += 1
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
				
				scroll_beginning_garden = int(float(target_scroll) / GARDEN_SIZE)
				
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
				new_lesson_button.set_disabled(false)
	
#endregion
	
	# Unlock the interface
	_unlock()
	
	# Empty the transition data
	transition_data = {}
	
	# Play the tutorial if needed
	if not UserDataManager.is_speech_played("gardens"):
		kalulu_button.hide()
		await kalulu.play_kalulu_speech(intro_speech)
		kalulu_button.show()
		UserDataManager.mark_speech_as_played("gardens")


static func compute_lessons_distribution(total_lessons: int, garden_layouts: Array[GardenLayout]) -> Array[int]:
	Log.info("Gardens: Computing lessons distribution")
	Log.trace("Gardens: ComputeLessonsDistribution: Parameters total_lessons = %s, garden_layouts count = %s" % [str(total_lessons), str(garden_layouts.size())])
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
	return distribution


static func generate_gardens_layout(total_lessons: int) -> GardensLayout:
	var layout: GardensLayout = GardensLayout.new()
	if total_lessons <= 0:
		return layout
	Log.info("Gardens: Generating dynamic gardens layout")
	Log.trace("Gardens: Total lessons to layout: %s" % str(total_lessons))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 13985
	Log.trace("Gardens: RNG seeded with %s" % str(rng.seed))
	var lessons_left: int = total_lessons
	var garden_index: int = 0
	while lessons_left > 0 and garden_index < GARDEN_TEXTURES_NB:
		var gardens_left: int = GARDEN_TEXTURES_NB - garden_index
		var lessons_for_garden: int = int(ceili(float(lessons_left) / float(gardens_left)))
		Log.trace("Gardens: Generating layout for garden %s with %s lessons left" % [str(garden_index), str(lessons_left)])
		layout.gardens.append(_generate_single_garden_layout(garden_index, lessons_for_garden, rng))
		lessons_left -= lessons_for_garden
		Log.trace("Gardens: Lessons left after garden %s generation: %s" % [str(garden_index), str(lessons_left)])
		garden_index += 1
	Log.info("Gardens: Completed layout generation with %s gardens" % str(layout.gardens.size()))
	return layout


static func _generate_single_garden_layout(garden_index: int, lessons_for_garden: int, rng: RandomNumberGenerator) -> GardenLayout:
	Log.info("Gardens: Generating single garden layout for garden %s" % str(garden_index))
	Log.trace("Gardens: Garden %s will include %s lessons" % [str(garden_index), str(lessons_for_garden)])
	var garden_layout: GardenLayout = GardenLayout.new()
	garden_layout.color = garden_index % GARDEN_TEXTURES_NB
	Log.trace("Gardens: Garden %s color index set to %s" % [str(garden_index), str(garden_layout.color)])
	var lesson_positions: Array[Vector2i] = _generate_lesson_positions(lessons_for_garden, garden_index)
	var lesson_buttons: Array[GardenLayout.GardenLayoutLessonButton] = []
	for lesson_index: int in range(lessons_for_garden):
		var lesson_position: Vector2i = lesson_positions[lesson_index]
		Log.trace("Gardens: Garden %s lesson %s position calculated at %s" % [str(garden_index), str(lesson_index), str(lesson_position)])
		var path_out: Vector2i = Vector2i.ZERO
		if lesson_index + 1 < lesson_positions.size():
			var next_position: Vector2i = lesson_positions[lesson_index + 1]
			var tangent: Vector2 = (next_position - lesson_position) * 0.5
			Log.trace("Gardens: Garden %s lesson %s tangent to next lesson: %s" % [str(garden_index), str(lesson_index), str(tangent)])
			path_out = Vector2i(int(tangent.x), int(tangent.y))
		else:
			path_out = Vector2i(int(GARDEN_SIZE * 0.15), int((-1.0 if (garden_index % 2) == 0 else 1.0) * 60))
			Log.trace("Gardens: Garden %s last lesson %s path out set to %s" % [str(garden_index), str(lesson_index), str(path_out)])
		lesson_buttons.append(GardenLayout.GardenLayoutLessonButton.new(lesson_position, path_out))
	garden_layout.lesson_buttons = lesson_buttons
	var flowers: Array[GardenLayout.Flower] = []
	for lesson_index: int in range(lesson_positions.size()):
		var flower_position: Vector2i = lesson_positions[lesson_index]
		flower_position.y = max(0, flower_position.y - int(FLOWER_OFFSET_FROM_LESSON))
		var flower_color: int = (garden_layout.color + lesson_index) % FLOWER_COLORS_NB
		var flower_type: int = (lesson_index + garden_index + rng.randi_range(0, FLOWER_TYPES_NB - 1)) % FLOWER_TYPES_NB
		Log.trace("Gardens: Garden %s flower %s position (%s,%s), color %s, type %s" % [str(garden_index), str(lesson_index), str(flower_position.x), str(flower_position.y), str(flower_color), str(flower_type)])
		flowers.append(GardenLayout.Flower.new(flower_color, flower_type, flower_position))
	garden_layout.flowers = flowers
	Log.info("Gardens: Finished generating garden layout for garden %s" % str(garden_index))
	return garden_layout


static func _generate_lesson_positions(lessons_for_garden: int, garden_index: int) -> Array[Vector2i]:
	Log.info("Gardens: Generating lesson positions for garden %s" % str(garden_index))
	var positions: Array[Vector2i] = []
	if lessons_for_garden <= 0:
		Log.trace("Gardens: No lessons for garden %s, returning empty positions" % str(garden_index))
		return positions
	var spacing: float = float(GARDEN_SIZE) / float(lessons_for_garden + 1)
	Log.trace("Gardens: Garden %s lesson spacing calculated as %s" % [str(garden_index), str(spacing)])
	var vertical_phase: float = float(garden_index % 3) * 0.65
	Log.trace("Gardens: Garden %s vertical phase set to %s" % [str(garden_index), str(vertical_phase)])
	for lesson_index: int in range(lessons_for_garden):
		var x: int = int(spacing * float(lesson_index + 1))
		var wave_position: float = float(lesson_index) / maxf(1.0, lessons_for_garden - 1)
		var y: int = int(LESSON_VERTICAL_BASE + sin(vertical_phase + wave_position * PI) * LESSON_VERTICAL_RANGE)
		Log.trace("Gardens: Garden %s lesson %s position -> x: %s, wave position: %s, y: %s" % [str(garden_index), str(lesson_index), str(x), str(wave_position), str(y)])
		positions.append(Vector2i(x, y))
	Log.info("Gardens: Completed lesson positions for garden %s" % str(garden_index))
	return positions


func _process(_delta: float) -> void:
	locked_line.position.x = - scroll_container.scroll_horizontal
	unlocked_line.position.x = - scroll_container.scroll_horizontal
	parallax_background.scroll_offset.x = - scroll_container.scroll_horizontal


func _open_minigames_layout(button: LessonButton, lesson_ind: int) -> void:
	if in_minigame_selection or not UserDataManager.student_progression:
		return
	
	feedback_audio_stream_player2.pitch_scale = 1.1
	feedback_audio_stream_player2.play()
	
	in_minigame_selection = true
	
	# Gets the correct exercises for the lesson
	var exercises: Array[int] = Database.get_exercise_for_lesson(lesson_ind)
	if not exercises or exercises.size() < 3:
		return
	
	# Sets the variables for the current garden and lesson
	current_lesson_number = lesson_ind
	if button:
		#button_global_position = button.global_position
		current_button = button
		current_button.show_placeholder(true)
	current_button_global_position = button.global_position
	
	# Gets the current lesson unlocks
	var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[current_lesson_number]
	
	var are_minigames_locked: bool = lesson_unlocks["games"][0] == StudentProgression.Status.Locked and lesson_unlocks["games"][1] == StudentProgression.Status.Locked and lesson_unlocks["games"][2] == StudentProgression.Status.Locked
	
	# Deactivate the mouse filters on the buttons behind the layout
	for l_button: LessonButton in current_garden.get_lesson_buttons():
		l_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Background
	if are_minigames_locked:
		minigame_background_center.modulate = locked_color
	else:
		minigame_background_center.modulate = current_garden.color
	
	# Lesson button
	_handle_lesson_button(current_lesson_number, lesson_unlocks["look_and_learn"] as StudentProgression.Status, current_garden.color)
	
	# Minigames
	_fill_minigame_choice(minigame_layout_1, exercises[0], lesson_unlocks["games"][0] as StudentProgression.Status, 0)
	_fill_minigame_choice(minigame_layout_2, exercises[1], lesson_unlocks["games"][1] as StudentProgression.Status, 1)
	_fill_minigame_choice(minigame_layout_3, exercises[2], lesson_unlocks["games"][2] as StudentProgression.Status, 2)
	
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


func _handle_lesson_button(lesson: int, status: StudentProgression.Status, color: Color) -> void:
	lesson_button.text = lessons[lesson][0].grapheme
	lesson_button.completed_color = color
	
	lesson_button.set_disabled(status == StudentProgression.Status.Locked)
	lesson_button.completed = status == StudentProgression.Status.Completed
	lesson_button_particles.emitting = status == StudentProgression.Status.Unlocked
	
	if status == StudentProgression.Status.Completed:
		if transition_data and transition_data.has("look_and_learn_completed") and transition_data.look_and_learn_completed:
			await minigame_layout_opened
			lesson_button.right()


func _fill_minigame_choice(layout: MinigameLayout, exercise_type: int, status: StudentProgression.Status, minigame_number: int) -> void:
	
	layout.icon.texture = minigames_icons[exercise_type-1]
	layout.is_disabled = status == StudentProgression.Status.Locked
	
	if status == StudentProgression.Status.Completed:
		if transition_data and transition_data.has("minigame_completed") and transition_data.minigame_completed and transition_data.has("minigame_number") and transition_data.minigame_number == minigame_number and transition_data.has("first_clear") and transition_data.first_clear:
			layout.self_modulate = unlocked_color
			await minigame_layout_opened
			create_tween().tween_property(layout, "self_modulate:a", 0, 0.5)
			layout.right()
		else:
			layout.self_modulate.a = 0
			
	elif status == StudentProgression.Status.Locked:
		layout.self_modulate = locked_color
	else:
		layout.self_modulate = unlocked_color

	layout.pressed.connect(_on_minigame_button_pressed.bind(minigames_scenes[exercise_type-1], minigame_number))


func _count_completed_minigames(lesson_ind: int) -> int:
	if not UserDataManager.student_progression or not UserDataManager.student_progression.unlocks.has(lesson_ind):
		return 0
	var completed: int = 0
	for game_status: int in UserDataManager.student_progression.unlocks[lesson_ind]["games"]:
		if game_status == StudentProgression.Status.Completed:
			completed += 1
	return completed

func _get_flower_size_for_completion(completed_minigames: int) -> Garden.FlowerSizes:
	match completed_minigames:
		1:
			return Garden.FlowerSizes.SMALL
		2:
			return Garden.FlowerSizes.MEDIUM
		3:
			return Garden.FlowerSizes.LARGE
		_:
			return Garden.FlowerSizes.NOT_STARTED


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
	
	minigame_layout_1.pressed.disconnect(_on_minigame_button_pressed)
	minigame_layout_2.pressed.disconnect(_on_minigame_button_pressed)
	minigame_layout_3.pressed.disconnect(_on_minigame_button_pressed)


func _set_up_lessons() -> void:
	var lesson_ind: int = 1
	for garden_ind: int in range(garden_parent.get_child_count()):
		var garden_control: Garden = garden_parent.get_child(garden_ind)
		var button_count: int = garden_control.garden_layout.lesson_buttons.size()
		for index: int in range(button_count):
			if not lesson_ind in lessons:
				break
			garden_control.set_lesson_label(index, lessons[lesson_ind][0].grapheme as String)
			garden_control.get_lesson_buttons()[index].pressed.connect(_on_garden_lesson_button_pressed.bind(garden_control.get_lesson_buttons()[index], lesson_ind))
			lesson_ind += 1


func set_gardens_layout(p_gardens_layout: GardensLayout) -> void:
	Log.info("Gardens: Setting gardens layout")
	gardens_layout = p_gardens_layout
	Log.trace("Gardens: Layout contains %s gardens" % str(gardens_layout.gardens.size()))
	add_gardens()
	if garden_parent:
		Log.trace("Gardens: Yielding a frame to ensure garden controls are ready before setting up the path")
		await get_tree().process_frame
	set_up_path()


func add_gardens() -> void:
	if not garden_parent:
		return
	# Removes old gardens
	Log.info("Gardens: Clearing existing gardens before generation")
	for child: Node in garden_parent.get_children():
		child.free()
	Log.info("Gardens: Computing lesson distribution for new gardens")
	var distribution: Array[int] = compute_lessons_distribution(lessons.size(), gardens_layout.gardens)
	var garden_index: int = 0
	for layout_index: int in range(gardens_layout.gardens.size()):
		Log.trace("Gardens: Preparing garden %s with layout index %s" % [str(garden_index), str(layout_index)])
		var garden_layout: GardenLayout = gardens_layout.gardens[layout_index]
		var garden: Garden = GARDEN_SCENE.instantiate()
		garden_parent.add_child(garden)
		garden.garden_index = garden_index
		garden_index += 1
		var lessons_for_garden: int = distribution[layout_index]
		Log.trace("Gardens: Garden %s will host %s lessons" % [str(garden.garden_index), str(lessons_for_garden)])
		garden_layout.lesson_buttons.resize(lessons_for_garden)
		Log.trace("Gardens: Assigning layout to garden %s" % str(garden.garden_index))
		garden.garden_layout = garden_layout


func set_up_path() -> void:
	if not garden_parent:
		return
	
	points = []
	var curve: Curve2D = Curve2D.new()
	
	for index: int in range(gardens_layout.gardens.size()):
		if index >= garden_parent.get_child_count():
			break
		var garden_layout: GardenLayout = gardens_layout.gardens[index]
		var garden_control: Garden = garden_parent.get_child(index)
		for button: GardenLayout.GardenLayoutLessonButton in garden_layout.lesson_buttons:
			var point_position: Vector2 = garden_parent.position + garden_control.position + Vector2(button.position)
			point_position += garden_control.get_button_size() / 2
			var point_in_position: Vector2 = Vector2.ZERO
			if curve.point_count > 1:
				point_in_position = curve.get_point_position(curve.point_count - 1) + curve.get_point_out(curve.point_count - 1) - point_position
			curve.add_point(point_position, point_in_position, button.path_out_position)
			points.append([point_position, point_in_position, button.path_out_position])
	locked_line.points = curve.get_baked_points()


func _lock() -> void:
	is_locked = true
	lock.show()


func _unlock() -> void:
	is_locked = false
	lock.hide()


func _get_current_lesson_button(lesson: int) -> LessonButton:
	var lesson_ind: int = 1
	for garden_control: Garden in garden_parent.get_children():
		for index: int in range(garden_control.get_lesson_buttons().size()):
			if lesson_ind == lesson:
				return garden_control.get_lesson_buttons()[index]
			lesson_ind += 1
	return null


func _on_garden_lesson_button_pressed(button: LessonButton, lesson_ind: int) -> void:
	_open_minigames_layout(button, lesson_ind)


func _on_lesson_button_pressed() -> void:
	if is_locked:
		return
		
	feedback_audio_stream_player.play()
	await OpeningCurtain.close()
	
	LookAndLearn.transition_data = {
		current_button_global_position = current_button_global_position,
		current_lesson_number = current_lesson_number,
		current_garden_index = current_garden.garden_index,
		look_and_learn_completed = false
	}
	get_tree().change_scene_to_packed(LOOK_AND_LEARN_SCENE)


func _on_minigame_button_pressed(minigame_scene: PackedScene, minigame_number: int) -> void:
	if is_locked:
		return
	
	feedback_audio_stream_player.play()
	await OpeningCurtain.close()
	
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
	if event.is_action_pressed("left_click"):
		is_scrolling = true
		scroll_beginning_garden = int(float(scroll_container.scroll_horizontal) / GARDEN_SIZE)
		if scroll_tween:
			scroll_tween.stop()
			scroll_tween = null
	elif event.is_action_released("left_click"):
		is_scrolling = false
		var shift_value: int = scroll_container.scroll_horizontal - scroll_beginning_garden * GARDEN_SIZE
		var target_scroll: int = scroll_beginning_garden * GARDEN_SIZE
		var is_garden_changed: bool = false
		if shift_value < - 400:
			target_scroll -= GARDEN_SIZE
			is_garden_changed = true
			left_audio_stream_player.play()
		elif shift_value > 400:
			target_scroll += GARDEN_SIZE
			is_garden_changed = true
			right_audio_stream_player.play()
		scroll_tween = create_tween()
		scroll_tween.set_ease(Tween.EASE_OUT)
		scroll_tween.set_trans(Tween.TRANS_SPRING)
		scroll_tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 1)
		if is_garden_changed:
			current_garden = garden_parent.get_child(int(float(target_scroll) / GARDEN_SIZE))
			current_garden.pop_animation()
		
		await scroll_tween.finished
		scroll_beginning_garden = int(float(scroll_container.scroll_horizontal) / GARDEN_SIZE)
		
	if is_scrolling and event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		scroll_container.scroll_horizontal -= int(motion_event.relative.x)


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	get_tree().change_scene_to_file("res://sources/menus/brain/brain.tscn")


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

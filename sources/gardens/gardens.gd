extends Control
signal minigame_layout_opened()

# Namespace
const LookAndLearn: = preload("res://sources/look_and_learn/look_and_learn.gd")
const LessonButton: = preload("res://sources/lesson_screen/lesson_button.gd")
const MinigameLayout: = preload("res://sources/gardens/minigame_layout.gd")
const Kalulu: = preload("res://sources/minigames/base/kalulu.gd")

const garden_scene: PackedScene = preload("res://resources/gardens/garden.tscn")
const look_and_learn_scene: PackedScene = preload("res://sources/look_and_learn/look_and_learn.tscn")
const flower_fvx: PackedScene = preload("res://sources/gardens/flower_particle.tscn")

const garden_size: int = 2400

@export_category("Layout")
@export var gardens_layout: GardensLayout:
	set = set_gardens_layout
@export var starting_garden: int = -1

@export_category("Colors")
@export var unlocked_color: Color = Color("1c2662") #blue
@export var locked_color: Color = Color("1d2229") #black

@export_group("Minigames")
@export var minigames_scenes: Array[PackedScene]
@export var minigames_icons: Array[Texture]

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
@onready var kalulu: Kalulu = %Kalulu
@onready var kalulu_button: CanvasItem = %KaluluButton

@onready var intro_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "intro"))
@onready var help_few_plants_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "help_few_plants"))
@onready var help_many_plants_speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path("gardens_screen", "help_many_plants"))

var lessons: Dictionary
var points: Array[Array]
var is_scrolling: bool = false
var scroll_beginning_garden: int = 0
var scroll_tween: Tween
var is_locked: bool = false

var in_minigame_selection: bool = false
var current_lesson_number: int = -1
var current_garden: Garden
var current_button_global_position: Vector2 = Vector2.ZERO
var current_button: LessonButton

static var transition_data: Dictionary


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
	
	# Loads the layout
	if not gardens_layout:
		gardens_layout = load("res://resources/gardens/gardens_layout.tres")
	else:
		set_gardens_layout(gardens_layout)
	
	# Setups the lessons
	_set_up_lessons()
	
	# If there is no data, skips the rest
	if not UserDataManager.student_progression:
		await OpeningCurtain.open()
		return
	
	await get_tree().process_frame
	
	_lock()
	
	# Transition variables #
	
	# The maximum unlocked lesson by the player
	var max_unlocked_lesson: int = UserDataManager.student_progression.get_max_unlocked_lesson() + 1
	
	# Defines if the last played minigame or lookandlearn is of the last available lesson
	var is_current_lesson: bool = transition_data and transition_data.current_lesson_number == max_unlocked_lesson
	
	# Defines if a look and learn was just completed
	var is_look_and_learn_completed: bool = transition_data.has("look_and_learn_completed") and transition_data.look_and_learn_completed
	
	# Defines if a minigame was just completed
	var is_minigame_completed: bool = transition_data.has("look_and_learn_completed") and transition_data.look_and_learn_completed
	
	# Defines if the minigame or lookandlearn cleared is for the first time
	var is_first_clear: bool = transition_data and transition_data.has("first_clear") and transition_data.first_clear
	
	# Defines if a new lesson has been unlocked by the player, setups to play the right animation
	var new_lesson_unlocked: bool = transition_data and transition_data.current_lesson_number == UserDataManager.student_progression.get_max_unlocked_lesson() and transition_data.has("minigame_number") && transition_data.minigame_number == 2 and transition_data.minigame_completed
	
#region Progression

	# Loads the progression of the player without the newly unlocked stuff from the transition data
	var lesson_ind: int = 1
	
	# Go through each garden
	for garden_control: Garden in garden_parent.get_children():
		
		# Handles the lesson buttons and calculate the progression of the garden
		for index: int in garden_control.lesson_button_controls.size():
			var button: LessonButton = garden_control.lesson_button_controls[index]
			if not lesson_ind in lessons:
				button.disabled = true
				continue
			
			# Adds the max progression of the look and learn
			garden_control.max_progression += 2.0
			
			if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] >= UserProgression.Status.Unlocked:
				match UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"]:
					UserProgression.Status.Unlocked:
						garden_control.current_progression += 1.0
					UserProgression.Status.Completed:
						garden_control.current_progression += 2.0
				button.disabled = false
			else:
				button.disabled = true
			
			# If we just unlocked the new lesson, leave the button disabled
			if new_lesson_unlocked and lesson_ind == max_unlocked_lesson:
				button.disabled = true
			
			# Remove the completion if the look and learn was just completed for the first time
			if is_look_and_learn_completed and is_first_clear:
				garden_control.current_progression -= 1
			
			if not(new_lesson_unlocked and lesson_ind == max_unlocked_lesson - 1):
				button.completed = UserDataManager.student_progression.is_lesson_completed(lesson_ind)
			
			# Handles progression of the minigames
			for k: int in range(3):
				garden_control.max_progression += 2.0
				match UserDataManager.student_progression.unlocks[lesson_ind]["games"][k]:
					UserProgression.Status.Unlocked:
						garden_control.current_progression += 1.0
					UserProgression.Status.Completed:
						garden_control.current_progression += 2.0
				
				# Remove the completion if the minigame was just completed for the first time
				if lesson_ind == max_unlocked_lesson and is_first_clear and is_minigame_completed and transition_data.has("minigame_number") and transition_data.minigame_number == k:
					garden_control.current_progression -= 1
			
			lesson_ind += 1
		
		# Handles the flowers
		var total_flowers: float = garden_control.get_progress_ratio() * garden_control.flower_controls.size() * 3.0
		var flower_ind: int = 0
		
		while total_flowers > 0 and flower_ind < garden_control.flower_controls.size():
			if total_flowers >= 3.0:
				garden_control.flowers_sizes[flower_ind] = Garden.FlowerSizes.Large
				total_flowers -= 3.0
			elif total_flowers >= 2.0:
				garden_control.flowers_sizes[flower_ind] = Garden.FlowerSizes.Medium
				total_flowers -= 2.0
			elif total_flowers >= 1.0:
				garden_control.flowers_sizes[flower_ind] = Garden.FlowerSizes.Small
				total_flowers -= 1.0
			flower_ind += 1
		garden_control.update_flowers()
	
	# Handles the path
	var curve: Curve2D = Curve2D.new()
	var max_lesson: int = UserDataManager.student_progression.get_max_unlocked_lesson()
	if not new_lesson_unlocked:
		max_lesson += 1
	
	for index: int in range(max_lesson):
		curve.add_point(points[index][0] as Vector2, points[index][1] as Vector2, points[index][2] as Vector2)
	unlocked_line.points = curve.get_baked_points()
	
	line_particles.global_position = unlocked_line.points[unlocked_line.points.size()-1]

#endregion
	
#region Scroll

	# Scrolls to the right garden
	if not transition_data:
		if starting_garden == -1:
			lesson_ind = 1
			for garden_ind: int in garden_parent.get_child_count():
				var garden_control: Garden = garden_parent.get_child(garden_ind)
				if starting_garden != -1:
					break
				if not lesson_ind in lessons:
					break
				for index: int in garden_control.lesson_button_controls.size():
					if not lesson_ind in lessons:
						break
					
					if UserDataManager.student_progression:
						var unlock: Dictionary = UserDataManager.student_progression.unlocks[lesson_ind]
						
						var look_and_learn_unlocked: bool = unlock["look_and_learn"] == UserProgression.Status.Unlocked
						var exercice_unlock_1: bool = unlock["games"][0] == UserProgression.Status.Unlocked
						var exercice_unlock_2: bool = unlock["games"][1] == UserProgression.Status.Unlocked
						var exercice_unlock_3: bool = unlock["games"][2] == UserProgression.Status.Unlocked
						if look_and_learn_unlocked or exercice_unlock_1 or exercice_unlock_2 or exercice_unlock_3:
							starting_garden = garden_ind
							break
	else:
		if transition_data.has("current_garden_index"):
			starting_garden = transition_data.current_garden_index
		else:
			Logger.error("Gardens: initialisation: transition_data exists but does not contains the needed current_garden_index")
			starting_garden = 0
	
	scroll_container.scroll_horizontal = garden_size * starting_garden
	@warning_ignore("integer_division")
	scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
	
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
		if is_current_lesson and is_first_clear:
			
			# Wait a bit before any action to smooth the animations
			await get_tree().create_timer(1).timeout
			
			# Calculate the progression of the garden
			current_garden.current_progression += 1
			
			var unlocks_ratio: float = current_garden.current_progression / current_garden.max_progression
			var total_flowers: float = unlocks_ratio * current_garden.flower_controls.size() * 3.0
			var flower_ind: int = 0
			while total_flowers > 0 and flower_ind < current_garden.flower_controls.size():
				var play_animation: bool = false
				if total_flowers >= 3.0 and current_garden.flowers_sizes[flower_ind] != Garden.FlowerSizes.Large:
					current_garden.flowers_sizes[flower_ind] = Garden.FlowerSizes.Large
					total_flowers -= 3.0
					play_animation = true
				elif total_flowers >= 2.0 and current_garden.flowers_sizes[flower_ind] != Garden.FlowerSizes.Medium:
					current_garden.flowers_sizes[flower_ind] = Garden.FlowerSizes.Medium
					total_flowers -= 2.0
					play_animation = true
				elif total_flowers >= 1.0 and current_garden.flowers_sizes[flower_ind] != Garden.FlowerSizes.Small:
					current_garden.flowers_sizes[flower_ind] = Garden.FlowerSizes.Small
					total_flowers -= 1.0
					play_animation = true
				
				if play_animation:
					var fvfx: FlowerVFX = flower_fvx.instantiate()
					current_garden.flower_controls[flower_ind].add_child(fvfx)
					fvfx.anchor_bottom = 0.5
					fvfx.anchor_top = 0.5
					fvfx.anchor_left = 0.5
					fvfx.anchor_right = 0.5
					
					fvfx.play()
					await get_tree().create_timer(0.5).timeout
					current_garden.update_flowers()
				
				flower_ind += 1
			
#endregion
		
		# Wait a bit before any action to smooth the animations
		await get_tree().create_timer(1).timeout
		
		# Re-open the minigames layout
		await _open_minigames_layout(_get_current_lesson_button(transition_data.current_lesson_number as int), transition_data.current_lesson_number as int)
		
#region New lesson unlocked

		if new_lesson_unlocked:
			
			# Close the layout
			await get_tree().create_timer(2).timeout
			await _close_minigames_layout()
			
			# Path towards the next lesson
			lesson_ind = 1
			var last_lesson_button: LessonButton
			var new_lesson_button: LessonButton
			var is_last_lesson_of_garden: bool = false
			for garden_control: Garden in garden_parent.get_children():
				for index: int in garden_control.lesson_button_controls.size():
					if lesson_ind == max_lesson + 1:
						new_lesson_button = garden_control.lesson_button_controls[index]
					if lesson_ind == max_lesson :
						last_lesson_button = garden_control.lesson_button_controls[index]
						if index == garden_control.lesson_button_controls.size() -1:
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
				@warning_ignore("integer_division")
				scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
				var target_scroll: int = scroll_beginning_garden * garden_size + garden_size
				var tween: Tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 4)
				
				@warning_ignore("integer_division")
				scroll_beginning_garden = target_scroll / garden_size
				
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
				new_lesson_button.disabled = false
	
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
	var exercises: Array[int] = Database.get_exercice_for_lesson(lesson_ind)
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
	
	var are_minigames_locked: bool = lesson_unlocks["games"][0] == UserProgression.Status.Locked and lesson_unlocks["games"][1] == UserProgression.Status.Locked and lesson_unlocks["games"][2] == UserProgression.Status.Locked
	
	# Desactivate the mouse filters on the buttons behind the layout
	for b: LessonButton in current_garden.lesson_button_controls:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Background
	if are_minigames_locked:
		minigame_background_center.modulate = locked_color
	else:
		minigame_background_center.modulate = current_garden.color
	
	# Lesson button
	_handle_lesson_button(current_lesson_number, lesson_unlocks["look_and_learn"] as UserProgression.Status, current_garden.color)
	
	# Minigames
	_fill_minigame_choice(minigame_layout_1, exercises[0], lesson_unlocks["games"][0] as UserProgression.Status, 0)
	_fill_minigame_choice(minigame_layout_2, exercises[1], lesson_unlocks["games"][1] as UserProgression.Status, 1)
	_fill_minigame_choice(minigame_layout_3, exercises[2], lesson_unlocks["games"][2] as UserProgression.Status, 2)
	
	# Animations
	minigame_selection.visible = true
	back_button.visible = false
	kalulu_button.visible = false
	line_particles.visible = false
	
	minigame_background.size = 300.0 * Vector2.ONE
	minigame_background.global_position = current_button_global_position
	minigame_background.visible = true
	
	minigame_background_center.size = 300.0 * Vector2.ONE
	minigame_background_center.global_position = current_button_global_position
	minigame_background_center.visible = true
	
	var tween: Tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(minigame_background_center, "scale", (1800.0 / 300.0) * Vector2.ONE, 0.25)
	tween.tween_property(minigame_background_center, "global_position", Vector2(380.0, 0), 0.25)
	tween.tween_property(minigame_background, "scale", (1800.0 / 300.0) * Vector2.ONE, 0.25)
	tween.tween_property(minigame_background, "global_position", Vector2(380.0, 0), 0.25)
	tween.chain().tween_property(minigame_selection, "modulate:a", 1.0, 0.25)
	await tween.finished
	
	minigame_layout_opened.emit()


func _handle_lesson_button(lesson: int, status: UserProgression.Status, color: Color) -> void:
	lesson_button.text = lessons[lesson][0].grapheme
	lesson_button.completed_color = color
	
	lesson_button.disabled = status == UserProgression.Status.Locked
	lesson_button.completed = status == UserProgression.Status.Completed
	lesson_button_particles.emitting = status == UserProgression.Status.Unlocked
	
	if status == UserProgression.Status.Completed:
		if transition_data and transition_data.has("look_and_learn_completed") and transition_data.look_and_learn_completed:
			await minigame_layout_opened
			lesson_button.right()


func _fill_minigame_choice(layout: MinigameLayout, exercise_type: int, status: UserProgression.Status, minigame_number: int) -> void:
	
	layout.icon.texture = minigames_icons[exercise_type-1]
	layout.is_disabled = status == UserProgression.Status.Locked
	
	if status == UserProgression.Status.Completed:
		if transition_data and transition_data.has("minigame_completed") and transition_data.minigame_completed and transition_data.has("minigame_number") and transition_data.minigame_number == minigame_number and transition_data.has("first_clear") and transition_data.first_clear:
			layout.self_modulate = unlocked_color
			await minigame_layout_opened
			create_tween().tween_property(layout, "self_modulate:a", 0, 0.5)
			layout.right()
		else:
			layout.self_modulate.a = 0
			
	elif status == UserProgression.Status.Locked:
		layout.self_modulate = locked_color
	else:
		layout.self_modulate = unlocked_color

	layout.pressed.connect(_on_minigame_button_pressed.bind(minigames_scenes[exercise_type-1], minigame_number))


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
	
	minigame_selection.visible = false
	minigame_background.visible = false
	minigame_background_center.visible = false
	back_button.visible = true
	kalulu_button.visible = true
	line_particles.visible = true
	
	for button in current_garden.lesson_button_controls:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	minigame_layout_1.pressed.disconnect(_on_minigame_button_pressed)
	minigame_layout_2.pressed.disconnect(_on_minigame_button_pressed)
	minigame_layout_3.pressed.disconnect(_on_minigame_button_pressed)


func _set_up_lessons() -> void:
	var lesson_ind: int = 1
	
	for garden_ind: int in garden_parent.get_child_count():
		
		var garden_control: Garden = garden_parent.get_child(garden_ind)
		
		for index: int in garden_control.lesson_button_controls.size():
			if not lesson_ind in lessons:
				break
			garden_control.set_lesson_label(index, lessons[lesson_ind][0].grapheme as String)
			garden_control.lesson_button_controls[index].pressed.connect(_on_garden_lesson_button_pressed.bind(garden_control.lesson_button_controls[index], lesson_ind))
			lesson_ind += 1


func set_gardens_layout(p_gardens_layout: GardensLayout) -> void:
	gardens_layout = p_gardens_layout
	add_gardens()
	if garden_parent:
		await get_tree().process_frame
	set_up_path()


func add_gardens() -> void:
	if not garden_parent:
		return
	
	# Removes old gardens
	for child: Node in garden_parent.get_children():
		child.free()
	
	# Adds the gardens needed from the layout configuration
	var current_lesson_count: int = 0
	var garden_index: int = 0
	for garden_layout: GardenLayout in gardens_layout.gardens:
		var garden: Garden = garden_scene.instantiate()
		garden_parent.add_child(garden)
		garden.garden_index = garden_index
		garden_index += 1
		
		for index: int in garden_layout.lesson_buttons.size():
			if current_lesson_count >= lessons.size():
				garden_layout.lesson_buttons.resize(index)
				break
			current_lesson_count += 1
		
		garden.garden_layout = garden_layout
		
		# Don't add empty gardens
		if current_lesson_count >= lessons.size():
			break


func set_up_path() -> void:
	if not garden_parent:
		return
	
	points = []
	var curve: Curve2D = Curve2D.new()
	
	for index: int in gardens_layout.gardens.size():
		if index >= garden_parent.get_child_count():
			break
		var garden_layout: GardenLayout = gardens_layout.gardens[index]
		var garden_control: Garden = garden_parent.get_child(index)
		for button in garden_layout.lesson_buttons:
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
	lock.visible = true


func _unlock() -> void:
	is_locked = false
	lock.visible = false


func _get_current_lesson_button(lesson: int) -> LessonButton:
	var lesson_ind: int = 1
	for garden_control: Garden in garden_parent.get_children():
		for index: int in garden_control.lesson_button_controls.size():
			if lesson_ind == lesson:
				return garden_control.lesson_button_controls[index]
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
	get_tree().change_scene_to_packed(look_and_learn_scene)


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
		@warning_ignore("integer_division")
		scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
		if scroll_tween:
			scroll_tween.stop()
			scroll_tween = null
	elif event.is_action_released("left_click"):
		is_scrolling = false
		var shift_value: int = scroll_container.scroll_horizontal - scroll_beginning_garden * garden_size
		var target_scroll: int = scroll_beginning_garden * garden_size
		var is_garden_changed: bool = false
		if shift_value < - 400:
			target_scroll -= garden_size
			is_garden_changed = true
			left_audio_stream_player.play()
		elif shift_value > 400:
			target_scroll += garden_size
			is_garden_changed = true
			right_audio_stream_player.play()
		scroll_tween = create_tween()
		scroll_tween.set_ease(Tween.EASE_OUT)
		scroll_tween.set_trans(Tween.TRANS_SPRING)
		scroll_tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 1)
		if is_garden_changed:
			@warning_ignore("integer_division")
			current_garden = garden_parent.get_child(target_scroll / garden_size)
			current_garden.pop_animation()
		
		await scroll_tween.finished
		@warning_ignore("integer_division")
		scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
		
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

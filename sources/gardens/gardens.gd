extends Control
signal minigame_layout_opened()

# Namespace
const LookAndLearn: = preload("res://sources/look_and_learn/look_and_learn.gd")
const LessonButton: = preload("res://sources/lesson_screen/lesson_button.gd")
const MinigameLayout: = preload("res://sources/gardens/minigame_layout.gd")

const garden_scene: = preload("res://resources/gardens/garden.tscn")
const look_and_learn_scene: = preload("res://sources/look_and_learn/look_and_learn.tscn")

const garden_size: = 2400

@export_category("Layout")
@export var gardens_layout: GardensLayout:
	set = set_gardens_layout
@export var starting_garden: = -1

@export_category("Colors")
@export var unlocked_color: = Color("1c2662")
@export var locked_color: = Color("1d2229")

@export_group("Minigames")
@export var minigames_scenes: Array[PackedScene]
@export var minigames_icons: Array[Texture]

@onready var garden_parent: HBoxContainer = %GardenParent
@onready var locked_line: Line2D = $ScrollContainer/LockedLine
@onready var unlocked_line: Line2D = $ScrollContainer/UnlockedLine
@onready var line_particles: GPUParticles2D = %LineParticles
@onready var line_audio_stream_player: AudioStreamPlayer = %LineAudioStreamPlayer
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

var curve: Curve2D
var lessons: = {}
var points: Array[Array]= []
var is_scrolling: = false
var scroll_beginning_garden: = 0
var scroll_tween: Tween
var is_locked: = false

var in_minigame_selection: = false
var current_lesson_number: = -1
var current_garden: = -1
var current_button_global_position: = Vector2.ZERO
var current_button: LessonButton

var new_lesson_unlocked: bool = false

static var transition_data: Dictionary


func _ready() -> void:
	get_gardens_db_data()
	if not gardens_layout:
		gardens_layout = load("res://resources/gardens/gardens_layout.tres")
	else:
		set_gardens_layout(gardens_layout)
	set_up_lessons()
	
	await get_tree().process_frame
	
	_lock()
	
	if UserDataManager.student_progression:
		
		# Defines if a new lesson has been unlocked by the player, setups to play the right animation
		new_lesson_unlocked = transition_data and transition_data.current_lesson_number == UserDataManager.student_progression.get_max_unlocked_lesson() and transition_data.minigame_number == 2 and transition_data.minigame_completed
	
		# Loads the progression of the player
		_set_progression()
	
	# Scrolls to the right garden
	if not transition_data:
		if starting_garden == -1:
			var lesson_ind: = 1
			for garden_ind in garden_parent.get_child_count():
				var garden_control: Garden = garden_parent.get_child(garden_ind)
				if starting_garden != -1:
					break
				if not lesson_ind in lessons:
					break
				for i in garden_control.lesson_button_controls.size():
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
		starting_garden = transition_data.current_garden
	
	scroll_container.scroll_horizontal = garden_size * starting_garden
	@warning_ignore("integer_division")
	scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
	
	if transition_data:
		# Finds the button
		var lesson_ind: int = 1
		var current_lesson_button: LessonButton
		for garden_control: Garden in garden_parent.get_children():
			for i in garden_control.lesson_button_controls.size():
				if lesson_ind == transition_data.current_lesson_number:
					current_lesson_button = garden_control.lesson_button_controls[i]
					break
				lesson_ind += 1
				pass
		
		# Re-open the minigames layout
		# If the minigame is completed: play an animation
		await _open_minigames_layout(current_lesson_button, transition_data.current_lesson_number as int, transition_data.current_garden as int, transition_data.current_button_global_position as Vector2)
	
	await OpeningCurtain.open()
	MusicManager.play(MusicManager.Track.Garden)
	
	if new_lesson_unlocked:
		_unlock_new_lesson()
	else:
		_unlock()
	
	new_lesson_unlocked = false
	transition_data = {}


func _unlock_new_lesson() -> void:
	
	var max_lesson: = UserDataManager.student_progression.get_max_unlocked_lesson()
		
	# Close the layout
	await get_tree().create_timer(1.5).timeout
	await _close_minigames_layout()
	
	var lesson_ind: = 1
	var last_lesson_button: LessonButton
	var new_lesson_button: LessonButton
	var is_last_lesson_of_garden: bool = false
	for garden_control: Garden in garden_parent.get_children():
		for i in garden_control.lesson_button_controls.size():
			if lesson_ind == max_lesson + 1:
				new_lesson_button = garden_control.lesson_button_controls[i]
			if lesson_ind == max_lesson :
				last_lesson_button = garden_control.lesson_button_controls[i]
				if i == garden_control.lesson_button_controls.size() -1:
					is_last_lesson_of_garden = true
			if last_lesson_button and new_lesson_button:
				break
			lesson_ind += 1
		if last_lesson_button and new_lesson_button:
			break
	
	# Play an animation on the completed lesson
	if last_lesson_button:
		await last_lesson_button.right()
	
	# Fill in the path towards the next lesson
	var c: = Curve2D.new()
	for i in range(max_lesson-1, max_lesson + 1):
		c.add_point(points[i][0] as Vector2, points[i][1] as Vector2, points[i][2] as Vector2)
	
	var baked_points: = c.get_baked_points()
	
	# Check if we need to scroll to the next garden
	if is_last_lesson_of_garden:
		@warning_ignore("integer_division")
		scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
		var target_scroll: int = scroll_beginning_garden * garden_size + garden_size
		var tween: = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 4)
		@warning_ignore("integer_division")
		scroll_beginning_garden = target_scroll / garden_size
		
		var g: Garden = garden_parent.get_child(scroll_beginning_garden)
		g.pop_animation()
	
	line_audio_stream_player.pitch_scale = 0.95
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
	
	_unlock()


func _process(_delta: float) -> void:
	locked_line.position.x = - scroll_container.scroll_horizontal
	unlocked_line.position.x = - scroll_container.scroll_horizontal
	parallax_background.scroll_offset.x = - scroll_container.scroll_horizontal


func get_gardens_db_data() -> void:
	Database.db.query("SELECT Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		ORDER BY LessonNb")
	for e in Database.db.query_result:
		if not lessons.has(e.LessonNb):
			lessons[e.LessonNb] = []
		var lesson_array: Array = lessons[e.LessonNb]
		lesson_array.append({grapheme = e.Grapheme, phoneme = e.Phoneme, gp_id = e.GPID})


func _open_minigames_layout(button: LessonButton, lesson_ind: int, garden_ind: int, button_global_position: = Vector2.ZERO) -> void:
	if in_minigame_selection or not UserDataManager.student_progression:
		return
	
	in_minigame_selection = true
	
	# Gets the correct exercises for the lesson
	var exercises: = Database.get_exercice_for_lesson(lesson_ind)
	if not exercises or exercises.size() < 3:
		return
	
	# Sets the variables for the current garden and lesson
	current_lesson_number = lesson_ind
	current_garden = garden_ind
	if button:
		button_global_position = button.global_position
		current_button = button
		current_button.show_placeholder(true)
	current_button_global_position = button_global_position
	
	# Gets the current garden node
	var garden: Garden = garden_parent.get_child(current_garden)
	
	# Gets the current lesson unlocks
	var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[current_lesson_number]
	
	var are_minigames_locked: bool = lesson_unlocks["games"][0] == UserProgression.Status.Locked and lesson_unlocks["games"][1] == UserProgression.Status.Locked and lesson_unlocks["games"][2] == UserProgression.Status.Locked
	
	# Desactivate the mouse filters on the buttons behind the layout
	for b: LessonButton in garden.lesson_button_controls:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Background
	if are_minigames_locked:
		minigame_background_center.modulate = locked_color
	else:
		minigame_background_center.modulate = garden.color
	
	# Lesson button
	_handle_lesson_button(current_lesson_number, lesson_unlocks["look_and_learn"] as UserProgression.Status, garden.color)
	
	# Minigames
	_fill_minigame_choice(minigame_layout_1, exercises[0], lesson_unlocks["games"][0] as UserProgression.Status, 0)
	_fill_minigame_choice(minigame_layout_2, exercises[1], lesson_unlocks["games"][1] as UserProgression.Status, 1)
	_fill_minigame_choice(minigame_layout_3, exercises[2], lesson_unlocks["games"][2] as UserProgression.Status, 2)
	
	# Animations
	minigame_selection.visible = true
	back_button.visible = false
	line_particles.visible = false
	
	minigame_background.size = 300.0 * Vector2.ONE
	minigame_background.global_position = current_button_global_position
	minigame_background.visible = true
	
	minigame_background_center.size = 300.0 * Vector2.ONE
	minigame_background_center.global_position = current_button_global_position
	minigame_background_center.visible = true
	
	var tween: = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
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
		if transition_data and transition_data.has("minigame_completed") and transition_data.minigame_completed and transition_data.minigame_number == minigame_number:
			layout.self_modulate = unlocked_color
			await minigame_layout_opened
			create_tween().tween_property(layout, "self_modulate:a", 0, 1)
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
	
	var tween: = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(minigame_selection, "modulate:a", 0.0, 0.25)
	var other_tween: = tween.chain()
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
	line_particles.visible = true
	
	var garden: Garden = garden_parent.get_child(current_garden) 
	
	for button in garden.lesson_button_controls:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	minigame_layout_1.pressed.disconnect(_on_minigame_button_pressed)
	minigame_layout_2.pressed.disconnect(_on_minigame_button_pressed)
	minigame_layout_3.pressed.disconnect(_on_minigame_button_pressed)


func set_up_lessons() -> void:
	var lesson_ind: = 1
	
	for garden_ind in garden_parent.get_child_count():
		
		var garden_control: Garden = garden_parent.get_child(garden_ind)
		
		for i in garden_control.lesson_button_controls.size():
			if not lesson_ind in lessons:
				break
			garden_control.set_lesson_label(i, lessons[lesson_ind][0].grapheme as String)
			garden_control.lesson_button_controls[i].pressed.connect(_on_garden_lesson_button_pressed.bind(garden_control.lesson_button_controls[i], lesson_ind, garden_ind))
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
	for child in garden_parent.get_children():
		child.free()
	
	# Adds the gardens needed from the layout configuration
	var current_lesson_count: int = 0
	for garden_layout in gardens_layout.gardens:
		var garden: Garden = garden_scene.instantiate()
		garden_parent.add_child(garden)
		
		for i in garden_layout.lesson_buttons.size():
			if current_lesson_count >= lessons.size():
				garden_layout.lesson_buttons.resize(i)
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
	curve = Curve2D.new()
	
	for i in gardens_layout.gardens.size():
		if i >= garden_parent.get_child_count():
			break
		var garden_layout: GardenLayout = gardens_layout.gardens[i]
		var garden_control: Garden = garden_parent.get_child(i)
		for b in garden_layout.lesson_buttons:
			var point_position: Vector2 = garden_parent.position + garden_control.position + Vector2(b.position)
			point_position += garden_control.get_button_size() / 2
			var point_in_position: = Vector2.ZERO
			if curve.point_count > 1:
				point_in_position = curve.get_point_position(curve.point_count - 1) + curve.get_point_out(curve.point_count - 1) - point_position
			curve.add_point(point_position, point_in_position, b.path_out_position)
			points.append([point_position, point_in_position, b.path_out_position])
	locked_line.points = curve.get_baked_points()


func _set_progression() -> void:
	if not garden_parent:
		return
	
	if not UserDataManager.student_progression:
		return
	
	var lesson_ind: = 1
	for garden_control: Garden in garden_parent.get_children():
		var garden_unlocks: = 0.0
		var garden_total_unlocks: = 0.0
		for i in garden_control.lesson_button_controls.size():
			var button: LessonButton = garden_control.lesson_button_controls[i]
			if not lesson_ind in lessons:
				button.disabled = true
				continue
			
			if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] >= UserProgression.Status.Unlocked and not (new_lesson_unlocked and lesson_ind == UserDataManager.student_progression.get_max_unlocked_lesson() + 1):
				if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] == UserProgression.Status.Unlocked:
					garden_unlocks += 1.0
				if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] == UserProgression.Status.Completed:
					garden_unlocks += 2.0
				garden_control.lesson_button_controls[i].disabled = false
			else:
				if ProjectSettings.get_setting_with_override("application/custom/unlock_everything"):
					button.disabled = false
				else:
					button.disabled = true
			
			garden_total_unlocks += 2.0
			
			button.completed = UserDataManager.student_progression.is_lesson_completed(lesson_ind)
			
			for k in range(3):
				garden_total_unlocks += 2.0
				match UserDataManager.student_progression.unlocks[lesson_ind]["games"][k]:
					UserProgression.Status.Unlocked:
						garden_unlocks += 1.0
					UserProgression.Status.Completed:
						garden_unlocks += 2.0
			
			lesson_ind += 1
		
		# Handles the flowers
		var unlocks_ratio: = garden_unlocks / garden_total_unlocks
		var total_flowers: float = unlocks_ratio * garden_control.flower_controls.size() * 4.0
		var flower_ind: = 0
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
	var c: = Curve2D.new()
	var max_lesson: = UserDataManager.student_progression.get_max_unlocked_lesson()
	if not new_lesson_unlocked:
		max_lesson += 1
	
	for i in range(max_lesson):
		c.add_point(points[i][0] as Vector2, points[i][1] as Vector2, points[i][2] as Vector2)
	unlocked_line.points = c.get_baked_points()
	
	line_particles.position = unlocked_line.points[unlocked_line.points.size()-1]

func _lock() -> void:
	is_locked = true
	lock.visible = true


func _unlock() -> void:
	is_locked = false
	lock.visible = false


func _on_garden_lesson_button_pressed(button: LessonButton, lesson_ind: int, garden_ind: int, button_global_position: = Vector2.ZERO) -> void:
	feedback_audio_stream_player2.pitch_scale = 1.1
	feedback_audio_stream_player2.play()
	_open_minigames_layout(button, lesson_ind, garden_ind, button_global_position)


func _on_lesson_button_pressed() -> void:
	if is_locked:
		return
		
	feedback_audio_stream_player.play()
	await OpeningCurtain.close()
	
	LookAndLearn.transition_data = {
		current_button_global_position = current_button_global_position,
		current_lesson_number = current_lesson_number,
		current_garden = current_garden,
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
		current_garden = current_garden,
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
		var is_garden_changed: = false
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
			var garden_ind: int = target_scroll / garden_size
			var garden: Garden = garden_parent.get_child(garden_ind)
			garden.pop_animation()
		
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
	if event.is_action_pressed("left_click") and in_minigame_selection:
		_close_minigames_layout()

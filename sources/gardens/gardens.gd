extends Control

const garden_scene: = preload("res://resources/gardens/garden.tscn")
const garden_size: = 2400

const LessonTextureButton: = preload("res://sources/lesson_screen/lesson_texture_button.gd")
const lesson_texture_button_scene: = preload("res://sources/lesson_screen/lesson_texture_button.tscn")

const LookAndLearn: = preload("res://sources/look_and_learn/look_and_learn.gd")
const look_and_learn_scene: = preload("res://sources/look_and_learn/look_and_learn.tscn")

@export var gardens_layout: GardensLayout:
	set = set_gardens_layout

@export var starting_garden: = -1

@export_group("Minigames")
@export_subgroup("Syllable")
@export var syllable_minigames: Array[PackedScene]
@export var syllable_minigames_icons: Array[Texture]

@export_subgroup("Pairing")
@export var pairing_minigames: Array[PackedScene]
@export var pairing_minigames_icons: Array[Texture]

@export_subgroup("Words")
@export var words_minigames: Array[PackedScene]
@export var words_minigames_icons: Array[Texture]

@export_subgroup("Sentences")
@export var sentences_minigames: Array[PackedScene]
@export var sentences_minigames_icons: Array[Texture]

@export_subgroup("Boss")
@export var boss_minigames: Array[PackedScene]
@export var boss_minigames_icons: Array[Texture]

@onready var garden_parent: = %GardenParent
@onready var locked_line: Line2D = $ScrollContainer/LockedLine
@onready var unlocked_line: Line2D = $ScrollContainer/UnlockedLine
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var parallax_background: = %ParallaxBackground
@onready var minigame_selection: Control = %MinigameSelection
@onready var lesson_button: TextureButton = %LessonButton
@onready var back_button: TextureButton = %BackButton
@onready var right_audio_stream_player: AudioStreamPlayer = $RightAudioStreamPlayer
@onready var left_audio_stream_player: AudioStreamPlayer = $LeftAudioStreamPlayer
@onready var minigame_container_1: HFlowContainer = %MinigameContainer1
@onready var minigame_container_2: HFlowContainer = %MinigameContainer2
@onready var minigame_container_3: HFlowContainer = %MinigameContainer3
@onready var minigame_background: TextureRect = %MinigameBackground

var lessons: = {}
var points: = []
var is_scrolling: = false
var scroll_beginning_garden: = 0
var tween: Tween

var in_minigame_selection: = false
var current_lesson_number: = -1
var current_garden: = -1
var current_button_global_position: = Vector2.ZERO
var current_button: TextureButton

static var transition_data: Dictionary


func _ready() -> void:
	OpeningCurtain.open()
	if not gardens_layout:
		gardens_layout = load("res://resources/gardens/gardens_layout.tres")
	else:
		set_gardens_layout(gardens_layout)
	get_gardens_db_data()
	set_up_lessons()
	
	_back_to_correct_spot()
	
	await get_tree().process_frame
	UserDataManager.student_progression.unlocks_changed.connect(_on_progression_unlocks_changed)
	_on_progression_unlocks_changed()
	
	if starting_garden == -1:
		var lesson_ind: = 1
		for garden_ind in garden_parent.get_child_count():
			var garden_control: = garden_parent.get_child(garden_ind)
			if starting_garden != -1:
				break
			if not lesson_ind in lessons:
				break
			for i in garden_control.lesson_button_controls.size():
				if not lesson_ind in lessons:
					break
				var unlock: Dictionary = UserDataManager.student_progression.unlocks[lesson_ind]
				var look_and_learn_unlocked: bool = unlock["look_and_learn"] == UserProgression.Status.Unlocked
				var exercice_unlock_1: bool = unlock["games"][0] == UserProgression.Status.Unlocked
				var exercice_unlock_2: bool = unlock["games"][1] == UserProgression.Status.Unlocked
				var exercice_unlock_3: bool = unlock["games"][2] == UserProgression.Status.Unlocked
				if look_and_learn_unlocked or exercice_unlock_1 or exercice_unlock_2 or exercice_unlock_3:
					starting_garden = garden_ind
					break
				lesson_ind += 1
	
	scroll_container.scroll_horizontal = garden_size * starting_garden


func _back_to_correct_spot() -> void:
	if transition_data.is_empty():
		return
	starting_garden = transition_data.current_garden
	await get_tree().process_frame
	_on_garden_lesson_button_pressed(null, transition_data.current_lesson_number, transition_data.current_garden, transition_data.current_button_global_position)
	transition_data = {}


func _process(_delta: float) -> void:
	locked_line.position.x = - scroll_container.scroll_horizontal
	unlocked_line.position.x = - scroll_container.scroll_horizontal
	parallax_background.scroll_offset.x = - scroll_container.scroll_horizontal


func get_gardens_db_data() -> void:
	Database.db.query("Select Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		ORDER BY LessonNb")
	for e in Database.db.query_result:
		if not lessons.has(e.LessonNb):
			lessons[e.LessonNb] = []
		lessons[e.LessonNb].append({grapheme = e.Grapheme, phoneme = e.Phoneme, gp_id = e.GPID})


func _setup_minigame_selection() -> void:
	var exercises: = Database.get_exercice_for_lesson(current_lesson_number)
	var exercise1: String = exercises[0]
	var exercise2: String = exercises[1]
	var exercise3: String = exercises[2]
	
	if lesson_button and UserDataManager.student_progression:
		var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[current_lesson_number]
		
		lesson_button.text = lessons[current_lesson_number][0].grapheme
		lesson_button.display_text = true
		if lesson_unlocks["look_and_learn"] == UserProgression.Status.Locked:
			lesson_button.disabled = true
		else:
			lesson_button.completed = lesson_unlocks["look_and_learn"] == UserProgression.Status.Completed
		
		_fill_minigame_choice(minigame_container_1, exercise1, lesson_unlocks["games"][0], 0)
		_fill_minigame_choice(minigame_container_2, exercise2, lesson_unlocks["games"][1], 1)
		_fill_minigame_choice(minigame_container_3, exercise3, lesson_unlocks["games"][2], 2)


func _fill_minigame_choice(container: HFlowContainer, exercise_type: String, status: UserProgression.Status, minigame_number: int) -> void:
	for button in container.get_children():
		button.queue_free()
	
	var exercise_scenes: Array[PackedScene]
	var exercise_icons: Array[Texture]
	if exercise_type == "Syllable":
		exercise_scenes = syllable_minigames
		exercise_icons = syllable_minigames_icons
	if exercise_type == "Pairing":
		exercise_scenes = pairing_minigames
		exercise_icons = pairing_minigames_icons
	elif exercise_type == "Words":
		exercise_scenes = words_minigames
		exercise_icons = words_minigames_icons
	elif exercise_type == "Sentences":
		exercise_scenes = sentences_minigames
		exercise_icons = sentences_minigames_icons
	elif exercise_type == "Boss":
		exercise_scenes = boss_minigames
		exercise_icons = boss_minigames_icons
	
	for i in range(exercise_scenes.size()):
		var button: LessonTextureButton = lesson_texture_button_scene.instantiate()
		container.add_child(button)
		button.completed = status == UserProgression.Status.Completed
		button.texture = exercise_icons[i]
		
		if status == UserProgression.Status.Locked:
			button.disabled = true
		
		button.pressed.connect(_on_minigame_button_pressed.bind(exercise_scenes[i], minigame_number))


func set_up_lessons() -> void:
	var lesson_ind: = 1
	for garden_ind in garden_parent.get_child_count():
		var garden_control: = garden_parent.get_child(garden_ind)
		for i in garden_control.lesson_button_controls.size():
			if not lesson_ind in lessons:
				break
			garden_control.set_lesson_label(i, lessons[lesson_ind][0].grapheme)
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
	for child in garden_parent.get_children():
		child.free()
	for garden_layout in gardens_layout.gardens:
		var garden: = garden_scene.instantiate()
		garden_parent.add_child(garden)
		garden.garden_layout = garden_layout


func set_up_path() -> void:
	if not garden_parent:
		return
	points = []
	var curve: = Curve2D.new()
	for i in gardens_layout.gardens.size():
		var garden_layout: = gardens_layout.gardens[i]
		var garden_control: = garden_parent.get_child(i)
		for lesson_button in garden_layout.lesson_buttons:
			var point_position: Vector2 = garden_parent.position + garden_control.position + Vector2(lesson_button.position)
			point_position += garden_control.get_button_size() / 2
			var point_in_position: = Vector2.ZERO
			if curve.point_count > 1:
				point_in_position = curve.get_point_position(curve.point_count - 1) + curve.get_point_out(curve.point_count - 1) - point_position
			curve.add_point(point_position, point_in_position, lesson_button.path_out_position)
			points.append([point_position, point_in_position, lesson_button.path_out_position])
	locked_line.points = curve.get_baked_points()


func _on_garden_lesson_button_pressed(button: TextureButton, lesson_ind: int, garden_ind: int, button_global_position: = Vector2.ZERO, tween_duration: = 0.25) -> void:
	if button:
		button_global_position = button.global_position
		current_button = button
		current_button.visible = false
	current_button_global_position = button_global_position
	current_lesson_number = lesson_ind
	current_garden = garden_ind
	in_minigame_selection = true
	_setup_minigame_selection()
	
	minigame_selection.visible = true
	back_button.disabled = true
	for other_button: TextureButton in garden_parent.get_child(current_garden).lesson_button_controls:
		other_button.disabled = true
	
	minigame_background.size = 300.0 * Vector2.ONE
	minigame_background.global_position = current_button_global_position
	minigame_background.visible = true
	
	var tween: = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(minigame_background, "scale", (1800.0 / 300.0) * Vector2.ONE, tween_duration)
	tween.tween_property(minigame_background, "global_position", Vector2(380.0, 0), tween_duration)
	tween.chain().tween_property(minigame_selection, "modulate:a", 1.0, tween_duration)
	await tween.finished
	
	back_button.disabled = false
	lesson_button.disabled = false


func _on_lesson_button_pressed() -> void:
	await OpeningCurtain.close()
	
	LookAndLearn.transition_data = {
		current_button_global_position = current_button_global_position,
		current_lesson_number = current_lesson_number,
		current_garden = current_garden,
	}
	get_tree().change_scene_to_packed(look_and_learn_scene)


func _on_minigame_button_pressed(minigame_scene: PackedScene, minigame_number: int) -> void:
	await OpeningCurtain.close()
	
	Minigame.transition_data = {
		current_button_global_position = current_button_global_position,
		current_lesson_number = current_lesson_number,
		current_garden = current_garden,
		minigame_number = minigame_number,
	}
	get_tree().change_scene_to_packed(minigame_scene)


func _on_progression_unlocks_changed() -> void:
	if not garden_parent:
		return
	
	var lesson_ind: = 1
	for garden_control in garden_parent.get_children():
		if not lesson_ind in lessons:
			break
		var garden_unlocks: = 0.0
		var garden_total_unlocks: = 0.0
		for i in garden_control.lesson_button_controls.size():
			if not lesson_ind in lessons:
				break
			
			if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] >= UserProgression.Status.Unlocked:
				if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] == UserProgression.Status.Unlocked:
					garden_unlocks += 1.0
				if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] == UserProgression.Status.Completed:
					garden_unlocks += 2.0
				garden_control.lesson_button_controls[i].disabled = false
			else:
				if ProjectSettings.get_setting_with_override("application/custom/unlock_everything"):
					garden_control.lesson_button_controls[i].disabled = false
				else:
					garden_control.lesson_button_controls[i].disabled = true
			
			garden_total_unlocks += 2.0
			
			for k in range(3):
				garden_total_unlocks += 2.0
				match UserDataManager.student_progression.unlocks[lesson_ind]["games"][k]:
					UserProgression.Status.Unlocked:
						garden_unlocks += 1.0
					UserProgression.Status.Completed:
						garden_unlocks += 2.0
			
			lesson_ind += 1
		
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
	
	lesson_ind = 1
	var curve: = Curve2D.new()
	for i in range(UserDataManager.student_progression.get_max_unlocked_lesson() + 1):
		curve.add_point(points[i][0], points[i][1], points[i][2])
	unlocked_line.points = curve.get_baked_points()


func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if in_minigame_selection:
		return
	if event.is_action_pressed("left_click"):
		is_scrolling = true
		scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
		if tween:
			tween.stop()
			tween = null
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
		tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_SPRING)
		tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 1)
		if is_garden_changed:
			var garden_ind: int = target_scroll / garden_size
			garden_parent.get_child(garden_ind).pop_animation()
	
	if is_scrolling and event is InputEventMouseMotion:
		scroll_container.scroll_horizontal -= event.relative.x


func _on_back_button_pressed() -> void:
	if in_minigame_selection:
		lesson_button.disabled = true
		var minigame_buttons: = minigame_container_1.get_children()
		minigame_buttons.append_array(minigame_container_2.get_children())
		minigame_buttons.append_array(minigame_container_3.get_children())
		for minigame_button in minigame_buttons:
			minigame_button.disabled = false
		back_button.disabled = true
		
		var tween: = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(minigame_selection, "modulate:a", 0.0, 0.25)
		var other_tween: = tween.chain()
		other_tween.tween_property(minigame_background, "scale", Vector2.ONE, 0.25)
		other_tween.tween_property(minigame_background, "global_position", current_button_global_position, 0.25)
		await tween.finished
		
		for other_button: TextureButton in garden_parent.get_child(current_garden).lesson_button_controls:
			other_button.disabled = false
		
		if current_button:
			current_button.visible = true
		
		in_minigame_selection = false
		minigame_selection.visible = false
		minigame_background.visible = false
		back_button.disabled = false
	else:
		await OpeningCurtain.close()
		get_tree().change_scene_to_file("res://sources/menus/brain/brain.tscn")

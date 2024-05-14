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
@onready var exercise_button_1: TextureButton = %ExerciseButton1
@onready var exercise_button_2: TextureButton = %ExerciseButton2
@onready var exercise_button_3: TextureButton = %ExerciseButton3
@onready var minigame_choice_container: PanelContainer = %MinigameChoiceContainer
@onready var minigame_button_container: HBoxContainer = %MinigameButtonContainer
@onready var camera_2d: Camera2D = $Camera2D
@onready var back_button: TextureButton = %BackButton

var lessons: = {}
var points: = []
var is_scrolling: = false
var scroll_beginning_garden: = 0
var tween: Tween

var in_minigame_selection: = false
var current_lesson_number: = -1
var current_garden: = -1


func _ready() -> void:
	OpeningCurtain.open()
	if not gardens_layout:
		gardens_layout = load("res://resources/gardens/gardens_layout.tres")
	else:
		set_gardens_layout(gardens_layout)
	get_gardens_db_data()
	set_up_lessons()
	
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
	
	if lesson_button:
		lesson_button.text = lessons[current_lesson_number][0].grapheme
		lesson_button.display_text = true
	if exercise_button_1:
		exercise_button_1.text = exercise1
		if exercise1 == "Syllable":
			exercise_button_1.images = syllable_minigames_icons
		elif exercise1 == "Words":
			exercise_button_1.images = words_minigames_icons
		elif exercise1 == "Sentences":
			exercise_button_1.images = sentences_minigames_icons
		elif exercise1 == "Boss":
			exercise_button_1.images = boss_minigames_icons
		exercise_button_1.load_images()
	if exercise_button_2:
		exercise_button_2.text = exercise2
		if exercise2 == "Syllable":
			exercise_button_2.images = syllable_minigames_icons
		elif exercise2 == "Words":
			exercise_button_2.images = words_minigames_icons
		elif exercise2 == "Sentences":
			exercise_button_2.images = sentences_minigames_icons
		elif exercise2 == "Boss":
			exercise_button_2.images = boss_minigames_icons
		exercise_button_2.load_images()
	if exercise_button_3:
		exercise_button_3.text = exercise3
		if exercise3 == "Syllable":
			exercise_button_3.images = syllable_minigames_icons
		elif exercise3 == "Words":
			exercise_button_3.images = words_minigames_icons
		elif exercise3 == "Sentences":
			exercise_button_3.images = sentences_minigames_icons
		elif exercise3 == "Boss":
			exercise_button_3.images = boss_minigames_icons
		exercise_button_3.load_images()
	
	if UserDataManager.student_progression :
		var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[current_lesson_number]
		if lesson_button:
			if lesson_unlocks["look_and_learn"] == UserProgression.Status.Locked:
				lesson_button.disabled = true
			else:
				lesson_button.completed = lesson_unlocks["look_and_learn"] == UserProgression.Status.Completed
		
		if exercise_button_1:
			if lesson_unlocks["games"][0] == UserProgression.Status.Locked:
				exercise_button_1.disabled = true
			else:
				exercise_button_1.completed = lesson_unlocks["games"][0] == UserProgression.Status.Completed
		
		if exercise_button_2:
			if lesson_unlocks["games"][0] == UserProgression.Status.Locked:
				exercise_button_2.disabled = true
			else:
				exercise_button_2.completed = lesson_unlocks["games"][1] == UserProgression.Status.Completed
		
		if exercise_button_3:
			if lesson_unlocks["games"][0] == UserProgression.Status.Locked:
				exercise_button_3.disabled = true
			else:
				exercise_button_3.completed = lesson_unlocks["games"][2] == UserProgression.Status.Completed


func _fill_minigame_choice(exercise_type: String, is_completed: bool, minigame_number: int) -> void:
	for button in minigame_button_container.get_children():
		button.queue_free()
	
	var exercise_scenes: Array[PackedScene]
	var exercise_icons: Array[Texture]
	if exercise_type == "Syllable":
		exercise_scenes = syllable_minigames
		exercise_icons = syllable_minigames_icons
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
		minigame_button_container.add_child(button)
		button.completed = is_completed
		button.texture = exercise_icons[i]
		
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


func _on_garden_lesson_button_pressed(current_button: TextureButton, lesson_ind: int, garden_ind: int) -> void:
	current_lesson_number = lesson_ind
	current_garden = garden_ind
	in_minigame_selection = true
	_setup_minigame_selection()
	
	minigame_selection.visible = true
	back_button.disabled = true
	for other_button: TextureButton in garden_parent.get_child(current_garden).lesson_button_controls:
		other_button.disabled = true
	
	var tween: = create_tween().set_parallel(true)
	tween.tween_property(minigame_selection, "modulate:a", 1.0, 0.5)
	tween.tween_property(locked_line, "modulate:a", 0.0, 0.5)
	tween.tween_property(unlocked_line, "modulate:a", 0.0, 0.5)
	tween.tween_property(garden_parent.get_child(current_garden).buttons, "modulate:a", 0.0, 0.5)
	tween.tween_property(camera_2d, "zoom", Vector2(2.0, 2.0), 0.5)
	tween.tween_property(camera_2d, "global_position", current_button.global_position, 0.5)
	await tween.finished
	
	locked_line.visible = false
	unlocked_line.visible = false
	garden_parent.get_child(current_garden).buttons.visible = false
	back_button.disabled = false
	lesson_button.disabled = false
	exercise_button_1.disabled = false
	exercise_button_2.disabled = false
	exercise_button_3.disabled = false


func _on_lesson_button_pressed() -> void:
	await OpeningCurtain.close()
	
	var look_and_learn: LookAndLearn = look_and_learn_scene.instantiate()
	look_and_learn.lesson_nb = current_lesson_number
	
	get_tree().root.add_child(look_and_learn)
	get_tree().current_scene = look_and_learn
	queue_free()


func _on_exercise_button_1_pressed() -> void:
	_fill_minigame_choice(exercise_button_1.text, exercise_button_1.completed, 0)
	minigame_choice_container.visible = true


func _on_exercise_button_2_pressed() -> void:
	_fill_minigame_choice(exercise_button_2.text, exercise_button_2.completed, 1)
	minigame_choice_container.visible = true


func _on_exercise_button_3_pressed() -> void:
	_fill_minigame_choice(exercise_button_3.text, exercise_button_3.completed, 2)
	minigame_choice_container.visible = true


func _on_minigame_button_pressed(minigame_scene: PackedScene, minigame_number: int) -> void:
	await OpeningCurtain.close()
	
	var minigame: Minigame = minigame_scene.instantiate()
	minigame.lesson_nb = current_lesson_number
	minigame.minigame_number = minigame_number
	
	get_tree().root.add_child(minigame)
	get_tree().current_scene = minigame
	queue_free()


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
		elif shift_value > 400:
			target_scroll += garden_size
			is_garden_changed = true
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
		minigame_choice_container.visible = false
		locked_line.visible = true
		unlocked_line.visible = true
		garden_parent.get_child(current_garden).buttons.visible = true
		
		lesson_button.disabled = true
		exercise_button_1.disabled = true
		exercise_button_2.disabled = true
		exercise_button_3.disabled = true
		back_button.disabled = true
		
		var tween: = create_tween().set_parallel(true)
		tween.tween_property(minigame_selection, "modulate:a", 0.0, 0.5)
		tween.tween_property(locked_line, "modulate:a", 1.0, 0.5)
		tween.tween_property(unlocked_line, "modulate:a", 1.0, 0.5)
		tween.tween_property(garden_parent.get_child(current_garden).buttons, "modulate:a", 1.0, 0.5)
		tween.tween_property(camera_2d, "zoom", Vector2(1.0, 1.0), 0.5)
		tween.tween_property(camera_2d, "global_position", Vector2(1280.0, 900.0), 0.5)
		await tween.finished
		
		for other_button: TextureButton in garden_parent.get_child(current_garden).lesson_button_controls:
			other_button.disabled = false
		
		in_minigame_selection = false
		minigame_selection.visible = false
		back_button.disabled = false
	else:
		await OpeningCurtain.close()
		get_tree().change_scene_to_file("res://sources/menus/brain/brain.tscn")


func _on_minigame_choice_back_button_pressed() -> void:
	minigame_choice_container.visible = false

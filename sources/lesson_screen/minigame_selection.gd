extends Control

const LessonLabelButton: = preload("res://sources/lesson_screen/lesson_label_button.gd")
const LessonTextureButton: = preload("res://sources/lesson_screen/lesson_texture_button.gd")
const LookAndLearn: = preload("res://sources/look_and_learn/look_and_learn.gd")

const lesson_texture_button_scene: = preload("res://sources/lesson_screen/lesson_texture_button.tscn")
const look_and_learn_scene: = preload("res://sources/look_and_learn/look_and_learn.tscn")

@export var lesson_number: = 1:
	set = _set_lesson_number

@export_group("Grapheme")
@export var grapheme_minigames: Array[PackedScene]
@export var grapheme_minigames_icons: Array[Texture]

@export_group("Syllable")
@export var syllable_minigames: Array[PackedScene]
@export var syllable_minigames_icons: Array[Texture]

@export_group("Words")
@export var words_minigames: Array[PackedScene]
@export var words_minigames_icons: Array[Texture]

@export_group("Sentences")
@export var sentences_minigames: Array[PackedScene]
@export var sentences_minigames_icons: Array[Texture]

@onready var lesson_button: LessonLabelButton = $Buttons/LessonButton
@onready var exercise_button_1: LessonLabelButton = $Buttons/ExerciseButton1
@onready var exercise_button_2: LessonLabelButton = $Buttons/ExerciseButton2
@onready var exercise_button_3: LessonLabelButton = $Buttons/ExerciseButton3
@onready var minigame_choice_container: PanelContainer = %MinigameChoiceContainer
@onready var minigame_button_container: HBoxContainer = %MinigameButtonContainer


func _ready() -> void:
	_set_lesson_number(lesson_number)
	OpeningCurtain.open()


func _set_lesson_number(value: int) -> void:
	lesson_number = value
	
	var query: = "Select Grapheme, Phoneme, Exercise1, Exercise2, Exercise3 FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		INNER JOIN LessonsExercises ON Lessons.ID = LessonsExercises.LessonID
		WHERE LessonNB == %o" % lesson_number
	Database.db.query(query)
	var lesson_dict: = Database.db.query_result[0]
	Database.db.query("Select Type FROM ExerciseTypes
		WHERE ID == %o" % lesson_dict.Exercise1)
	var exercise1: String = Database.db.query_result[0].Type
	Database.db.query("Select Type FROM ExerciseTypes
		WHERE ID == %o" % lesson_dict.Exercise2)
	var exercise2: String = Database.db.query_result[0].Type
	Database.db.query("Select Type FROM ExerciseTypes
		WHERE ID == %o" % lesson_dict.Exercise3)
	var exercise3: String = Database.db.query_result[0].Type
	
	if lesson_button:
		lesson_button.text = "%s-%s" % [lesson_dict.Grapheme, lesson_dict.Phoneme]
	if exercise_button_1:
		exercise_button_1.text = exercise1
	if exercise_button_2:
		exercise_button_2.text = exercise2
	if exercise_button_3:
		exercise_button_3.text = exercise3
	
	if UserDataManager.student_progression :
		var lesson_unlocks: Dictionary = UserDataManager.student_progression.unlocks[lesson_number]
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
	if exercise_type == "Grapheme":
		exercise_scenes = grapheme_minigames
		exercise_icons = grapheme_minigames_icons
	elif exercise_type == "Syllable":
		exercise_scenes = syllable_minigames
		exercise_icons = syllable_minigames_icons
	elif exercise_type == "Words":
		exercise_scenes = words_minigames
		exercise_icons = words_minigames_icons
	elif exercise_type == "Sentences":
		exercise_scenes = sentences_minigames
		exercise_icons = sentences_minigames_icons
	
	for i in range(exercise_scenes.size()):
		var button: LessonTextureButton = lesson_texture_button_scene.instantiate()
		minigame_button_container.add_child(button)
		button.completed = is_completed
		button.texture = exercise_icons[i]
		
		button.pressed.connect(_on_minigame_button_pressed.bind(exercise_scenes[i], minigame_number))


func _on_lesson_button_pressed() -> void:
	await OpeningCurtain.close()
	
	var look_and_learn: LookAndLearn = look_and_learn_scene.instantiate()
	look_and_learn.lesson_nb = lesson_number
	
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
	minigame.lesson_nb = lesson_number
	minigame.minigame_number = minigame_number
	
	get_tree().root.add_child(minigame)
	get_tree().current_scene = minigame
	queue_free()


func _on_minigame_choice_back_button_pressed() -> void:
	minigame_choice_container.visible = false


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	
	get_tree().change_scene_to_file("res://sources/gardens/gardens.tscn")

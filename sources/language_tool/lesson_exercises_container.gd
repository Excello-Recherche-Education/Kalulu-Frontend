class_name LessonExerciseContainer
extends PanelContainer

@export var lesson_number: int = -1:
	set = _set_lesson_number

var sentences_by_lesson: Dictionary = {}

@onready var lesson_id_label: Label = %LessonIDLabel
@onready var lesson_gps: HBoxContainer = %LessonGPs
@onready var exercise_buttons: Array[OptionButton] = [%ExerciseButton1, %ExerciseButton2, %ExerciseButton3]
@onready var ok_texture: TextureRect = %OKTexture
@onready var number_of_g_ps: Label = %NumberOfGPs
@onready var number_of_syllables: Label = %NumberOfSyllables
@onready var number_of_words: Label = %NumberOfWords
@onready var number_of_sentences: Label = %NumberOfSentences


func _ready() -> void:
	Database.db.query("Select * FROM ExerciseTypes")
	
	for element: Dictionary in Database.db.query_result:
		for exercise_button: OptionButton in exercise_buttons:
			exercise_button.add_item(element.Type as String, element.ID as int)


func _set_lesson_number(value: int) -> void:
	if value == lesson_number:
		return
	
	lesson_number = value
	lesson_id_label.text = str(lesson_number)
	for gp: Label in lesson_gps.get_children():
		gp.queue_free()
	
	Database.db.query("Select Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		WHERE LessonNb = " + str(lesson_number))
	
	for element: Dictionary in Database.db.query_result:
		var gp: Label = Label.new()
		gp.text = Database.get_gp_name(element)
		lesson_gps.add_child(gp)
	
	Database.db.query("Select Exercise1, Exercise2, Exercise3, LessonNb FROM LessonsExercises
	INNER JOIN Lessons ON Lessons.ID = LessonsExercises.LessonID
	WHERE LessonNb = " + str(lesson_number))
	
	for element: Dictionary in Database.db.query_result:
		exercise_buttons[0].select(exercise_buttons[0].get_item_index(element.Exercise1 as int))
		exercise_buttons[1].select(exercise_buttons[0].get_item_index(element.Exercise2 as int))
		exercise_buttons[2].select(exercise_buttons[0].get_item_index(element.Exercise3 as int))
	
	var gps_in_lesson: Array[Dictionary] = Database.get_gps_for_lesson(lesson_number, true)
	var syllables_in_lesson: Array[Dictionary] = Database.get_syllables_for_lesson(lesson_number)
	var words_in_lesson: Array[Dictionary] = Database.get_words_for_lesson(lesson_number)
	var sentences_in_lesson: Array = Database.get_sentences(lesson_number, false, sentences_by_lesson)
	
	number_of_g_ps.text = str(gps_in_lesson.size())
	number_of_syllables.text = str(syllables_in_lesson.size())
	number_of_words.text = str(words_in_lesson.size())
	number_of_sentences.text = str(sentences_in_lesson.size())
	
	ok_texture.visible = true


func _on_exercise_button_1_item_selected(_index: int) -> void:
	ok_texture.visible = false


func _on_exercise_button_2_item_selected(_index: int) -> void:
	ok_texture.visible = false


func _on_exercise_button_3_item_selected(_index: int) -> void:
	ok_texture.visible = false


func _on_save_button_pressed() -> void:
	Database.db.query("Select * FROM Lessons WHERE LessonNb = " + str(lesson_number))
	var lesson_id: int = Database.db.query_result[0].ID
	
	var exercise1: int = exercise_buttons[0].get_item_id(exercise_buttons[0].selected)
	var exercise2: int = exercise_buttons[1].get_item_id(exercise_buttons[1].selected)
	var exercise3: int = exercise_buttons[2].get_item_id(exercise_buttons[2].selected)
	var lesson_dict: Dictionary = {"Exercise1": exercise1, "Exercise2": exercise2, "Exercise3": exercise3}
	
	Database.db.query("Select * FROM LessonsExercises WHERE LessonID = " + str(lesson_id))
	if Database.db.query_result.is_empty():
		lesson_dict["LessonID"] = lesson_id
		Database.db.insert_row("LessonsExercises", lesson_dict)
	else:
		Database.db.update_rows("LessonsExercises", "LessonID=" + str(lesson_id), lesson_dict)
	
	ok_texture.visible = true

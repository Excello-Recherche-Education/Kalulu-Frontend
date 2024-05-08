extends PanelContainer

@export var lesson_number: = -1:
	set = _set_lesson_number

@onready var lesson_id_label: Label = %LessonIDLabel
@onready var lesson_gps: HBoxContainer = %LessonGPs
@onready var exercise_buttons: Array[OptionButton] = [%ExerciseButton1, %ExerciseButton2, %ExerciseButton3]
@onready var ok_texture: TextureRect = %OKTexture


func _ready() -> void:
	Database.db.query("Select * FROM ExerciseTypes")
	
	for e in Database.db.query_result:
		for exercise_button: OptionButton in exercise_buttons:
			exercise_button.add_item(e.Type, e.ID)


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
	
	for e in Database.db.query_result:
		var gp: = Label.new()
		gp.text = e.Grapheme + "-" + e.Phoneme
		lesson_gps.add_child(gp)
		
	
	Database.db.query("Select Exercise1, Exercise2, Exercise3, LessonNb FROM LessonsExercises
	INNER JOIN Lessons ON Lessons.ID = LessonsExercises.LessonID
	WHERE LessonNb = " + str(lesson_number))
	
	for e in Database.db.query_result:
		exercise_buttons[0].select(exercise_buttons[0].get_item_index(e.Exercise1))
		exercise_buttons[1].select(exercise_buttons[0].get_item_index(e.Exercise2))
		exercise_buttons[2].select(exercise_buttons[0].get_item_index(e.Exercise3))
	
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
	
	var exercise1: = exercise_buttons[0].get_item_id(exercise_buttons[0].selected)
	var exercise2: = exercise_buttons[1].get_item_id(exercise_buttons[1].selected)
	var exercise3: = exercise_buttons[2].get_item_id(exercise_buttons[2].selected)
	var lesson_dict: = {Exercise1= exercise1, Exercise2= exercise2, Exercise3= exercise3}
	
	Database.db.query("Select * FROM LessonsExercises WHERE LessonID = " + str(lesson_id))
	if Database.db.query_result.is_empty():
		lesson_dict["LessonID"] = lesson_id
		Database.db.insert_row("LessonsExercises", lesson_dict)
	else:
		Database.db.update_rows("LessonsExercises", "LessonID=" + str(lesson_id), lesson_dict)
	
	ok_texture.visible = true

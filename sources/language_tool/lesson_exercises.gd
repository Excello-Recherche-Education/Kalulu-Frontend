extends Control

const LessonExerciceContainer: = preload("res://sources/language_tool/lesson_exercises_container.gd")
const lesson_exercice_container_scene: = preload("res://sources/language_tool/lesson_exercises_container.tscn")

@onready var lessons_container: VBoxContainer = %LessonsContainer


func _ready() -> void:
	var query: = "SELECT name FROM sqlite_master WHERE type='table' AND name='ExerciseTypes'"
	Database.db.query(query)
	if Database.db.query_result.is_empty():
		Database.db.query("CREATE TABLE ExerciseTypes (ID INTEGER PRIMARY KEY ASC AUTOINCREMENT UNIQUE NOT NULL, Type TEXT NOT NULL)")
		Database.db.insert_row("ExerciseTypes",
		{
			Type = "Grapheme",
		})
		Database.db.insert_row("ExerciseTypes",
		{
			Type = "Syllable",
		})
		Database.db.insert_row("ExerciseTypes",
		{
			Type = "Words",
		})
		Database.db.insert_row("ExerciseTypes",
		{
			Type = "Sentences",
		})
	
	query = "SELECT name FROM sqlite_master WHERE type='table' AND name='LessonsExercises'"
	Database.db.query(query)
	if Database.db.query_result.is_empty():
		Database.db.query("CREATE TABLE 'LessonsExercises' (
			'ID'	INTEGER NOT NULL UNIQUE,
			'LessonID'	INTEGER NOT NULL,
			'Exercise1'	INTEGER NOT NULL,
			'Exercise2'	INTEGER NOT NULL,
			'Exercise3'	INTEGER NOT NULL,
			PRIMARY KEY('ID' AUTOINCREMENT),
			FOREIGN KEY('Exercise3') REFERENCES 'ExerciseTypes'('ID') ON UPDATE CASCADE ON DELETE CASCADE,
			FOREIGN KEY('Exercise2') REFERENCES 'ExerciseTypes'('ID') ON UPDATE CASCADE ON DELETE CASCADE,
			FOREIGN KEY('Exercise1') REFERENCES 'ExerciseTypes'('ID') ON UPDATE CASCADE ON DELETE CASCADE,
			FOREIGN KEY('LessonID') REFERENCES 'Lessons'('ID') ON UPDATE CASCADE ON DELETE CASCADE
		)")
	
	
	Database.db.query("Select * FROM Lessons")
	
	for e in Database.db.query_result:
		var container: LessonExerciceContainer = lesson_exercice_container_scene.instantiate()
		lessons_container.add_child(container)
		container.lesson_number = e.LessonNb
		container._on_save_button_pressed()


func _on_save_button_pressed() -> void:
	for container: LessonExerciceContainer in lessons_container.get_children():
		container._on_save_button_pressed()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")

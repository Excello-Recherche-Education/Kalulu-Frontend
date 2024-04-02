extends Control

const LessonExerciceContainer: = preload("res://sources/language_tool/lesson_exercises_container.gd")
const lesson_exercice_container_scene: = preload("res://sources/language_tool/lesson_exercises_container.tscn")

@onready var lessons_container: VBoxContainer = %LessonsContainer


func _ready() -> void:
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

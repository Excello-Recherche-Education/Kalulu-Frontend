extends Control

@onready var lessons_container: = $%LessonsContainer

var lesson_container_scene: = preload("res://sources/language_tool/lesson_container.tscn")

var lessons: = {}


func _ready() -> void:
	Database.db.query("Select Grapheme, Phoneme, LessonNb FROM Lessons
		INNER JOIN GPs ON Lessons.GPID = GPs.ID
		ORDER BY LessonNb")
	for e in Database.db.query_result:
		if lessons.has(e.LessonNb):
			lessons[e.LessonNb].add_gp({grapheme = e.Grapheme, phoneme = e.Phoneme})
		else:
			var lesson_container: = lesson_container_scene.instantiate()
			lessons_container.add_child(lesson_container)
			lesson_container.add_gp({grapheme = e.Grapheme, phoneme = e.Phoneme})
			lesson_container.number = e.LessonNb
			lessons[e.LessonNb] = lesson_container

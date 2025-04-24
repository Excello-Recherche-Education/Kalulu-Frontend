extends Control
class_name LessonUnlocks

signal student_deleted(code: int)

const StudentUnlock: = preload("res://sources/menus/settings/lesson_unlock.gd")
const student_unlock_scene: = preload("res://sources/menus/settings/lesson_unlock.tscn")

@onready var lesson_container: VBoxContainer = %LessonContainer

@export var device: int
@export var student: int:
	set = _on_student_changed

var progression: UserProgression

func _create_lessons() -> void:
	for lesson_unlock in lesson_container.get_children():
		lesson_unlock.queue_free()
	
	Database.db.query("SELECT LessonNb, group_concat(Grapheme || '-' ||Phoneme, ' ') GPs FROM Lessons
INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
GROUP BY LessonNb
ORDER BY LessonNb")
	for e in Database.db.query_result:
		var student_unlock: StudentUnlock = student_unlock_scene.instantiate()
		student_unlock.lesson_GPs = e.GPs
		student_unlock.lesson_number = e.LessonNb
		student_unlock.unlocks = progression.unlocks
		lesson_container.add_child(student_unlock)
		
		student_unlock.unlocks_changed.connect(_create_lessons)


func _on_student_changed(value: int)-> void:
	student = value
	progression = UserDataManager.get_student_progression_for_code(device, student)
	_create_lessons()
	(%PasswordVisualizer as PasswordVisualizer).password = str(value)


func _on_back_button_pressed() -> void:
	UserDataManager.save_student_progression_for_code(device, student, progression)
	hide()


func _on_delete_button_pressed() -> void:
	student_deleted.emit(int(student))

extends Control

const StudentUnlock: = preload("res://sources/menus/settings/lesson_unlock.gd")
const student_unlock_scene: = preload("res://sources/menus/settings/lesson_unlock.tscn")

@onready var device_option_button: OptionButton = %DeviceOptionButton
@onready var student_option_button: OptionButton = %StudentOptionButton
@onready var lesson_container: VBoxContainer = %LessonContainer


func _ready() -> void:
	for device in UserDataManager.teacher_settings.students.keys():
		device_option_button.add_item(str(device), device)
	
	device_option_button.select(0)
	_on_device_option_button_item_selected(0)
	
	_create_lessons()


func _create_lessons() -> void:
	for lesson_unlock in lesson_container.get_children():
		lesson_unlock.queue_free()
	
	for lesson_number in UserDataManager.student_progression.unlocks.keys():
		var student_unlock: StudentUnlock = student_unlock_scene.instantiate()
		student_unlock.lesson_number = lesson_number
		
		lesson_container.add_child(student_unlock)


func _on_device_option_button_item_selected(index: int) -> void:
	var device_id: = device_option_button.get_item_id(index)
	student_option_button.clear()
	for student in UserDataManager.teacher_settings.students[device_id]:
		student_option_button.add_item(student.name, int(student.code))
	student_option_button.select(0)
	_on_student_option_button_item_selected(0)


func _on_student_option_button_item_selected(index: int) -> void:
	var student_code: = str(student_option_button.get_item_id(index))
	if not UserDataManager.login_student(student_code):
		return
	
	_create_lessons()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/menus/settings/teacher_settings.tscn")

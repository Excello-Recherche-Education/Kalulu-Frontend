extends TabBar

signal student_pressed(code: String)

const StudentPanel: = preload("res://sources/menus/settings/student_panel.gd")
const student_panel_scene : PackedScene = preload("res://sources/menus/settings/student_panel.tscn")

@onready var students_container : GridContainer = %StudentsContainer

@export var device_id : int
@export var students : Array[StudentData] = []


func _ready() -> void:
	refresh()


func refresh() -> void:
	for child in students_container.get_children():
		child.queue_free()
	
	if not students:
		return
	
	var student_count : int = 1
	for student in students:
		var student_panel: StudentPanel = student_panel_scene.instantiate()
		student_panel.student_count = student_count
		student_panel.student_data = student
		
		student_panel.pressed.connect(func() -> void: student_pressed.emit(student.code))
		
		students_container.add_child(student_panel)
		
		student_count += 1

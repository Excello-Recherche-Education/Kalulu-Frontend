extends TabBar
class_name DeviceTab

signal student_pressed(code: int)

const STUDENT_PANEL_SCENE: PackedScene = preload("res://sources/menus/settings/student_panel.tscn")

@onready var students_container: GridContainer = %StudentsContainer

@export var device_id: int
@export var students: Array[StudentData] = []


func _ready() -> void:
	refresh()


func refresh() -> void:
	for child: Node in students_container.get_children():
		child.queue_free()
	
	if not students:
		return
	
	var student_count: int = 1
	for student: StudentData in students:
		var student_panel: StudentPanel = STUDENT_PANEL_SCENE.instantiate()
		student_panel.student_count = student_count
		student_panel.student_data = student
		
		student_panel.pressed.connect(func() -> void: student_pressed.emit(student.code))
		
		students_container.add_child(student_panel)
		
		student_count += 1

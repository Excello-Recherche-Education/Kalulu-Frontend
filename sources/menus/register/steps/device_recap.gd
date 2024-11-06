extends Control
class_name DeviceRecap

const StudentPanel = preload("res://sources/menus/settings/student_panel.gd")
const student_panel_scene = preload("res://sources/menus/settings/student_panel.tscn")

@export var title : String
@export var students : Array[StudentData] = []

@onready var title_label : Label = %Title
@onready var students_container : GridContainer = %StudentsContainer

func _ready():
	
	if title:
		title_label.text = title
	
	var i := 1
	for student in students:
		var student_panel : StudentPanel = student_panel_scene.instantiate()
		student_panel.student_count = i
		student_panel.student_data = student
		
		students_container.add_child(student_panel)
		
		i+= 1

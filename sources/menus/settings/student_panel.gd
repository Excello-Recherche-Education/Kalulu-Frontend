extends Control
class_name StudentPanel

@onready var name_label : Label = %NameLabel
@onready var password_visualizer : PasswordVisualizer = %PasswordVisualizer

@export var student_count : int
@export var student_data : StudentData

func _ready():
	if not student_data:
		return
	
	if student_data.name:
		name_label.text = student_data.name
	else:
		name_label.text = "Student %d" % student_count
	
	if student_data.code:
		password_visualizer.password = student_data.code


func _on_details_button_pressed():
	# UserDataManager.delete_student(1, student_data.code)
	print(student_data)

extends Control

signal pressed

@onready var name_label : Label = %NameLabel
@onready var password_visualizer : PasswordVisualizer = %PasswordVisualizer

@export var student_count : int
@export var student_data : StudentData

func _ready() -> void:
	if not student_data:
		return
	
	if student_data.name:
		name_label.text = student_data.name
	else:
		name_label.text = tr("STUDENT_NUM").format({"number" : student_count})
	
	if student_data.code:
		password_visualizer.password = str(student_data.code)


func _on_details_button_pressed() -> void:
	pressed.emit()

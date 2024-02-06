extends Control

@onready var teacher_steps : Array[PackedScene] = [
	preload("res://sources/menus/register/steps/teacher/method_step.tscn"),
	preload("res://sources/menus/register/steps/teacher/devices_count_step.tscn")
]
@onready var parent_steps : Array[PackedScene] = [
	preload("res://sources/menus/register/steps/parent/players_count_step.tscn")
]

@onready var account_type_step : PackedScene = preload("res://sources/menus/register/steps/account_type_step.tscn")
@onready var credential_step : PackedScene = preload("res://sources/menus/register/steps/credentials_step.tscn")
@onready var students_step : PackedScene = preload("res://sources/menus/register/steps/teacher/students_count_step.tscn")
@onready var player_step : PackedScene = preload("res://sources/menus/register/steps/parent/player_step.tscn")

var current_steps : Array[Step]

@onready var register_data := UserSettings.new() # TODO Change the resource
@onready var progress_bar := %ProgressBar
@onready var steps := %Steps

func _ready():
	current_steps = [account_type_step.instantiate()]
	_go_to_step(progress_bar.value)


func _go_to_step(step_index: int):
	
	# Clear the steps
	for step in steps.get_children(false):
		step.completed.disconnect(_on_step_completed)
		steps.remove_child(step)
	
	# Instantiate the step
	var next_step = current_steps[step_index]
	if not next_step.data:
		next_step.data = register_data
	steps.add_child(next_step)
	
	# Connect the step
	next_step.completed.connect(_on_step_completed)
	
	# Handles progress bar
	progress_bar.set_value_with_tween(step_index)


func _on_back_button_pressed():
	if progress_bar.value == 0:
		print("Back to title screen")
	else:
		_go_to_step(progress_bar.value-1)


func _on_step_completed(step : Step, values : Dictionary):
	
	match step.step_name:
		"type":
			# Adds teacher or parent steps
			if "type" in values:
				_remove_future_steps()
				if values["type"] == 0:
					for scene in teacher_steps:
						current_steps.append(scene.instantiate())
				else:
					for scene in parent_steps:
						current_steps.append(scene.instantiate())
				progress_bar.max_value = current_steps.size()
		"devices":
			# Adds students steps for teachers
			if "devices_count" in values:
				_remove_future_steps()
				var count = values["devices_count"] as int
				if count:
					for device in count:
						var students_step_scene := students_step.instantiate()
						students_step_scene.question = students_step_scene.question % (device + 1)
						current_steps.append(students_step_scene)
					current_steps.append(credential_step.instantiate())
					progress_bar.max_value = current_steps.size()
		"players":
			# Adds students steps for parents
			if "students_count" in values:
				_remove_future_steps()
				var count = values["students_count"] as int
				if count:
					for student in count:
						var student_step_scene := player_step.instantiate()
						student_step_scene.question = student_step_scene.question % (student + 1)
						current_steps.append(student_step_scene)
					current_steps.append(credential_step.instantiate())
					progress_bar.max_value = current_steps.size()
	
	
	if progress_bar.value == current_steps.size()-1:
		print("Registering complete !")
	else:
		_go_to_step(progress_bar.value+1)


func _remove_future_steps():
	# Free memory
	for i in current_steps.size():
		if i > progress_bar.value:
			current_steps[i].queue_free()
	
	# Resize the array to remove unwanted steps
	current_steps.resize(progress_bar.value + 1)

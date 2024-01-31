extends Control

@onready var teacher_steps : Array[PackedScene] = [
	preload("res://sources/menus/register/steps/teacher/method_step.tscn"),
	preload("res://sources/menus/register/steps/teacher/devices_count_step.tscn"),
	preload("res://sources/menus/register/steps/teacher/students_count_step.tscn"),
	preload("res://sources/menus/register/steps/credentials_step.tscn")
]
@onready var parent_steps : Array[PackedScene] = [
	
]
var current_steps : Array[PackedScene]
# TODO Change the resource
@onready var register_data := UserSettings.new()
@onready var progress_bar := %ProgressBar
@onready var steps := %Steps

func _ready():
	current_steps = teacher_steps
	
	# Handles the progress bar
	progress_bar.value = 0
	progress_bar.max_value = current_steps.size()
	
	# Load new step
	_go_to_step(progress_bar.value)


func _go_to_step(step_index: int):
	var next_step
	
	# Check if step is already instantiated
	for step in steps.get_children(false):
		step.hide()
		
		if step.name == str(progress_bar.value):
			step.completed.disconnect(_on_step_completed)
			pass
		
		if step.name == str(step_index):
			next_step = step
	
	# Instantiate the step
	if not next_step:
		next_step = teacher_steps[step_index].instantiate()
		next_step.name = str(step_index)
		next_step.object = register_data
		steps.add_child(next_step)
	else:
		next_step.show()
		
	# Connect the step
	next_step.completed.connect(_on_step_completed)
	
	# Handles progress bar
	progress_bar.value = step_index


func _reset_steps():
	progress_bar.value = 0
	progress_bar.max_value = 0
	
	for step in steps.get_children(false):
		step.queue_free()


func _on_back_button_pressed():
	if progress_bar.value == 0:
		print("Back to title screen")
		# get_tree().change_scene_to_file()
	else:
		_go_to_step(progress_bar.value-1)


func _on_step_completed():
	if progress_bar.value == current_steps.size()-1:
		print("Registering complete !")
	else:
		_go_to_step(progress_bar.value+1)

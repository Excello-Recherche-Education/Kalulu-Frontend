extends Control

const MAIN_MENU_PATH: String = "res://sources/menus/main/main_menu.tscn"
const NEXT_SCENE_PATH: String = "res://sources/menus/settings/teacher_settings.tscn"

@onready var teacher_steps: Array[PackedScene] = [
	preload("res://sources/menus/register/steps/teacher/method_step.tscn"),
	preload("res://sources/menus/register/steps/teacher/devices_count_step.tscn")
]
@onready var parent_steps: Array[PackedScene] = [
	preload("res://sources/menus/register/steps/parent/players_count_step.tscn")
]
@onready var last_steps: Array[PackedScene] = [
	preload("res://sources/menus/register/steps/credentials_step.tscn"),
	preload("res://sources/menus/register/steps/general_conditions_step.tscn"),
	preload("res://sources/menus/register/steps/recap_step.tscn")
]
@onready var account_type_step: PackedScene = preload("res://sources/menus/register/steps/account_type_step.tscn")
@onready var students_step: PackedScene = preload("res://sources/menus/register/steps/teacher/students_count_step.tscn")
@onready var player_step: PackedScene = preload("res://sources/menus/register/steps/parent/player_step.tscn")

var current_steps: Array[Step] = []

@onready var register_data: TeacherSettings = TeacherSettings.new()
@onready var progress_bar: RegisterProgressBar = %ProgressBar
@onready var steps: Control = %Steps
@onready var popup: TextureRect = %Popup
@onready var popup_info_label: Label = %PopupInfo

func _ready() -> void:
	current_steps = [account_type_step.instantiate()]
	_go_to_step(int(progress_bar.value))
	OpeningCurtain.open()


func _go_to_step(step_index: int) -> void:
	# Clear the steps
	for step: Node in steps.get_children(false):
		if step is Step:
			(step as Step).back.disconnect(_on_step_back)
			(step as Step).next.disconnect(_on_step_completed)
			steps.remove_child(step)
	
	# Instantiate the step
	var next_step: Step = current_steps[step_index]
	if not next_step.data:
		next_step.data = register_data
	steps.add_child(next_step)
	
	# Connect the step
	next_step.back.connect(_on_step_back)
	next_step.next.connect(_on_step_completed)
	next_step.on_enter()
	
	# Handles progress bar
	progress_bar.set_value_with_tween(step_index)


func _on_step_back(_step: Step) -> void:
	if progress_bar.value == 0:
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
	else:
		_go_to_step(int(progress_bar.value-1))


func _on_step_completed(step: Step) -> void:
	match step.step_name:
		"type":
			# Adds teacher or parent steps
			_remove_future_steps()
			if register_data.account_type == TeacherSettings.AccountType.Teacher:
				for scene: PackedScene in teacher_steps:
					current_steps.append(scene.instantiate())
			elif register_data.account_type == TeacherSettings.AccountType.Parent:
				for scene: PackedScene in parent_steps:
					current_steps.append(scene.instantiate())
			progress_bar.max_value = current_steps.size() + 3
		"devices":
			# Adds students steps for teachers
			_remove_future_steps()
			for device: int in register_data.devices_count:
				var students_step_scene: Node  = students_step.instantiate()
				if students_step_scene is StudentsCountStep:
					(students_step_scene as StudentsCountStep).question = tr((students_step_scene as StudentsCountStep).question).format({"number": (device + 1)})
					(students_step_scene as StudentsCountStep).device_id = device + 1
					current_steps.append(students_step_scene)
				else:
					students_step_scene.queue_free()
			for scene: PackedScene in last_steps:
					current_steps.append(scene.instantiate())
			progress_bar.max_value = current_steps.size()
		"players":
			# Adds students steps for parents
			_remove_future_steps()
			var student_count: int = 1
			for student: StudentData in register_data.students[1]:
				var student_step_scene: Step = player_step.instantiate()
				student_step_scene.question = tr(student_step_scene.question).format({"number": student_count})
				student_step_scene.data = student
				current_steps.append(student_step_scene)
				student_count += 1
			for scene: PackedScene in last_steps:
				current_steps.append(scene.instantiate())
			progress_bar.max_value = current_steps.size()
	
	if progress_bar.value == current_steps.size()-1:
		# Send register via API
		var res: Dictionary = await ServerManager.register(register_data.to_dict())
		if res.code == 200:
			register_data.last_modified = res.body.last_modified
			register_data.token = res.body.token
			if UserDataManager.register(register_data):
				get_tree().change_scene_to_file(NEXT_SCENE_PATH)
		else:
			if res.has("body") and (res.body as Dictionary).has("message"):
				popup_info_label.text = res.body.message
			else:
				popup_info_label.text = ''
			popup.show()
	else:
		_go_to_step(int(progress_bar.value + 1))


func _remove_future_steps() -> void:
	# Free memory
	for index: int in range(progress_bar.value + 1, current_steps.size(), 1):
		current_steps[index].queue_free()
	
	# Resize the array to remove unwanted steps
	current_steps.resize(int(progress_bar.value + 1))

func _on_popup_button_pressed() -> void:
	popup.hide()

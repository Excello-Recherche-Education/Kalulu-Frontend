extends Control
## Drives the registration wizard: builds the list of steps and walks it.
##
## The step list is not fixed. Choosing an account type appends the teacher or
## parent branch, and choosing a device count appends one students step per
## device, so the list grows as the answers come in.

const BACK_SCENE_PATH: String = EntryFlow.WELCOME_SCENE_PATH
const NEXT_SCENE_PATH: String = "res://sources/menus/language_selection/package_downloader.tscn"

## Index into current_steps of the step on screen.
##
## This used to be kept in the progress bar's `value`, which made a piece of
## decoration load-bearing: the wizard could not lose the bar without losing its
## place. The redesign has no progress bar, so the index lives here.
var current_step: int = 0
var current_steps: Array[Step] = []

@onready var language_step: PackedScene = preload("res://sources/menus/register/steps/language/language_step.tscn")
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
@onready var register_data: TeacherSettings = TeacherSettings.new()
@onready var steps: Control = %Steps
@onready var popup: TextureRect = %Popup
@onready var popup_info_label: Label = %PopupInfo
@onready var code_limit_popup: ConfirmPopup = %CodeLimitPopup


func _ready() -> void:
	current_steps = [language_step.instantiate(), account_type_step.instantiate()]
	Log.info("Register: Initialized registration flow with %d steps" % current_steps.size())
	_go_to_step(current_step)
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
	Log.trace("Register: Entered step %s (%d/%d)" % [next_step.step_name, step_index + 1, current_steps.size()])

	current_step = step_index


func _on_step_back(_step: Step) -> void:
	if current_step == 0:
		Log.info("Register: Back to the welcome screen from first step")
		get_tree().change_scene_to_file(BACK_SCENE_PATH)
	else:
		Log.trace("Register: Moving back from step %d" % current_step)
		_go_to_step(current_step - 1)


func _on_step_completed(step: Step) -> void:
	Log.trace("Register: Completed step %s" % step.step_name)
	match step.step_name:
		"type":
			# Adds teacher or parent steps
			_remove_future_steps()
			if register_data.account_type == TeacherSettings.AccountType.TEACHER:
				for scene: PackedScene in teacher_steps:
					current_steps.append(scene.instantiate())
			elif register_data.account_type == TeacherSettings.AccountType.PARENT:
				for scene: PackedScene in parent_steps:
					current_steps.append(scene.instantiate())
		"devices":
			# Adds students steps for teachers
			_remove_future_steps()
			for device: int in range(register_data.devices_count):
				var students_step_scene: Node = students_step.instantiate()
				if students_step_scene is StudentsCountStep:
					(students_step_scene as StudentsCountStep).question = tr((students_step_scene as StudentsCountStep).question).format({"number": (device + 1)})
					(students_step_scene as StudentsCountStep).device_id = device + 1
					current_steps.append(students_step_scene)
				else:
					students_step_scene.queue_free()
			for scene: PackedScene in last_steps:
				current_steps.append(scene.instantiate())
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
		"language":
			register_data.language = UserDataManager.get_language()

	# Both branches allocate codes through the same step script, so both can run
	# the account dry. The notice carries the flow on once it is dismissed.
	var device_step: StudentsCountStep = step as StudentsCountStep
	if device_step and device_step.codes_ran_out:
		_explain_the_code_limit(device_step)
		return

	await _continue()


## Moves to the next step, or submits when the last one is done.
func _continue() -> void:
	if current_step == current_steps.size() - 1:
		await _submit()
	else:
		_go_to_step(current_step + 1)


## Explains that the account has run out of student codes.
##
## The devices still to come are dropped first: the codes are one fixed set for
## the whole account, so a device that has not been filled in yet has nothing left
## to fill it with. Registration carries on from here rather than dead-ending,
## with however many students did get a code.
func _explain_the_code_limit(device_step: StudentsCountStep) -> void:
	var dropped: int = _drop_remaining_device_steps()
	var created: int = (register_data.students.get(device_step.device_id, []) as Array).size()
	if created == 0:
		# A device with no students is not a device.
		register_data.students.erase(device_step.device_id)

	Log.info("Register: out of student codes on device %d; dropped %d later device(s)"
		% [device_step.device_id, dropped])
	if dropped > 0:
		code_limit_popup.content_text = tr("STUDENT_CODES_EXHAUSTED_DEVICES_POPUP").format({
			"students": created,
			"device": device_step.device_id,
			"devices": dropped,
		})
	else:
		code_limit_popup.content_text = tr("STUDENT_CODES_EXHAUSTED_POPUP").format({
			"students": created,
		})
	code_limit_popup.show()


## Removes the device steps still to come, keeping the steps that close the flow.
##
## Returns how many devices were dropped, for the message that explains it.
func _drop_remaining_device_steps() -> int:
	var kept: Array[Step] = []
	var dropped: int = 0
	for index: int in range(current_step + 1, current_steps.size()):
		var step: Step = current_steps[index]
		if step is StudentsCountStep:
			register_data.students.erase((step as StudentsCountStep).device_id)
			step.queue_free()
			dropped += 1
		else:
			kept.append(step)

	current_steps.resize(current_step + 1)
	current_steps.append_array(kept)
	return dropped


func _submit() -> void:
	Log.info("Register: Submitting registration for %s" % str(register_data.email))
	var res: Dictionary = await ServerManager.register(register_data.to_dict())
	if res.code != 200:
		Log.warn("Register: Registration failed with code %d" % res.code)
		if res.has("body") and (res.body as Dictionary).has("message"):
			popup_info_label.text = res.body.message
		else:
			popup_info_label.text = ''
		popup.show()
		return

	Log.info("Register: Registration request successful, saving data")
	register_data.last_modified = res.body.last_modified
	register_data.token = res.body.token
	if UserDataManager.register(register_data):
		Log.info("Register: Registration stored locally, moving to package downloader")
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	else:
		Log.error("Register: Failed to persist registration locally")


func _remove_future_steps() -> void:
	# Free memory
	for index: int in range(current_step + 1, current_steps.size(), 1):
		current_steps[index].queue_free()

	# Resize the array to remove unwanted steps
	current_steps.resize(current_step + 1)


func _on_popup_button_pressed() -> void:
	popup.hide()


## Both ways out of the notice carry on: it reports, it does not ask.
func _on_code_limit_popup_dismissed() -> void:
	await _continue()

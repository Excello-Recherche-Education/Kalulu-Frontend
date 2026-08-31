extends GutTest
## Step bookkeeping in the registration wizard.
##
## The current step index used to live in the progress bar's `value`. Moving it
## into a plain field touched every branch and every back step, so the walk is
## worth pinning down. Submission is not exercised: that reaches the network.

const REGISTER_SCENE: String = "res://sources/menus/register/register.tscn"

var wizard: Control


func before_each() -> void:
	wizard = (load(REGISTER_SCENE) as PackedScene).instantiate()
	add_child_autofree(wizard)
	await get_tree().process_frame


func after_each() -> void:
	# Only the step on screen is a child of anything, so freeing the wizard does
	# not take the rest of current_steps with it.
	for step: Step in wizard.current_steps:
		if is_instance_valid(step) and not step.is_inside_tree():
			step.free()


func test_it_opens_on_the_first_step() -> void:
	assert_eq(wizard.current_step, 0, "the wizard should start at the beginning")
	assert_eq(wizard.current_steps.size(), 2,
		"language and account type are known up front")
	assert_eq(wizard.current_steps[0].step_name, "language")


func test_only_the_current_step_is_on_screen() -> void:
	var shown: int = 0
	for child: Node in wizard.steps.get_children():
		if child is Step:
			shown += 1
	assert_eq(shown, 1, "exactly one step should be mounted at a time")


func test_choosing_teacher_appends_the_teacher_branch() -> void:
	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.TEACHER

	wizard._on_step_completed(wizard.current_steps[1])

	assert_eq(wizard.current_steps.size(), 4, "teacher adds a method and a device count")
	assert_eq(wizard.current_step, 2, "and the wizard moves on to the first of them")


func test_choosing_parent_appends_the_parent_branch() -> void:
	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.PARENT

	wizard._on_step_completed(wizard.current_steps[1])

	assert_eq(wizard.current_steps.size(), 3, "a parent only needs a player count")
	assert_eq(wizard.current_step, 2)


func test_changing_the_account_type_discards_the_old_branch() -> void:
	# Going back and answering differently must not leave the first branch's
	# steps stranded further down the list.
	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.TEACHER
	wizard._on_step_completed(wizard.current_steps[1])
	assert_eq(wizard.current_steps.size(), 4)

	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.PARENT
	wizard._on_step_completed(wizard.current_steps[1])

	assert_eq(wizard.current_steps.size(), 3, "the teacher branch should be gone")


func test_a_device_count_adds_one_students_step_per_device() -> void:
	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.TEACHER
	wizard._on_step_completed(wizard.current_steps[1])
	wizard._go_to_step(3)
	wizard.register_data.devices_count = 3

	wizard._on_step_completed(wizard.current_steps[3])

	# language, type, method, devices, 3 x students, credentials, conditions, recap
	assert_eq(wizard.current_steps.size(), 10,
		"three devices should add three students steps plus the closing three")
	assert_eq(wizard.current_step, 4)


func test_going_back_walks_the_list_down() -> void:
	wizard._go_to_step(1)

	wizard._on_step_back(wizard.current_steps[1])

	assert_eq(wizard.current_step, 0, "back from the second step returns to the first")


func test_every_step_is_reachable_and_leaves_one_mounted() -> void:
	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.TEACHER
	wizard._on_step_completed(wizard.current_steps[1])
	wizard._go_to_step(3)
	wizard.register_data.devices_count = 2
	wizard._on_step_completed(wizard.current_steps[3])

	for index: int in wizard.current_steps.size():
		wizard._go_to_step(index)
		assert_eq(wizard.current_step, index, "step %d should be reachable" % index)
		var mounted: int = 0
		for child: Node in wizard.steps.get_children():
			if child is Step:
				mounted += 1
		assert_eq(mounted, 1, "step %d should leave exactly one step mounted" % index)


# Running out is logged as well as shown, which is exactly what is being asked
# for here. Acknowledge it so GUT does not report it as an unexpected error. Must
# run inside the test: GUT checks for unhandled errors before after_each().
func _accept_the_logged_warning() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


## Walks the wizard to the first device's students step, with `devices` devices.
func _reach_the_first_device_step(devices: int) -> StudentsCountStep:
	wizard._go_to_step(1)
	wizard.register_data.account_type = TeacherSettings.AccountType.TEACHER
	wizard._on_step_completed(wizard.current_steps[1])
	wizard._go_to_step(3)
	wizard.register_data.devices_count = devices
	wizard._on_step_completed(wizard.current_steps[3])
	return wizard.current_steps[4] as StudentsCountStep


## Answers the mounted device step with `count` students, the way Next does.
func _answer_with(step: StudentsCountStep, count: int) -> void:
	step.students_count_field.value = count
	assert_true(step._on_next(), "the step should let the wizard move on")


func test_a_device_asking_for_more_students_than_there_are_codes_keeps_what_fits() -> void:
	# Regression: the step stored the -1 that get_new_code returns when it runs
	# out, because it checked the code for truthiness and -1 is true. The next
	# student then crashed the wizard outright.
	var first: StudentsCountStep = await _reach_the_first_device_step(2)
	var codes: int = TeacherSettings.AVAILABLE_CODES.size()

	_answer_with(first, codes)

	var created: Array = wizard.register_data.students[first.device_id]
	assert_eq(created.size(), codes, "every code should have been used")
	assert_false(first.codes_ran_out, "asking for exactly the codes available fits")
	for student: StudentData in created:
		assert_ne(student.code, TeacherSettings.NO_CODE_AVAILABLE,
			"no student should be left carrying the no-code marker")


func test_the_devices_left_over_are_dropped_once_the_codes_run_out() -> void:
	var first: StudentsCountStep = await _reach_the_first_device_step(3)
	_answer_with(first, TeacherSettings.AVAILABLE_CODES.size())
	await wizard._on_step_completed(first)

	var second: StudentsCountStep = wizard.current_steps[5] as StudentsCountStep
	wizard._go_to_step(5)
	_answer_with(second, 4)

	_accept_the_logged_warning()
	assert_true(second.codes_ran_out, "there is nothing left to give this device")
	wizard._on_step_completed(second)

	# language, type, method, devices, device 1, device 2, credentials, conditions,
	# recap -- device 3 is gone, the closing steps are not.
	assert_eq(wizard.current_steps.size(), 9, "the third device's step should be dropped")
	for index: int in range(6, 9):
		assert_false(wizard.current_steps[index] is StudentsCountStep,
			"the steps that close the flow must survive the drop")
	assert_eq(wizard.current_steps[6].step_name, "credentials")
	assert_false(wizard.register_data.students.has(3), "device 3 should not be in the account")
	assert_false(wizard.register_data.students.has(2),
		"a device that got no students at all is not a device")


func test_running_out_explains_itself_before_carrying_on() -> void:
	var first: StudentsCountStep = await _reach_the_first_device_step(3)
	_answer_with(first, TeacherSettings.AVAILABLE_CODES.size())
	await wizard._on_step_completed(first)
	var second: StudentsCountStep = wizard.current_steps[5] as StudentsCountStep
	wizard._go_to_step(5)
	_answer_with(second, 4)

	_accept_the_logged_warning()
	wizard._on_step_completed(second)

	assert_true(wizard.code_limit_popup.visible, "the teacher should be told what happened")
	assert_false(wizard.code_limit_popup.content_text.contains("{"),
		"every placeholder in the message should have been filled in")
	assert_string_contains(wizard.code_limit_popup.content_text, "1",
		"the message should name the devices that were dropped")
	assert_eq(wizard.current_step, 5, "the flow waits on the notice rather than moving on")

	wizard._on_code_limit_popup_dismissed()
	await get_tree().process_frame

	assert_eq(wizard.current_step, 6, "dismissing the notice carries the flow on")
	assert_eq(wizard.current_steps[6].step_name, "credentials")


func test_the_notice_reports_rather_than_asks() -> void:
	assert_true(wizard.code_limit_popup.acknowledge_only,
		"there is nothing to decide, so it should have one button")
	assert_false(wizard.code_limit_popup.visible, "and it should start hidden")

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

## Integration test: Full account creation → login → deletion lifecycle.
## Requires internet access and the DEV API server to be reachable.
## Uses a unique throwaway email per run to avoid collisions.
extends GutTest

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const TEST_EMAIL_PREFIX: String = "gut_test_"
const TEST_EMAIL_DOMAIN: String = "@kalulu-test.org"
const TEST_PASSWORD: String = "GutTestP4ssw0rd!"

# ---------------------------------------------------------------------------
# State shared across lifecycle
# ---------------------------------------------------------------------------
var _test_email: String
var _cleanup_token: String = ""
var _original_env_setting: int
var _original_custom_env_url: String
var _original_teacher_settings: TeacherSettings


# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------
func before_all() -> void:
	# Save original environment so we can restore it after the test
	_original_env_setting = ServerManager.environment_setting
	_original_custom_env_url = ServerManager.custom_environment_url
	_original_teacher_settings = UserDataManager.teacher_settings

	# Force DEV environment for the test
	ServerManager.set_environment(0)

	# Generate a unique email using the current tick count
	_test_email = TEST_EMAIL_PREFIX + str(Time.get_ticks_usec()) + TEST_EMAIL_DOMAIN
	gut.p("Test email: " + _test_email)
	gut.p("Environment URL: " + ServerManager.environment_url)


func after_all() -> void:
	# Safety net: if we stored a token during the test but the delete step
	# was never reached (test failure / early abort), attempt cleanup now.
	if _cleanup_token != "":
		gut.p("after_all: Attempting to clean up leftover test account…")
		var tmp: TeacherSettings = TeacherSettings.new()
		tmp.token = _cleanup_token
		UserDataManager.teacher_settings = tmp
		await ServerManager.delete_account()

	# Restore original state
	ServerManager.set_environment(_original_env_setting, _original_custom_env_url)
	UserDataManager.teacher_settings = _original_teacher_settings


# ---------------------------------------------------------------------------
# Main test
# ---------------------------------------------------------------------------
func test_full_account_creation_login_and_deletion() -> void:

	# ------------------------------------------------------------------
	# Step 0 – Internet availability
	# ------------------------------------------------------------------
	gut.p("Step 0: Checking internet access…")
	var has_internet: bool = await ServerManager.check_internet_access()
	if not has_internet:
		pending("SKIPPED – no internet access available. Cannot run integration test.")
		return
	assert_true(has_internet, "Internet access should be available")

	# ------------------------------------------------------------------
	# Step 1 – Email should be available before registration
	# ------------------------------------------------------------------
	gut.p("Step 1: Checking that test email is available…")
	var check_res: Dictionary = await ServerManager.check_email(_test_email)
	assert_eq(check_res.code as int, 200, "Test email should be available before registration")
	if check_res.code != 200:
		gut.p("ABORTING – email already exists: " + _test_email)
		return

	# ------------------------------------------------------------------
	# Step 2 – Build registration data (Teacher, 2 devices, 3 students)
	# ------------------------------------------------------------------
	gut.p("Step 2: Building registration payload…")

	var register_data: TeacherSettings = TeacherSettings.new()
	register_data.account_type = TeacherSettings.AccountType.TEACHER
	register_data.education_method = TeacherSettings.EducationMethod.COMPLETE
	register_data.email = _test_email
	register_data.password = TEST_PASSWORD
	register_data.language = "fr_FR"

	# Device 1 — two students
	var student_alice: StudentData = StudentData.new()
	student_alice.code = 123
	student_alice.name = "Alice"
	student_alice.level = StudentData.Level.BEGINNER
	student_alice.age = 7

	var student_bob: StudentData = StudentData.new()
	student_bob.code = 124
	student_bob.name = "Bob"
	student_bob.level = StudentData.Level.REVIEWER
	student_bob.age = 8

	# Device 2 — one student
	var student_charlie: StudentData = StudentData.new()
	student_charlie.code = 321
	student_charlie.name = "Charlie"
	student_charlie.level = StudentData.Level.ADULT
	student_charlie.age = 10

	register_data.students[1] = [student_alice, student_bob]
	register_data.students[2] = [student_charlie]

	# Quick sanity check on the payload before sending
	var payload: Dictionary = register_data.to_dict()
	assert_eq(payload.email as String, _test_email, "Payload email should match test email")
	assert_eq((payload.students as Dictionary).size(), 2, "Payload should contain 2 devices")

	# ------------------------------------------------------------------
	# Step 3 – Register
	# ------------------------------------------------------------------
	gut.p("Step 3: Sending registration request…")
	var reg_res: Dictionary = await ServerManager.register(payload)
	assert_eq(reg_res.code as int, 200, "Registration should succeed (HTTP 200)")

	if reg_res.code != 200:
		gut.p("ABORTING – Registration failed with code %d" % reg_res.code)
		return

	var reg_body: Dictionary = reg_res.body as Dictionary
	assert_true(reg_body.has("token"), "Registration response must contain a token")
	assert_true(reg_body.has("last_modified"), "Registration response must contain last_modified")
	assert_true(str(reg_body.token).length() > 0, "Token must not be empty")
	assert_true(str(reg_body.last_modified).length() > 0, "last_modified must not be empty")

	# Store the token for cleanup in case later steps fail
	_cleanup_token = str(reg_body.token)

	# ------------------------------------------------------------------
	# Step 4 – Email should now be taken
	# ------------------------------------------------------------------
	gut.p("Step 4: Verifying email is now taken…")
	var check_taken_res: Dictionary = await ServerManager.check_email(_test_email)
	assert_ne(check_taken_res.code as int, 200, "Email should be unavailable after registration")

	# Handle expected warnings: server returns 400 for a taken email
	assert_engine_error("Response code = 400",
			"Expected: server returns 400 for taken email")
	assert_engine_error("Email address already used",
			"Expected: email should be reported as already used")

	# ------------------------------------------------------------------
	# Step 5 – Login and verify all returned data
	# ------------------------------------------------------------------
	gut.p("Step 5: Logging in and verifying response data…")
	var login_res: Dictionary = await ServerManager.login(_test_email, TEST_PASSWORD)
	assert_eq(login_res.code as int, 200, "Login should succeed with registered credentials")

	if login_res.code != 200:
		gut.p("ABORTING – Login failed with code %d" % login_res.code)
		return

	var login_body: Dictionary = login_res.body as Dictionary

	# --- Basic fields ---
	assert_eq(str(login_body.email), _test_email, "Returned email should match")
	assert_eq(login_body.account_type as int, TeacherSettings.AccountType.TEACHER,
			"Account type should be Teacher (0)")
	assert_eq(login_body.education_method as int, TeacherSettings.EducationMethod.COMPLETE,
			"Education method should be Complete (1)")
	assert_eq(str(login_body.language), "fr_FR", "Language should be 'fr'")
	assert_true(login_body.has("token"), "Login response must include token")
	assert_true(str(login_body.token).length() > 0, "Login token must not be empty")
	assert_true(login_body.has("last_modified"), "Login response must include last_modified")

	# Update cleanup token to the freshest one
	_cleanup_token = str(login_body.token)

	# --- Students structure ---
	assert_true(login_body.has("students"), "Login response must include students")
	var students: Dictionary = login_body.students as Dictionary

	# Backend returns string-keyed device IDs ("1", "2")
	assert_true(students.has("1"), "Students dict should contain device '1'")
	assert_true(students.has("2"), "Students dict should contain device '2'")
	assert_eq((students["1"] as Array).size(), 2, "Device 1 should have 2 students")
	assert_eq((students["2"] as Array).size(), 1, "Device 2 should have 1 student")

	# --- Device 1 student details ---
	var d1_students: Array = students["1"] as Array
	var found_alice: bool = false
	var found_bob: bool = false
	for student: Dictionary in d1_students:
		match student.code as int:
			123:
				found_alice = true
				assert_eq(str(student.name), "Alice", "Student 123 should be Alice")
				assert_eq(student.age as int, 7, "Alice should be age 7")
				assert_eq(student.level as int, StudentData.Level.BEGINNER,
						"Alice should be Beginner (0)")
			124:
				found_bob = true
				assert_eq(str(student.name), "Bob", "Student 124 should be Bob")
				assert_eq(student.age as int, 8, "Bob should be age 8")
				assert_eq(student.level as int, StudentData.Level.REVIEWER,
						"Bob should be Reviewer (1)")
	assert_true(found_alice, "Alice (code 123) should be present on device 1")
	assert_true(found_bob, "Bob (code 124) should be present on device 1")

	# --- Device 2 student details ---
	var d2_students: Array = students["2"] as Array
	var charlie: Dictionary = d2_students[0] as Dictionary
	assert_eq(charlie.code as int, 321, "Device 2 student should have code 321")
	assert_eq(str(charlie.name), "Charlie", "Student 321 should be Charlie")
	assert_eq(charlie.age as int, 10, "Charlie should be age 10")
	assert_eq(charlie.level as int, StudentData.Level.ADULT,
			"Charlie should be Adult (2)")

	# ------------------------------------------------------------------
	# Step 6 – Set auth context and delete the account
	# ------------------------------------------------------------------
	gut.p("Step 6: Deleting the test account…")

	# ServerManager reads the Bearer token from UserDataManager.teacher_settings
	var auth_settings: TeacherSettings = TeacherSettings.new()
	auth_settings.token = str(login_body.token)
	auth_settings.email = _test_email
	UserDataManager.teacher_settings = auth_settings

	var del_res: Dictionary = await ServerManager.delete_account()
	assert_eq(del_res.code as int, 200, "Account deletion should succeed (HTTP 200)")

	# Handle expected warning: ServerManager logs a warning when delete is initiated
	assert_engine_error("Delete account request initiated",
			"Expected: delete account produces a warning log")

	if del_res.code == 200:
		# Account deleted — no cleanup needed
		_cleanup_token = ""

	# ------------------------------------------------------------------
	# Step 7 – Login should now fail
	# ------------------------------------------------------------------
	gut.p("Step 7: Verifying login fails after deletion…")
	# Clear teacher_settings so the login call doesn't carry a stale token
	UserDataManager.teacher_settings = null

	var login_after_del: Dictionary = await ServerManager.login(_test_email, TEST_PASSWORD)
	assert_ne(login_after_del.code as int, 200,
			"Login should fail after account deletion (expected 401, got %d)" % login_after_del.code)

	# Handle expected warnings: server returns 401 for deleted account login
	assert_engine_error("Response code = 401",
			"Expected: server returns 401 for deleted account")
	assert_engine_error("Login or password incorrect",
			"Expected: login should fail after account deletion")

	# ------------------------------------------------------------------
	# Step 8 – Email should be available again
	# ------------------------------------------------------------------
	gut.p("Step 8: Verifying email is available again after deletion…")
	var check_freed_res: Dictionary = await ServerManager.check_email(_test_email)
	assert_eq(check_freed_res.code as int, 200,
			"Email should be available again after account deletion")

	# Handle expected warnings that may fire outside the test method's scope
	# (e.g. during autoload initialization or before_all). assert_engine_error
	# cannot reach those, so we mark them manually via get_errors().
	# "Database is null" warnings are also expected when the godot-sqlite addon
	# is absent (e.g. in GitHub Actions), so we suppress them here too.
	for err: GutTrackedError in get_errors():
		if not err.handled and err.contains_text("Database file not found"):
			err.handled = true
		if not err.handled and err.contains_text("Database is null"):
			err.handled = true

	gut.p("All steps passed.")

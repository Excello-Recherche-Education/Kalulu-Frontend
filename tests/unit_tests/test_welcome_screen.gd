extends GutTest
## Wiring of the unified welcome screen.
##
## Covers the structure and tab behaviour rather than the network calls: the
## login request goes through ServerManager, which these tests do not stand up.

const WELCOME_SCENE: String = "res://sources/menus/welcome/welcome.tscn"
const LOGIN_TAB: int = 0
const SIGN_UP_TAB: int = 1

var welcome: Control


func before_each() -> void:
	welcome = (load(WELCOME_SCENE) as PackedScene).instantiate()
	add_child_autofree(welcome)
	await get_tree().process_frame


func test_the_scene_loads_with_every_part_wired() -> void:
	assert_not_null(welcome.toggle, "the tab switch should be present")
	assert_not_null(welcome.login_panel, "the login panel should be present")
	assert_not_null(welcome.sign_up_panel, "the sign up panel should be present")
	assert_not_null(welcome.keypad, "the adult check keypad should be present")
	assert_not_null(welcome.next_button, "the primary action should be present")


func test_the_login_panel_is_also_the_form_validator() -> void:
	# The panel needs to be a container so it lays its fields out, and a
	# FormValidator so the fields find it. A script may attach to any subclass of
	# the type it extends, so one VBoxContainer is both.
	assert_true(welcome.login_panel is FormValidator,
		"the login panel should be a FormValidator")
	assert_true(welcome.login_panel is VBoxContainer,
		"the login panel should also be a container")


func test_it_opens_on_the_login_tab() -> void:
	assert_eq(welcome.toggle.selected, LOGIN_TAB)
	assert_true(welcome.login_panel.visible, "login should be showing")
	assert_false(welcome.sign_up_panel.visible, "sign up should be hidden")
	assert_true(welcome.next_button.visible, "login needs its Next button")


func test_switching_to_sign_up_swaps_the_panels() -> void:
	welcome.toggle.selected = SIGN_UP_TAB
	await get_tree().process_frame

	assert_false(welcome.login_panel.visible, "login should be hidden")
	assert_true(welcome.sign_up_panel.visible, "sign up should be showing")


func test_the_sign_up_tab_has_no_next_button() -> void:
	# Completing the code is itself the action, as in the mockups.
	welcome.toggle.selected = SIGN_UP_TAB
	await get_tree().process_frame

	assert_false(welcome.next_button.visible,
		"the adult check advances on its own, so Next would be dead weight")


func test_the_credential_fields_are_validated() -> void:
	assert_eq(welcome.email_field.rules.size(), 2, "email should be required and well formed")
	assert_eq(welcome.password_field.rules.size(), 1, "password should be required")

	var passed: bool = welcome.login_panel.validate()

	assert_false(passed, "an empty form should not validate")
	assert_true(welcome.email_field.error_label.visible, "the email field should say why")


func test_a_well_formed_login_validates() -> void:
	welcome.email_field.text = "teacher@example.org"
	welcome.password_field.text = "a-password"

	assert_true(welcome.login_panel.validate(), "a filled, valid form should pass")
	assert_false(welcome.email_field.error_label.visible)
	assert_false(welcome.password_field.error_label.visible)


func test_the_password_field_starts_masked() -> void:
	assert_true(welcome.password_field.is_masked(), "a password should not be readable")
	assert_false(welcome.email_field.is_masked(), "the email is not a secret")


func test_the_language_field_lists_the_supported_locales() -> void:
	var field: OptionButton = welcome.get_node("%LanguageField")
	assert_eq(field.item_count, Utils.SUPPORTED_LOCALES.size(),
		"every supported locale should be offered")


func test_the_adult_challenge_is_one_of_the_available_codes() -> void:
	assert_has(TeacherSettings.AVAILABLE_CODES, int(welcome.adult_challenge.code),
		"the challenge must be a code the keypad can actually produce")


func test_the_adult_prompt_names_the_three_symbols() -> void:
	var digits: PackedStringArray = welcome.adult_challenge.code.split("", false)
	for digit: String in digits:
		assert_string_contains(welcome.adult_prompt.text, tr(Design.code_symbol_name(digit)),
			"the prompt should name symbol %s" % digit)


func test_a_wrong_code_resets_the_challenge() -> void:
	welcome.toggle.selected = SIGN_UP_TAB
	await get_tree().process_frame
	var wrong: String = _code_other_than(welcome.adult_challenge.code)

	for digit: String in wrong.split("", false):
		welcome.keypad.toggle_digit(digit)
	await get_tree().process_frame

	assert_eq(welcome.keypad.code, "", "a wrong code should clear the keypad")


func test_revisiting_sign_up_issues_a_fresh_challenge() -> void:
	# Otherwise the answer could be memorised from a previous visit.
	var seen: Dictionary[String, bool] = {}
	for _attempt: int in 20:
		welcome.toggle.selected = SIGN_UP_TAB
		seen[welcome.adult_challenge.code] = true
		welcome.toggle.selected = LOGIN_TAB
	assert_gt(seen.size(), 1, "the challenge should not be the same every visit")


func test_the_tabs_use_action_labels() -> void:
	# LOGIN translates to "Identifiants"/"Credenziali", which labels a form
	# rather than an action, so the tab uses LOG_IN instead.
	assert_eq(welcome.toggle.options[0], "LOG_IN")
	assert_eq(welcome.toggle.options[1], "SIGN_UP")


func test_forgot_password_is_hidden_until_a_login_fails() -> void:
	assert_false(welcome.reset_password_button.visible,
		"the reset offer should not be there before an attempt has failed")
	assert_eq(welcome.reset_password_button.text, "FORGOT_PASSWORD")


func test_a_wrong_password_offers_a_reset() -> void:
	welcome._show_login_error("LOGIN_WRONG_PASSWORD")

	assert_true(welcome.reset_password_button.visible,
		"a wrong password is the failure a reset fixes")
	assert_false(welcome.reset_password_button.disabled)


func test_other_failures_do_not_offer_a_reset() -> void:
	# Resetting cannot help an unknown account, and the network failures could
	# not send the mail anyway.
	for key: String in ["LOGIN_USER_NOT_FOUND", "LOGIN_NETWORK_ERROR",
			"LOGIN_SERVER_ERROR", "LOGIN_MISSING_CREDENTIALS",
			"INVALID_EMAIL_OR_PASSWORD"]:
		welcome._show_login_error(key)
		assert_false(welcome.reset_password_button.visible,
			"%s should not offer a password reset" % key)


func test_editing_the_form_withdraws_the_reset_offer() -> void:
	welcome._show_login_error("LOGIN_WRONG_PASSWORD")

	welcome.email_field.input.text = "someone@example.org"
	welcome.email_field.input.text_changed.emit("someone@example.org")

	assert_false(welcome.login_error.visible, "the stale error should go")
	assert_false(welcome.reset_password_button.visible,
		"the offer belongs to the failed attempt, not to the new one")


func test_switching_tabs_withdraws_the_reset_offer() -> void:
	welcome._show_login_error("LOGIN_WRONG_PASSWORD")

	welcome.toggle.selected = SIGN_UP_TAB
	await get_tree().process_frame
	welcome.toggle.selected = LOGIN_TAB
	await get_tree().process_frame

	assert_false(welcome.reset_password_button.visible,
		"coming back to a fresh login form should not still offer a reset")


func _code_other_than(code: String) -> String:
	for value: int in TeacherSettings.AVAILABLE_CODES:
		if str(value) != code:
			return str(value)
	return code


# --- Language selector -------------------------------------------------------
# The language really is applied on selection, which means writing it to the
# device settings on disk. These tests put it back afterwards, unconditionally,
# so a failure part-way through cannot leave the machine in another language.
func _language_field() -> OptionButton:
	return welcome.get_node("KeyboardSpacer/Scroll/Content/LoginPanel/LanguageField")


func _index_of(field: OptionButton, locale: String) -> int:
	return (field.items as Array[String]).find(locale)


# Switching language points the database at that language's pack, and only one
# pack is installed here, so the switch warns about the others. That is inherent
# to what is being tested. Must run inside the test: GUT checks for unhandled
# errors before after_each().
func _accept_the_missing_pack_warnings() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_the_language_selector_is_wired_to_something() -> void:
	# Regression: the field was carried over from the old main menu without the
	# connection that scene made for it, so choosing a language did nothing at
	# all. Nothing errored -- the field just showed one language while the app
	# stayed in another.
	var field: OptionButton = _language_field()

	assert_gt(field.item_count, 1, "there should be languages to choose between")
	assert_true(field.item_selected.get_connections().size() > 0,
		"choosing a language has to reach something")


func test_choosing_a_language_applies_it() -> void:
	var field: OptionButton = _language_field()
	var original: String = UserDataManager.get_device_settings().language
	var target: String = "fr_FR" if original != "fr_FR" else "pt_BR"
	var index: int = _index_of(field, target)
	assert_gte(index, 0, "%s should be one of the supported locales" % target)

	field.item_selected.emit(index)

	assert_eq(UserDataManager.get_device_settings().language, target,
		"the chosen language should be the device's language")
	assert_eq(TranslationServer.get_locale(), target,
		"and the interface should already be reading from it")

	UserDataManager.set_language(original)
	_accept_the_missing_pack_warnings()
	assert_eq(UserDataManager.get_device_settings().language, original,
		"the test should leave the device on the language it found it in")


func test_the_selector_opens_on_the_language_in_use() -> void:
	# Otherwise it claims the app is in a language it is not, which is how the
	# broken selector looked once something had been chosen.
	var field: OptionButton = _language_field()
	var current: String = UserDataManager.get_device_settings().language
	if _index_of(field, current) < 0:
		pending("the device is on %s, which is not a supported locale" % current)
		return

	assert_eq((field.items as Array[String])[field.get_selected_id()], current,
		"the field should show the language the app is running in")

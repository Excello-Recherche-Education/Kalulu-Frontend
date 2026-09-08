extends GutTest
## Wiring of the unified welcome screen.
##
## Covers the structure and tab behaviour rather than the network calls: the
## login request goes through ServerManager, which these tests do not stand up.

const WELCOME_SCENE: String = "res://sources/menus/welcome/welcome.tscn"
const REFERENCE_VIEWPORT: Vector2i = Vector2i(2560, 1800)
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


func test_a_failure_message_is_scrolled_into_view() -> void:
	# The message and the reset offer are added under the fields, and on a screen
	# this short that puts them past the bottom of the column. The column scrolls
	# and starts at the top, so the reply to a failed login would be off screen.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var screen: Control = (load(WELCOME_SCENE) as PackedScene).instantiate()
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	screen._show_login_error("LOGIN_WRONG_PASSWORD")
	await get_tree().process_frame
	await get_tree().process_frame

	var error: Control = screen.login_error
	var visible_area: Rect2 = screen.scroll.get_global_rect()
	assert_lte(error.get_global_rect().end.y, visible_area.end.y + 1.0,
		"the message should have been scrolled into the visible column")
	assert_gte(error.global_position.y, visible_area.position.y - 1.0,
		"and not past the top of it")


func test_the_longest_message_still_fits_in_the_column() -> void:
	# The blocked-network message carries the domains for whoever runs the network, so
	# it is several times longer than the rest and wraps to a handful of lines. The
	# column scrolls, so the risk is not that it overflows the screen but that the end
	# of it -- which is where the domains are -- lands below the visible area.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var screen: Control = (load(WELCOME_SCENE) as PackedScene).instantiate()
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	screen._show_login_error("LOGIN_KALULU_BLOCKED")
	await get_tree().process_frame
	await get_tree().process_frame

	var error: Control = screen.login_error
	assert_gt(error.get_global_rect().size.y, 0.0, "the label should have been laid out")
	var visible_area: Rect2 = screen.scroll.get_global_rect()
	assert_lte(error.get_global_rect().end.y, visible_area.end.y + 1.0,
		"the domains at the end of it should be inside the visible column")
	assert_lte(error.get_global_rect().size.y, visible_area.size.y,
		"a message taller than the column could never be shown whole")


func test_the_domains_are_never_split_across_lines() -> void:
	# What the label was too narrow for: the pack host broke mid-name, and with the
	# text centred the tail read as a third domain sitting underneath. Nobody can
	# copy a hostname out of that. The message is for whoever runs the network, so
	# each domain has to arrive whole, on its own line.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var screen: Control = (load(WELCOME_SCENE) as PackedScene).instantiate()
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	screen._show_login_error("LOGIN_KALULU_BLOCKED")
	await get_tree().process_frame

	var label: Label = screen.login_error
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var available: float = label.get_global_rect().size.x
	for line: String in tr("LOGIN_KALULU_BLOCKED").split("\n"):
		if not line.begins_with("•"):
			continue
		var needed: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(needed, available,
			"\"%s\" needs %d px and the label offers %d" % [line, needed, available])


# --- Handing the failure on ---------------------------------------------------

func test_only_the_failures_somebody_else_can_fix_are_worth_copying() -> void:
	# A wrong password is the reader's own to fix; mailing it to a technician would
	# send them down a corridor for nothing. The three below are the network's and
	# the server's, and the blocked one carries the domains to unblock.
	for key: String in Welcome.REPORTABLE_ERRORS:
		assert_true(Welcome.offers_copy(key, true), "%s is worth handing on" % key)
	for key: String in ["LOGIN_WRONG_PASSWORD", "LOGIN_USER_NOT_FOUND",
			"LOGIN_MISSING_CREDENTIALS", "INVALID_EMAIL_OR_PASSWORD"]:
		assert_false(Welcome.offers_copy(key, true), "%s is the reader's own to fix" % key)


func test_the_wait_for_a_diagnosis_is_said_out_loud_and_not_offered_for_copy() -> void:
	# A failure with no HTTP response has to be diagnosed before it can be described,
	# and that probe can take its full 15 seconds on the very networks this is for.
	# Answering the press with nothing for that long is the dead-button complaint all
	# over again -- so the screen says what it is doing. It is not a verdict, so
	# there is nothing to hand on to anybody yet.
	assert_false(Welcome.offers_copy(Welcome.DIAGNOSING_ERROR, true),
		"a diagnosis still in progress is nobody else's to act on")
	for language: String in TranslationServer.get_loaded_locales():
		var translation: Translation = TranslationServer.get_translation_object(language)
		if not translation:
			continue
		assert_ne(translation.get_message(Welcome.DIAGNOSING_ERROR), "",
			"%s should be translated into %s" % [Welcome.DIAGNOSING_ERROR, language])


func test_nothing_is_offered_where_there_is_no_clipboard() -> void:
	# Pressing it would do nothing and then claim it had.
	for key: String in Welcome.REPORTABLE_ERRORS:
		assert_false(Welcome.offers_copy(key, false), "%s has nowhere to copy to" % key)


func test_the_report_carries_what_its_reader_asks_first() -> void:
	var report: String = Utils.support_report("le message", HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR)
	assert_string_contains(report, "le message", "the message the reader saw")
	assert_string_contains(report, Utils.get_application_version_with_code(),
		"which build it came from")
	assert_string_contains(report, "RESULT_TLS_HANDSHAKE_ERROR",
		"and what failed -- this one says the connection was intercepted, not dropped")


func test_the_report_does_not_sign_itself_off_as_a_success() -> void:
	# Nothing failed at that level, so naming the result would contradict the message
	# above it, and be the first thing a technician queried.
	var report: String = Utils.support_report("le message", HTTPRequest.RESULT_SUCCESS)
	assert_false(report.contains("RESULT_SUCCESS"), "a report cannot report success")
	assert_string_contains(report, Utils.get_application_version_with_code(),
		"the build still goes with it")


func test_the_copy_offer_is_translated() -> void:
	for key: String in ["COPY_ERROR_MESSAGE", "ERROR_MESSAGE_COPIED"]:
		assert_ne(tr(key), key, "%s should be translated" % key)


func test_the_copy_offer_is_scrolled_into_view() -> void:
	# It sits under a message long enough to leave it below the fold, so the one
	# control the reader is invited to press would be the one thing off screen.
	# Shown by hand: headless has no clipboard, so the screen would not offer it.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var screen: Control = (load(WELCOME_SCENE) as PackedScene).instantiate()
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	screen._show_login_error("LOGIN_KALULU_BLOCKED")
	screen.copy_error_button.show()
	await screen._scroll_to_login_error()
	await get_tree().process_frame

	var button: Rect2 = screen.copy_error_button.get_global_rect()
	var visible_area: Rect2 = screen.scroll.get_global_rect()
	assert_lte(button.end.y, visible_area.end.y + 1.0, "the offer should be in the column")
	assert_gte(button.position.y, visible_area.position.y - 1.0, "and not above it")


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
	return welcome.get_node("KeyboardSpacer/FooterRoom/Scroll/Content/LoginPanel/LanguageField")


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


# --- One request at a time ----------------------------------------------------
# ServerManager owns a single HTTPRequest and a single set of result fields, and
# every caller awaits the same request_completed signal. A second request started
# before the first answers is refused as busy, resets the result the first one is
# waiting on, and leaves both reading whichever reply arrives -- so a perfectly
# good login can surface as a server error.
#
# These drive the guard rather than the request: starting a real login here would
# reach the live server.
func test_the_password_field_stays_usable_while_a_login_runs() -> void:
	# Which is why disabling Next is not enough on its own, and why the guard is
	# a flag rather than a disabled control.
	assert_false(welcome.password_field.input.editable == false,
		"the field is deliberately left editable, so Enter can still fire")


func test_a_second_submit_is_ignored_while_a_login_is_in_flight() -> void:
	welcome.email_field.text = "teacher@example.org"
	welcome.password_field.text = "aValidPassword1"
	welcome.request_in_flight = true

	welcome._on_password_submitted("aValidPassword1")

	assert_false(welcome.next_button.disabled,
		"the guard should return before a second request is started")


func test_the_button_and_enter_share_the_guard() -> void:
	# They are the same path: Enter calls the button's handler.
	welcome.email_field.text = "teacher@example.org"
	welcome.password_field.text = "aValidPassword1"
	welcome.request_in_flight = true

	welcome._on_next_pressed()

	assert_false(welcome.next_button.disabled, "pressing Next should be ignored too")


func test_a_reset_is_ignored_while_a_request_is_in_flight() -> void:
	# The reset goes through the same HTTPRequest, so it can collide with a login
	# just as readily.
	welcome.request_in_flight = true
	welcome.reset_password_button.disabled = false

	welcome._on_reset_password_pressed()

	assert_false(welcome.reset_password_button.disabled,
		"the reset should not have started either")


func test_finishing_a_request_makes_the_screen_usable_again() -> void:
	# A refused login has to be retryable, or one wrong password locks the screen.
	# Regression: this restored only Next, so a reset that failed on a transient
	# network error left "Forgot password?" on screen and permanently dead -- until
	# another failed login happened to re-enable it.
	welcome.request_in_flight = true
	welcome.next_button.disabled = true
	welcome.reset_password_button.disabled = true

	welcome._end_request()

	assert_false(welcome.request_in_flight)
	assert_false(welcome.next_button.disabled, "Next should come back")
	assert_false(welcome.reset_password_button.disabled,
		"and so should the reset, or a failed one can never be retried")


func test_nothing_is_in_flight_when_the_screen_opens() -> void:
	assert_false(welcome.request_in_flight)
	assert_false(welcome.next_button.disabled)


# --- One half of the screen at a time --------------------------------------------
func test_the_switch_is_locked_while_the_server_is_being_waited_on() -> void:
	# Regression: it stayed open, so the teacher could go to Sign Up mid-login. The
	# reply still signs the account in and writes it to disk, and the synchronisation
	# after that runs long enough for the adult challenge to be answered in the middle
	# of it -- which starts registration on a device already signed in as someone else.
	assert_false(welcome.toggle.disabled, "the switch is open to begin with")

	welcome._set_request_in_flight(true)

	assert_true(welcome.request_in_flight)
	assert_true(welcome.toggle.disabled, "the switch should be locked for the wait")
	for button: Button in welcome.toggle.buttons:
		assert_true(button.disabled, "including the segment that leads to Sign Up")


func test_the_switch_comes_back_when_the_request_ends() -> void:
	# Both ways out of a request go through here. A switch left locked would strand
	# the teacher on whichever half they were on.
	welcome._set_request_in_flight(true)

	welcome._end_request()

	assert_false(welcome.request_in_flight)
	assert_false(welcome.toggle.disabled, "the switch should open again")
	assert_false(welcome.next_button.disabled, "and so should the action")


func test_the_switch_comes_back_after_a_password_reset_too() -> void:
	# The reset's success path does not go through _end_request, because its button
	# deliberately stays disabled -- but nothing is outstanding, so the switch opens.
	welcome._set_request_in_flight(true)

	welcome._set_request_in_flight(false)

	assert_false(welcome.toggle.disabled)

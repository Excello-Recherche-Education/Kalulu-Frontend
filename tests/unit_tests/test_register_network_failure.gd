extends GutTest
## What registration says when the network, rather than the teacher, is the problem.
##
## Both of its requests used to blame her for it. The email step answered every
## non-200 with "this address is already used" -- a claim about data the server never
## looked at -- and the final submit put "Une erreur est survenue" over an empty card,
## after the whole wizard had been filled in.
##
## The decisions are extracted, so none of this needs a server: register.gd's _submit
## reaches the network and is deliberately not exercised.

const REGISTER_SCENE: String = "res://sources/menus/register/register.tscn"
const CREDENTIALS_STEP: String = "res://sources/menus/register/steps/credentials_step.tscn"

var wizard: Control


func before_each() -> void:
	wizard = (load(REGISTER_SCENE) as PackedScene).instantiate()
	add_child_autofree(wizard)
	await get_tree().process_frame


func after_each() -> void:
	# Only the step on screen is a child of anything, so freeing the wizard does not
	# take the rest of current_steps with it.
	for step: Step in wizard.current_steps:
		if is_instance_valid(step) and not step.is_inside_tree():
			step.free()


# --- The email step ------------------------------------------------------------

func test_only_a_400_is_about_the_address() -> void:
	# The backend uses it for both of the address's own problems: already registered,
	# or malformed. Nothing else it can answer says a word about the address.
	assert_true(CredentialsStep.is_about_the_address(400))
	for code: int in [0, 200, 401, 403, 404, 429, 500, 502, 503]:
		assert_false(CredentialsStep.is_about_the_address(code),
			"%d must not be reported as the address being taken" % code)


func test_the_address_message_is_translated() -> void:
	# It was in no locale at all, so a teacher whose address really was registered
	# read the raw key: USED_EMAIL_ADDRESS, in capitals, under the field.
	assert_ne(tr("USED_EMAIL_ADDRESS"), "USED_EMAIL_ADDRESS")


func test_the_email_step_still_carries_that_message() -> void:
	var step: Step = (load(CREDENTIALS_STEP) as PackedScene).instantiate()
	autofree(step)
	var label: Label = step.find_child("APIEmailFieldError", true, false) as Label
	assert_not_null(label, "the field keeps its own one-line message")
	assert_eq(label.text, "USED_EMAIL_ADDRESS",
		"and it is the one the 400 branch shows")


func test_a_step_can_hand_a_failed_request_to_the_wizard() -> void:
	# The step has no dialog and its field messages are one line each: a column that
	# grows past them prints over the footer buttons, which has happened before. So
	# the diagnosis goes to the wizard's card, which has the room.
	var step: Step = wizard.current_steps[0]
	assert_true(step.has_signal("request_failed"), "every step can report one")
	assert_true(step.request_failed.is_connected(wizard._on_step_request_failed),
		"and the wizard is listening to the step on screen")


# --- Which notice the card carries ---------------------------------------------

func test_a_blocked_network_says_so_and_names_the_domains() -> void:
	var notice: Dictionary = wizard.notice_for(0, true)
	assert_eq(notice["title"], "KALULU_BLOCKED_TITLE")
	assert_string_contains(tr(str(notice["message"])), "kalulu-app-language-packs",
		"the domains are the whole point of this one")


func test_no_network_at_all_asks_for_a_connection() -> void:
	var notice: Dictionary = wizard.notice_for(0, false)
	assert_eq(notice["title"], "NO_LANGUAGE_PACK_TITLE")
	assert_ne(tr(str(notice["message"])), str(notice["message"]), "and it is translated")


func test_a_server_failure_is_not_blamed_on_the_connection() -> void:
	for code: int in [500, 502, 503, 504]:
		var notice: Dictionary = wizard.notice_for(code, false)
		assert_eq(notice["title"], "SERVER_UNAVAILABLE_TITLE",
			"%d came from the server, so it is the server's" % code)


func test_anything_else_leaves_room_for_the_server_s_own_words() -> void:
	# A 4xx is this registration's own -- an address refused, a field rejected -- and
	# the backend says which. An empty message is how _show_failure knows to use it.
	var notice: Dictionary = wizard.notice_for(409, false)
	assert_eq(notice["title"], "REGISTER_FAILED")
	assert_eq(notice["message"], "", "so the server's message is shown instead")


# --- The offer to copy ----------------------------------------------------------

func test_only_what_somebody_else_can_fix_is_worth_copying() -> void:
	for code: int in [0, 500, 502, 503]:
		assert_true(wizard.is_reportable(code), "%d is not hers to fix" % code)
	for code: int in [400, 401, 403, 404, 409]:
		assert_false(wizard.is_reportable(code),
			"%d is this registration's own, and no use to a technician" % code)


func test_the_card_holds_the_domains_without_breaking_them() -> void:
	# Split over two lines a hostname is no use to the person the notice is for. The
	# card is wider than the login column, so this passes where that one needed
	# widening -- but it has to keep passing.
	wizard.popup_info_label.text = tr("REGISTER_KALULU_BLOCKED")
	wizard.popup.show()
	await get_tree().process_frame
	await get_tree().process_frame

	var label: Label = wizard.popup_info_label
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var available: float = label.get_global_rect().size.x
	for line: String in tr("REGISTER_KALULU_BLOCKED").split("\n"):
		if not line.begins_with("•"):
			continue
		var needed: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(needed, available,
			"\"%s\" needs %d px and the card offers %d" % [line, needed, available])

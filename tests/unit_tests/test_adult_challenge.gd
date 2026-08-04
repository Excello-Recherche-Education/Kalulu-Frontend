extends GutTest
## The "prove you are an adult" test the three gates share.
##
## Three screens ask it -- the boss minigame's block, the Sign Up tab and the way
## into the teacher settings -- and each drew its own copy before, including a
## second table of symbol names that could drift out of step with Design's.


func test_it_asks_for_a_code_the_keypad_can_produce() -> void:
	# Anything outside that set could not be answered at all.
	for _attempt: int in 20:
		var challenge: AdultChallenge = AdultChallenge.new()
		assert_has(TeacherSettings.AVAILABLE_CODES, int(challenge.code),
			"%s should be one of the student codes" % challenge.code)
		assert_eq(challenge.code.length(), 3, "and three symbols long")


func test_the_instruction_names_the_symbols_in_order() -> void:
	var challenge: AdultChallenge = AdultChallenge.new()

	var instruction: String = challenge.prompt("ADULT_CHECK_PROMPT")

	var last_position: int = -1
	for digit: String in challenge.code.split("", false):
		var symbol: String = tr(Design.code_symbol_name(digit))
		var position: int = instruction.find(symbol)
		assert_gt(position, -1, "the instruction should name %s" % symbol)
		assert_gt(position, last_position,
			"%s should be named after the symbol before it" % symbol)
		last_position = position


func test_it_accepts_only_the_answer_it_asked_for() -> void:
	var challenge: AdultChallenge = AdultChallenge.new()

	assert_true(challenge.accepts(challenge.code))
	assert_false(challenge.accepts(""), "an empty answer is not the answer")
	assert_false(challenge.accepts(challenge.code.reverse()) if
		challenge.code != challenge.code.reverse() else false,
		"the order of the symbols matters")
	for code: int in TeacherSettings.AVAILABLE_CODES:
		if str(code) != challenge.code:
			assert_false(challenge.accepts(str(code)),
				"%d is not the code being asked for" % code)
			break


func test_renewing_asks_something_else() -> void:
	# Otherwise the answer could be memorised from a previous attempt.
	var challenge: AdultChallenge = AdultChallenge.new()
	var seen: Dictionary[String, bool] = {}
	for _attempt: int in 30:
		challenge.renew()
		seen[challenge.code] = true

	assert_gt(seen.size(), 1, "the challenge should not always be the same")


func test_the_symbol_names_come_from_one_place() -> void:
	# The boss block used to keep its own copy of this table.
	for digit: String in Design.CODE_KEYPAD_ORDER:
		assert_ne(tr(Design.code_symbol_name(digit)), Design.code_symbol_name(digit),
			"symbol %s should have a translated name" % digit)


func test_both_gates_ask_with_their_own_wording() -> void:
	# The same challenge, phrased for where it appears.
	var challenge: AdultChallenge = AdultChallenge.new()
	for key: String in ["ADULT_CHECK_PROMPT", "ADULT_BOSS_BLOCK_PROMPT"]:
		var instruction: String = challenge.prompt(key)
		assert_false(instruction.contains("{1}"), "%s should have its symbols filled in" % key)
		assert_ne(instruction, key, "%s should be translated" % key)


# --- The dialog the teacher settings put it behind ----------------------------
# Mounted on its own rather than through the login screen: that screen's _ready
# navigates away when no language pack is installed. The popup itself needs
# nothing but the challenge.
const POPUP_SCENE: String = "res://sources/ui/adult_check_popup.tscn"


func _popup() -> AdultCheckPopup:
	var popup: AdultCheckPopup = (load(POPUP_SCENE) as PackedScene).instantiate()
	add_child_autofree(popup)
	await get_tree().process_frame
	return popup


func test_the_dialog_starts_out_of_the_way() -> void:
	var popup: AdultCheckPopup = await _popup()

	assert_false(popup.visible, "a CanvasLayer defaults to visible, so this has to be turned off")


func test_opening_it_asks_something_and_shows_it() -> void:
	var popup: AdultCheckPopup = await _popup()

	popup.open()
	await get_tree().process_frame

	assert_true(popup.visible)
	for digit: String in popup.challenge.code.split("", false):
		assert_string_contains(popup.prompt_label.text, tr(Design.code_symbol_name(digit)),
			"the instruction should name symbol %s" % digit)
	assert_eq(popup.keypad.code, "", "and start from an empty keypad")


func test_a_wrong_answer_asks_again_rather_than_refusing() -> void:
	# Nothing to learn by guessing.
	var popup: AdultCheckPopup = await _popup()
	popup.open()
	await get_tree().process_frame
	watch_signals(popup)

	popup._on_code_entered("000")

	assert_true(popup.visible, "it should still be asking")
	assert_signal_not_emitted(popup, "passed")
	assert_eq(popup.keypad.code, "", "and the keypad should be clear for another go")


func test_the_right_answer_passes_and_gets_out_of_the_way() -> void:
	var popup: AdultCheckPopup = await _popup()
	popup.open()
	await get_tree().process_frame
	watch_signals(popup)

	popup._on_code_entered(popup.challenge.code)

	assert_signal_emitted(popup, "passed")
	assert_false(popup.visible)


func test_closing_it_cancels_without_passing() -> void:
	var popup: AdultCheckPopup = await _popup()
	popup.open()
	await get_tree().process_frame
	watch_signals(popup)

	popup._on_close_pressed()

	assert_signal_emitted(popup, "cancelled")
	assert_signal_not_emitted(popup, "passed")
	assert_false(popup.visible)


func test_reopening_it_asks_something_new() -> void:
	var popup: AdultCheckPopup = await _popup()
	var seen: Dictionary[String, bool] = {}
	for _attempt: int in 20:
		popup.open()
		seen[popup.challenge.code] = true

	assert_gt(seen.size(), 1, "a memorised answer should not keep working")

extends GutTest
## Behaviour of the Login | Sign Up pill switch.

const TOGGLE_SCENE: String = "res://sources/ui/segmented_toggle.tscn"

var toggle: SegmentedToggle


func before_each() -> void:
	toggle = (load(TOGGLE_SCENE) as PackedScene).instantiate()
	add_child_autofree(toggle)
	# Containers only lay out on the next frame, and the highlight geometry is
	# derived from the laid-out segment width.
	toggle.size = Vector2(Design.CONTENT_WIDTH, Design.TOGGLE_HEIGHT)
	await wait_for_signal(toggle.resized, 1.0)
	await get_tree().process_frame


func test_the_capsule_looks_right_before_anything_is_laid_out() -> void:
	# Regression: the capsule was only styled inside _move_highlight, which bails
	# out while the segment row still has no width -- which it does not have during
	# _ready. So on arrival the highlight showed the engine's default square grey
	# panel, and only turned into the purple capsule once the selection changed.
	var fresh: SegmentedToggle = (load(TOGGLE_SCENE) as PackedScene).instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame

	var box: StyleBox = fresh.highlight.get_theme_stylebox("panel")
	assert_true(box is StyleBoxFlat, "the capsule should be a flat box")
	var flat: StyleBoxFlat = box as StyleBoxFlat
	assert_eq(flat.bg_color, Design.PURPLE, "the capsule should be purple from the start")
	assert_gt(flat.corner_radius_top_left, 0,
		"the capsule should be rounded from the start, not square")


func test_the_capsule_is_rounded_to_a_full_half_circle() -> void:
	var expected: int = floori(float(Design.TOGGLE_HEIGHT - 2 * Design.TOGGLE_INSET) / 2)
	var flat: StyleBoxFlat = toggle.highlight.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(flat.corner_radius_top_left, expected,
		"the capsule's radius should be half its height")


func test_it_builds_one_segment_per_option() -> void:
	assert_eq(toggle.buttons.size(), 2, "the default options should give two segments")
	# LOG_IN, not LOGIN: the latter translates to "Identifiants"/"Credenziali",
	# which labels a form rather than an action.
	assert_eq(toggle.buttons[0].text, "LOG_IN")
	assert_eq(toggle.buttons[1].text, "SIGN_UP")


func test_the_first_option_starts_selected() -> void:
	assert_eq(toggle.selected, 0)
	assert_true(toggle.buttons[0].button_pressed, "the first segment should be pressed")
	assert_false(toggle.buttons[1].button_pressed, "the second segment should not be pressed")


func test_selecting_emits_the_new_index() -> void:
	watch_signals(toggle)

	toggle.selected = 1

	assert_signal_emitted_with_parameters(toggle, "selection_changed", [1])
	assert_true(toggle.buttons[1].button_pressed, "the chosen segment should be pressed")
	assert_false(toggle.buttons[0].button_pressed, "the other segment should be released")


func test_reselecting_the_current_option_emits_nothing() -> void:
	watch_signals(toggle)

	toggle.selected = 0

	assert_signal_not_emitted(toggle, "selection_changed",
		"reselecting the current option should not emit")


func test_pressing_a_segment_selects_it() -> void:
	watch_signals(toggle)

	toggle.buttons[1].emit_signal("pressed")

	assert_eq(toggle.selected, 1, "pressing a segment should select it")
	assert_signal_emitted_with_parameters(toggle, "selection_changed", [1])


func test_restoring_state_does_not_emit() -> void:
	# Used when returning to the screen so it opens on the tab the user left.
	watch_signals(toggle)

	toggle.set_selected_silently(1)

	assert_eq(toggle.selected, 1)
	assert_signal_not_emitted(toggle, "selection_changed",
		"restoring state should not look like a user action")


func test_out_of_range_selections_are_clamped() -> void:
	toggle.selected = 9
	assert_eq(toggle.selected, 1, "a too-large index should clamp to the last option")

	toggle.selected = -4
	assert_eq(toggle.selected, 0, "a negative index should clamp to the first option")


func test_segments_share_the_width_equally() -> void:
	# Deliberately not content-hugging: see the note on SegmentedToggle. The
	# highlight has to line up with the selected segment at every size.
	var expected_width: float = toggle.segments.size.x / 2.0
	assert_almost_eq(toggle.highlight.size.x, expected_width, 1.0,
		"the highlight should cover exactly one segment")
	assert_almost_eq(toggle.highlight.position.x, toggle.segments.position.x, 1.0,
		"the highlight should start on the first segment")

	toggle.set_selected_silently(1)

	assert_almost_eq(toggle.highlight.position.x,
		toggle.segments.position.x + expected_width, 1.0,
		"the highlight should move a whole segment across")


func test_changing_options_rebuilds_the_segments() -> void:
	toggle.options = ["ONE", "TWO", "THREE"]

	assert_eq(toggle.buttons.size(), 3, "the segments should follow the options")
	assert_eq(toggle.buttons[2].text, "THREE")


func test_shrinking_the_options_clamps_the_selection() -> void:
	toggle.set_selected_silently(1)

	toggle.options = ["ONLY"]

	assert_eq(toggle.selected, 0, "the selection should clamp when options shrink")
	assert_eq(toggle.buttons.size(), 1)


# --- Locking ---------------------------------------------------------------------
func test_a_locked_switch_stops_answering() -> void:
	toggle.disabled = true

	for button: Button in toggle.buttons:
		assert_true(button.disabled, "%s should not answer while the switch is locked" % button.text)


func test_unlocking_gives_it_back() -> void:
	toggle.disabled = true

	toggle.disabled = false

	for button: Button in toggle.buttons:
		assert_false(button.disabled, "%s should answer again" % button.text)


func test_the_lock_survives_the_segments_being_rebuilt() -> void:
	# Changing the options rebuilds the buttons, and a fresh button answers unless it
	# is told otherwise -- which would quietly unlock the switch.
	toggle.disabled = true

	toggle.options = PackedStringArray(["LOG_IN", "SIGN_UP", "LOG_IN"])

	assert_eq(toggle.buttons.size(), 3, "the segments should have been rebuilt")
	for button: Button in toggle.buttons:
		assert_true(button.disabled, "a rebuilt segment should still be locked")


func test_locking_does_not_change_which_segment_is_chosen() -> void:
	watch_signals(toggle)
	# The one emission the test allows: choosing a segment is a real change.
	toggle.selected = 1

	toggle.disabled = true

	assert_eq(toggle.selected, 1, "the lock holds the switch, it does not move it")
	assert_signal_emit_count(toggle, "selection_changed", 1,
		"locking is not a change of selection and must not announce one")

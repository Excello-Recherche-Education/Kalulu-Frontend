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


func test_it_builds_one_segment_per_option() -> void:
	assert_eq(toggle.buttons.size(), 2, "the default options should give two segments")
	assert_eq(toggle.buttons[0].text, "LOGIN")
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

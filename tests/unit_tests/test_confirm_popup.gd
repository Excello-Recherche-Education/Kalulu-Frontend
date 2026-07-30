extends GutTest
## Behaviour of the shared confirm dialog.
##
## Five screens instance this one scene, so its button wiring is worth pinning:
## a confirm that emitted `refused` would delete the wrong things quietly.

const POPUP_SCENE: String = "res://sources/ui/popup.tscn"

var popup: ConfirmPopup


func before_each() -> void:
	popup = (load(POPUP_SCENE) as PackedScene).instantiate()
	add_child_autofree(popup)
	await get_tree().process_frame


func test_a_dialog_scene_is_hidden_before_anyone_shows_it() -> void:
	# The root is a CanvasLayer, which defaults to visible, so every scene that
	# instanced one had to remember `visible = false` -- and a scene that forgot
	# drew its dialogs over the whole screen. The default now lives here instead.
	var fresh: ConfirmPopup = (load(POPUP_SCENE) as PackedScene).instantiate()
	autofree(fresh)
	assert_false(fresh.visible, "a dialog should not be on screen until shown")


func test_confirming_accepts_and_closes() -> void:
	watch_signals(popup)
	popup.show()

	popup.confirm_button.pressed.emit()

	assert_signal_emitted(popup, "accepted")
	assert_signal_not_emitted(popup, "refused")
	assert_false(popup.visible, "confirming should close the dialog")


func test_cancelling_refuses_and_closes() -> void:
	watch_signals(popup)
	popup.show()

	popup.cancel_button.pressed.emit()

	assert_signal_emitted(popup, "refused")
	assert_signal_not_emitted(popup, "accepted")
	assert_false(popup.visible, "cancelling should close the dialog")


func test_the_close_cross_refuses_rather_than_confirms() -> void:
	# The cross is new in the redesign. Wiring it to confirm would turn
	# "dismiss this" into "yes, delete it".
	watch_signals(popup)
	popup.show()

	popup.close_button.pressed.emit()

	assert_signal_emitted(popup, "refused")
	assert_signal_not_emitted(popup, "accepted",
		"dismissing a dialog must never count as agreeing to it")


func test_close_on_action_can_keep_the_dialog_open() -> void:
	popup.close_on_action = false
	popup.show()

	popup.confirm_button.pressed.emit()

	assert_true(popup.visible, "a dialog that reports progress stays up")


func test_the_title_is_hidden_until_one_is_given() -> void:
	assert_false(popup.title_label.visible,
		"a dialog that reads as one sentence should not show an empty heading")

	popup.title_text = "DELETE_STUDENT"

	assert_true(popup.title_label.visible)
	assert_eq(popup.title_label.text, "DELETE_STUDENT")


func test_button_labels_can_be_overridden() -> void:
	var custom: ConfirmPopup = (load(POPUP_SCENE) as PackedScene).instantiate()
	custom.confirm_text_override = "DELETE"
	custom.cancel_text_override = "CLOSE"
	add_child_autofree(custom)
	await get_tree().process_frame

	assert_eq(custom.confirm_button.text, "DELETE")
	assert_eq(custom.cancel_button.text, "CLOSE")


func test_cancel_sits_before_confirm() -> void:
	# The hand-off puts Cancel on the left and the action on the right; the old
	# dialog had them the other way round.
	var row: HBoxContainer = popup.cancel_button.get_parent()
	assert_lt(row.get_children().find(popup.cancel_button),
		row.get_children().find(popup.confirm_button),
		"Cancel should come before the confirming action")


func test_it_survives_a_dialog_built_without_the_new_chrome() -> void:
	# Regression: three screens build their dialog inline with this script rather
	# than instancing popup.tscn, and those copies have no heading and no close
	# cross. Requiring them crashed the language check and the package downloader
	# on every launch -- which no unit test saw, because they all used the scene.
	var bare: ConfirmPopup = ConfirmPopup.new()
	var content: Label = Label.new()
	content.name = "ContentLabel"
	var confirm: Button = Button.new()
	confirm.name = "ConfirmButton"
	var cancel: Button = Button.new()
	cancel.name = "CancelButton"
	# Assembled before entering the tree: _ready fires on add_child, and it is
	# _ready that has to cope with the missing nodes.
	for child: Node in [content, confirm, cancel]:
		bare.add_child(child)
		child.owner = bare
		child.unique_name_in_owner = true
	add_child_autofree(bare)
	await get_tree().process_frame

	assert_null(bare.title_label, "a bare dialog has no heading")
	assert_null(bare.close_button, "a bare dialog has no close cross")

	bare.title_text = "IGNORED"
	bare.content_text = "SOMETHING"

	assert_eq(bare.content_label.text, "SOMETHING",
		"the parts that do exist should still work")


func test_the_dialog_uses_the_redesigned_styles() -> void:
	assert_eq(popup.confirm_button.theme_type_variation, MenuTheme.VARIATION_PRIMARY_BUTTON)
	assert_eq(popup.cancel_button.theme_type_variation,
		MenuTheme.VARIATION_CARD_SECONDARY_BUTTON,
		"on a white card the secondary button needs the navy outline")
	assert_eq(popup.content_label.theme_type_variation, MenuTheme.VARIATION_CARD_BODY)

extends GutTest
## The volume button and the dialog it opens.
##
## The levels are written to the device settings on disk as the sliders move, so
## every test here puts back what it found. A failure part-way through must not
## leave the machine on a different volume.

const SCENE: String = "res://sources/menus/settings/sound_settings_button.tscn"
const REFERENCE_VIEWPORT: Vector2i = Vector2i(2560, 1800)

var original_levels: Array[float] = []


func before_each() -> void:
	original_levels = [UserDataManager.get_master_volume(), UserDataManager.get_music_volume(),
		UserDataManager.get_voice_volume(), UserDataManager.get_effects_volume()]


func after_each() -> void:
	UserDataManager.set_master_volume(original_levels[0])
	UserDataManager.set_music_volume(original_levels[1])
	UserDataManager.set_voice_volume(original_levels[2])
	UserDataManager.set_effects_volume(original_levels[3])


func _mounted() -> TextureButton:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = REFERENCE_VIEWPORT
	add_child_autofree(viewport)
	var button: TextureButton = (load(SCENE) as PackedScene).instantiate()
	viewport.add_child(button)
	await get_tree().process_frame
	return button


func _opened() -> TextureButton:
	var button: TextureButton = await _mounted()
	button._on_volume_button_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	return button


func test_the_dialog_starts_closed() -> void:
	var button: TextureButton = await _mounted()

	assert_false((button.get_node("%Dialog") as CanvasLayer).visible,
		"a CanvasLayer defaults to visible, so this has to be turned off")


func test_pressing_the_button_opens_it() -> void:
	var button: TextureButton = await _opened()

	assert_true((button.get_node("%Dialog") as CanvasLayer).visible)


func test_it_is_a_modal_dialog_rather_than_a_panel_beside_the_button() -> void:
	# Regression: the panel was positioned at the button's own x plus 300, with no
	# backdrop and the old theme, so it opened half off the screen as a dark strip.
	var button: TextureButton = await _opened()

	var backdrop: ColorRect = button.get_node("%Dialog/Backdrop")
	assert_eq(backdrop.size, Vector2(REFERENCE_VIEWPORT),
		"the backdrop should cover the screen")
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_STOP,
		"and swallow clicks meant for what is behind it")

	var card: PanelContainer = button.get_node("%Dialog/Backdrop/Card")
	assert_eq(card.theme_type_variation, MenuTheme.VARIATION_CARD)
	assert_almost_eq(card.global_position.x + card.size.x / 2.0,
		REFERENCE_VIEWPORT.x / 2.0, 2.0, "the card should be centred, not offset from the button")
	assert_almost_eq(card.global_position.y + card.size.y / 2.0,
		REFERENCE_VIEWPORT.y / 2.0, 2.0)
	assert_eq(card.size, Vector2(Design.AUDIO_DIALOG_SIZE), "at the size the mockup draws it")


func test_it_has_a_row_per_bus_and_a_way_out() -> void:
	var button: TextureButton = await _opened()

	for name: String in ["%MasterVolumeSlider", "%MusicVolumeSlider", "%VoiceVolumeSlider",
			"%EffectsVolumeSlider", "%CancelButton", "%SaveButton", "%CloseButton"]:
		assert_not_null(button.get_node_or_null(name), "%s should be there" % name)


func test_the_sliders_work_in_the_range_the_manager_expects() -> void:
	# UserDataManager converts 0..100 to decibels itself; handing it decibels
	# would put the volume somewhere else entirely.
	var button: TextureButton = await _opened()

	for slider: HSlider in button.sliders():
		assert_eq(slider.min_value, 0.0)
		assert_eq(slider.max_value, 100.0)


func test_the_sliders_open_on_the_saved_levels() -> void:
	UserDataManager.set_master_volume(42.0)
	var button: TextureButton = await _opened()

	assert_almost_eq((button.get_node("%MasterVolumeSlider") as HSlider).value, 42.0, 1.0,
		"the dialog should show where the volume actually is")


func test_reading_the_levels_in_does_not_write_them_back_out() -> void:
	# Assigning a slider's value emits value_changed, which would write the level
	# straight back -- and on cancel would save the value being undone.
	UserDataManager.set_master_volume(30.0)
	var button: TextureButton = await _opened()
	(button.get_node("%MasterVolumeSlider") as HSlider).value = 80.0
	UserDataManager.set_master_volume(30.0)

	button.read_levels()

	assert_almost_eq(UserDataManager.get_master_volume(), 30.0, 1.0,
		"reading the sliders should leave the saved level alone")


func test_a_slider_applies_as_it_moves() -> void:
	# A volume you cannot hear while setting it is not worth setting.
	var button: TextureButton = await _opened()

	(button.get_node("%MasterVolumeSlider") as HSlider).value = 55.0

	assert_almost_eq(UserDataManager.get_master_volume(), 55.0, 1.0)


func test_saving_keeps_the_new_level_and_closes() -> void:
	UserDataManager.set_master_volume(20.0)
	var button: TextureButton = await _opened()
	(button.get_node("%MasterVolumeSlider") as HSlider).value = 90.0

	button._on_save_pressed()

	assert_almost_eq(UserDataManager.get_master_volume(), 90.0, 1.0)
	assert_false((button.get_node("%Dialog") as CanvasLayer).visible)


func test_cancelling_puts_back_the_level_it_opened_on() -> void:
	# What makes trying a level out safe.
	UserDataManager.set_master_volume(20.0)
	var button: TextureButton = await _opened()
	(button.get_node("%MasterVolumeSlider") as HSlider).value = 90.0
	assert_almost_eq(UserDataManager.get_master_volume(), 90.0, 1.0, "moved while dragging")

	button._on_cancel_pressed()

	assert_almost_eq(UserDataManager.get_master_volume(), 20.0, 1.0,
		"cancel should undo the drag")
	assert_almost_eq((button.get_node("%MasterVolumeSlider") as HSlider).value, 20.0, 1.0,
		"and put the slider back where it was")
	assert_false((button.get_node("%Dialog") as CanvasLayer).visible)


func test_the_close_cross_cancels_too() -> void:
	UserDataManager.set_music_volume(25.0)
	var button: TextureButton = await _opened()
	(button.get_node("%MusicVolumeSlider") as HSlider).value = 75.0

	# The cross is wired to the same handler as Cancel.
	button._on_cancel_pressed()

	assert_almost_eq(UserDataManager.get_music_volume(), 25.0, 1.0)


func test_the_sliders_look_like_the_mockup() -> void:
	var button: TextureButton = await _opened()
	var slider: HSlider = button.get_node("%MasterVolumeSlider")

	assert_eq(slider.theme_type_variation, MenuTheme.VARIATION_VOLUME_SLIDER)
	assert_eq((slider.get_theme_stylebox("slider") as StyleBoxFlat).bg_color, Design.GREY,
		"the unplayed part of the track is grey")
	assert_eq((slider.get_theme_stylebox("grabber_area") as StyleBoxFlat).bg_color, Design.PURPLE,
		"and the played part purple")
	assert_eq(slider.get_theme_icon("grabber").get_size(),
		Vector2(Design.SLIDER_GRABBER_SIZE, Design.SLIDER_GRABBER_SIZE),
		"the grabber is an icon, so its size is the artwork's")

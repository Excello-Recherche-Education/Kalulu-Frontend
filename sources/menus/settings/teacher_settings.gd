extends Control

const main_menu_path := "res://sources/menus/main/main_menu.tscn"
const login_menu_path := "res://sources/menus/login/login.tscn"

const device_tab_scene : PackedScene = preload("res://sources/menus/settings/device_tab.tscn")

# Volume menu
@onready var volume_menu: Control = %VolumeMenu
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var voice_volume_slider: HSlider = %VoiceVolumeSlider
@onready var effects_volume_slider: HSlider = %EffectsVolumeSlider

@onready var devices_tab_container : TabContainer = %DevicesTabContainer
@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks


func _ready():
	await _refresh_devices_tabs()
	
	set_master_volume_slider(UserDataManager.get_master_volume())
	set_music_volume_slider(UserDataManager.get_music_volume())
	set_voice_volume_slider(UserDataManager.get_voice_volume())
	set_effects_volume_slider(UserDataManager.get_effects_volume())
	
	OpeningCurtain.open()


func _refresh_devices_tabs() -> void:
	for child in devices_tab_container.get_children(false):
		child.queue_free()
	
	if not UserDataManager.teacher_settings:
		push_error("Teacher settings not found")
		return
	
	for device in UserDataManager.teacher_settings.students.keys():
		var device_tab := device_tab_scene.instantiate()
		device_tab.name = tr("DEVICE_NUMBER").format({"number" : device})
		device_tab.device_id = device
		device_tab.students = UserDataManager.teacher_settings.students[device]
		devices_tab_container.add_child(device_tab)
		
		device_tab.student_pressed.connect(_on_student_pressed)


func _on_back_button_pressed():
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(login_menu_path)


func _on_logout_button_pressed():
	await OpeningCurtain.close()
	UserDataManager.logout()
	get_tree().change_scene_to_file(main_menu_path)


func _on_devices_tab_container_tab_changed(tab: int) -> void:
	lesson_unlocks.device = tab + 1


func _on_student_pressed(code: String):
	lesson_unlocks.student = code
	lesson_unlocks.show()


func _on_add_student_button_pressed():
	var current_tab = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		return
	
	# If parent -> show a creation popup
	# If teacher -> create a default student
	
	if UserDataManager.add_default_student(current_tab.device_id):
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()


func _on_add_device_button_pressed():
	if UserDataManager.add_device():
		_refresh_devices_tabs()

# ------------ Volume Menu ------------

func _on_volume_button_pressed() -> void:
	volume_menu.visible = not volume_menu.visible


func set_master_volume_slider(volume: float) -> void:
	master_volume_slider.value = volume


func set_music_volume_slider(volume: float) -> void:
	music_volume_slider.value = volume


func set_voice_volume_slider(volume: float) -> void:
	voice_volume_slider.value = volume


func set_effects_volume_slider(volume: float) -> void:
	effects_volume_slider.value = volume

func _on_master_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_master_volume(volume)


func _on_music_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_music_volume(volume)


func _on_voice_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_voice_volume(volume)


func _on_effects_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_effects_volume(volume)

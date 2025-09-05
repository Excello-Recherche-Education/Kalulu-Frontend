extends TextureButton

@onready var volume_menu: Control = %VolumeMenu
@onready var volume_panel: Panel = %VolumePanel
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var voice_volume_slider: HSlider = %VoiceVolumeSlider
@onready var effects_volume_slider: HSlider = %EffectsVolumeSlider


func _ready() -> void:
	set_master_volume_slider(UserDataManager.get_master_volume())
	set_music_volume_slider(UserDataManager.get_music_volume())
	set_voice_volume_slider(UserDataManager.get_voice_volume())
	set_effects_volume_slider(UserDataManager.get_effects_volume())


func set_master_volume_slider(volume: float) -> void:
	master_volume_slider.value = volume


func set_music_volume_slider(volume: float) -> void:
	music_volume_slider.value = volume


func set_voice_volume_slider(volume: float) -> void:
	voice_volume_slider.value = volume


func set_effects_volume_slider(volume: float) -> void:
	effects_volume_slider.value = volume

#region Connections

func _on_volume_menu_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		volume_menu.visible = not volume_menu.visible


func _on_volume_button_pressed() -> void:
	volume_panel.global_position = Vector2(self.global_position.x + 300, self.global_position.y)
	volume_menu.visible = not volume_menu.visible


func _on_master_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_master_volume(volume)


func _on_music_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_music_volume(volume)


func _on_voice_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_voice_volume(volume)


func _on_effects_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_effects_volume(volume)

#endregion

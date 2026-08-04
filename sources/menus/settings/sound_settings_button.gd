extends TextureButton
## The volume button in Settings, and the dialog it opens.
##
## The sliders apply as they are dragged, because a volume you cannot hear is not
## worth setting. Save simply closes -- the levels are already in place -- while
## Cancel and the close cross put back the ones the dialog opened on, which is
## what makes trying a level out safe.

## The levels the dialog opened on, to put back if it is cancelled.
var levels_on_open: Dictionary[String, float] = {}

@onready var dialog: CanvasLayer = %Dialog
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var voice_volume_slider: HSlider = %VoiceVolumeSlider
@onready var effects_volume_slider: HSlider = %EffectsVolumeSlider


func _ready() -> void:
	read_levels()


## Puts the saved levels on the sliders without that counting as a change.
##
## Signals are blocked while it happens: assigning a slider's value emits
## value_changed, which would write the level straight back out again -- and on
## cancel would record the value being undone as the one to keep.
func read_levels() -> void:
	for slider: HSlider in sliders():
		slider.set_block_signals(true)
	master_volume_slider.value = UserDataManager.get_master_volume()
	music_volume_slider.value = UserDataManager.get_music_volume()
	voice_volume_slider.value = UserDataManager.get_voice_volume()
	effects_volume_slider.value = UserDataManager.get_effects_volume()
	for slider: HSlider in sliders():
		slider.set_block_signals(false)


func sliders() -> Array[HSlider]:
	return [master_volume_slider, music_volume_slider, voice_volume_slider,
		effects_volume_slider]


func set_master_volume_slider(volume: float) -> void:
	master_volume_slider.value = volume


func set_music_volume_slider(volume: float) -> void:
	music_volume_slider.value = volume


func set_voice_volume_slider(volume: float) -> void:
	voice_volume_slider.value = volume


func set_effects_volume_slider(volume: float) -> void:
	effects_volume_slider.value = volume

#region Connections

func _on_volume_button_pressed() -> void:
	read_levels()
	levels_on_open = {
		"master": UserDataManager.get_master_volume(),
		"music": UserDataManager.get_music_volume(),
		"voice": UserDataManager.get_voice_volume(),
		"effects": UserDataManager.get_effects_volume(),
	}
	Log.trace("SoundSettings: Opened on %s" % str(levels_on_open))
	dialog.show()


func _on_save_pressed() -> void:
	# The levels went in as the sliders moved, so there is nothing left to write.
	Log.info("SoundSettings: Keeping the new levels")
	dialog.hide()


func _on_cancel_pressed() -> void:
	Log.info("SoundSettings: Putting back the levels the dialog opened on")
	UserDataManager.set_master_volume(levels_on_open.get("master", 0.0))
	UserDataManager.set_music_volume(levels_on_open.get("music", 0.0))
	UserDataManager.set_voice_volume(levels_on_open.get("voice", 0.0))
	UserDataManager.set_effects_volume(levels_on_open.get("effects", 0.0))
	read_levels()
	dialog.hide()


func _on_master_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_master_volume(volume)


func _on_music_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_music_volume(volume)


func _on_voice_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_voice_volume(volume)


func _on_effects_volume_slider_value_changed(volume: float) -> void:
	UserDataManager.set_effects_volume(volume)

#endregion

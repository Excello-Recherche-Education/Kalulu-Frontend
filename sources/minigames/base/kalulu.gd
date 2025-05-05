extends Control

signal speech_ended

const show_sound: AudioStreamMP3 = preload("res://assets/kalulu/audio/ui_button_on.mp3")
const hide_sound: AudioStreamMP3 = preload("res://assets/kalulu/audio/ui_button_off.mp3")


@onready var kalulu_sprite: AnimatedSprite2D = $KaluluSprite
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	hide()


func play_kalulu_speech(speech: AudioStream, show_animation: bool = true, hide_animation: bool = true) -> void:
	var ind: int = AudioServer.get_bus_index("Music")
	var musicVolume: float = AudioServer.get_bus_volume_db(ind)
	AudioServer.set_bus_volume_db(ind, -80.0)
	if show_animation:
		show()
		
		audio_player.stream = show_sound
		audio_player.play()
		
		kalulu_sprite.play("Show")
		await kalulu_sprite.animation_finished
	
	if speech:
		kalulu_sprite.play("Talk1")
		audio_player.stream = speech
		audio_player.play()
		await audio_player.finished
	else:
		Logger.warn("Kalulu: Speech not found")
	
	if hide_animation:
		audio_player.stream = hide_sound
		audio_player.play()
		
		kalulu_sprite.play("Hide")
		await kalulu_sprite.animation_finished
		hide()
	
	AudioServer.set_bus_volume_db(ind, musicVolume)
	speech_ended.emit()

func _on_pass_button_pressed() -> void:
	if audio_player.playing:
		audio_player.stop()
		audio_player.finished.emit()

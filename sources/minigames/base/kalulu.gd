extends Control

signal speech_ended

@onready var kalulu_sprite: = $KaluluSprite
@onready var audio_player: = $AudioStreamPlayer


func _ready() -> void:
	hide()


func play_kalulu_speech(speech: AudioStream) -> void:
	show()
	kalulu_sprite.play("Show")
	await kalulu_sprite.animation_finished
	
	kalulu_sprite.play("Talk1")
	audio_player.stream = speech
	audio_player.play()
	
	await audio_player.finished
	
	kalulu_sprite.play("Hide")
	await kalulu_sprite.animation_finished
	hide()
	
	speech_ended.emit()

func _on_pass_button_pressed() -> void:
	if OS.has_feature("debug") and audio_player.playing:
		audio_player.stop()
		audio_player.finished.emit()

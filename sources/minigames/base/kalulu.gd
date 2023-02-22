extends Control

signal kalulu_speech_end

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
	
	emit_signal("kalulu_speech_end")


func _on_kalulu_sprite_animation_finished() -> void:
	if kalulu_sprite.animation in ["Idle1", "Idle2"]:
		var r: = randf()
		if r < 0.5:
			kalulu_sprite.play("Idle1")
		else:
			kalulu_sprite.play("Idle2")
	
	if kalulu_sprite.animation in ["Talk1", "Talk2", "Talk3"]:
		var r: = randf()
		if r < 1.0 / 3.0:
			kalulu_sprite.play("Talk1")
		elif r < 2.0 / 3.0:
			kalulu_sprite.play("Talk2")
		else:
			kalulu_sprite.play("Talk3")


func _on_pass_button_pressed() -> void:
	if audio_player.playing:
		audio_player.stop()
		audio_player.finished.emit()

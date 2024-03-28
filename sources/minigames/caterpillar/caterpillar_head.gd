@tool
extends Node2D
class_name CaterpillarHead

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_stream_player: CaterpillarAudioStreamPlayer = $CaterpillarAudioStreamPlayer

func _ready():
	idle()


func idle():
	if randf() < 0.8:
		animated_sprite.play("idle1")
	else:
		animated_sprite.play("idle2")


func eat():
	animated_sprite.play("eat")
	audio_stream_player.eat()
	await animated_sprite.animation_finished


func spit():
	animated_sprite.play("spit")
	await animated_sprite.animation_finished


func _on_animation_finished():
	idle()

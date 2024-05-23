@tool
extends Node2D

#Namespace
const CaterpillarAudioStreamPlayer: = preload("res://sources/minigames/caterpillar/CaterpillarAudioStreamPlayer.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_stream_player: CaterpillarAudioStreamPlayer = $CaterpillarAudioStreamPlayer
@onready var spit_vfx: SpitVFX = $SpitFX

func _ready() -> void:
	idle()


func idle() -> void:
	if randf() < 0.8:
		animated_sprite.play("idle1")
	else:
		animated_sprite.play("idle2")


func eat() -> void:
	animated_sprite.play("eat")
	audio_stream_player.eat()
	await animated_sprite.animation_finished


func spit() -> void:
	animated_sprite.play("spit")
	spit_vfx.play()
	await animated_sprite.animation_finished


func _on_animation_finished() -> void:
	idle()

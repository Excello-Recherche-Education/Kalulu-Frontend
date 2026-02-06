class_name KaluluBoss
extends AnimatedSprite2D

var animation_counter: int = 0
var animation_delay: int = 3
var animation_random: int = 3


func happy() -> void:
	play("happy")
	await animation_finished
	play("happy")
	await animation_finished


func sad() -> void:
	play("sad")
	await animation_finished
	await get_tree().create_timer(1).timeout
	play_backwards("sad")
	await animation_finished
	play("idle_1")


func _on_animation_finished() -> void:
	match animation:
		"idle_1":
			animation_counter -= 1
			if animation_counter <= 0:
				animation_counter = animation_delay + randi_range(0, animation_random)
				play("idle_2") 
			else: 
				play("idle_1")
		"idle_2":
			play("idle_1")

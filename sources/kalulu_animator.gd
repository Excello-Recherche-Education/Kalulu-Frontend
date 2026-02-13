extends AnimatedSprite2D

const TALK_SPECIALS: Array[StringName] = [&"Talk_blink", &"Talk_ear_bend", &"Talk_ear_wiggle"]

var blink_counter: int = 0
var blink_delay: int = 3
var blink_random: int = 3
var talk_counter: int = 0
var talk_delay: int = 3
var talk_random: int = 3


func _on_animation_finished() -> void:
	if animation in [&"Hide", &"Show"]:
		return
	
	match animation:
		&"Idle":
			blink_counter -= 1
			if blink_counter <= 0:
				blink_counter = blink_delay + randi_range(0, blink_random)
				play(&"Idle_blink")
			else:
				play(&"Idle")
		&"Idle_blink":
			play(&"Idle")
		&"Talk":
			talk_counter -= 1
			if talk_counter <= 0:
				talk_counter = talk_delay + randi_range(0, talk_random)
				play(TALK_SPECIALS.pick_random() as StringName)
			else:
				play(&"Talk")
		&"Talk_blink", &"Talk_ear_bend", &"Talk_ear_wiggle":
			play(&"Talk")

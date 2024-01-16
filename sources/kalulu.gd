extends AnimatedSprite2D

func _on_animation_finished() -> void:
	
	if animation in ["Hide", "Show"]:
		return
	
	var r: = randf()
	
	match animation:
		"Idle1", "Idle2":
			if r < 0.5 :
				play("Idle1") 
			else : 
				play("Idle2")
		"Talk1", "Talk2", "Talk3":
			if r < 1.0 / 3.0:
				play("Talk1")
			elif r < 2.0 / 3.0:
				play("Talk2")
			else:
				play("Talk3")
		"Tc_Idle1", "Tc_Idle2":
			if r < 0.5 :
				play("Tc_Idle1") 
			else : 
				play("Tc_Idle2")
		"Tc_Talk1", "Tc_Talk2", "Tc_Talk3":
			if r < 1.0 / 3.0:
				play("Tc_Talk1")
			elif r < 2.0 / 3.0:
				play("Tc_Talk2")
			else:
				play("Tc_Talk3")

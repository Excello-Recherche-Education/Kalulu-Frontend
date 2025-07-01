extends Node2D
class_name Leaf

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

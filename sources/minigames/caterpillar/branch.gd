extends Node2D
class_name Branch

signal branch_pressed()

func _on_button_pressed():
	branch_pressed.emit()

extends Area2D
class_name Island

@onready var label : Label = $Label


func _on_area_entered(area):
	print(area)
	print(area.owner)

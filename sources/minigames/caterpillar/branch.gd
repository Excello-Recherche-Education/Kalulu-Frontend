extends Node2D
class_name Branch

signal branch_pressed()

const leaf_scene: PackedScene = preload("res://sources/minigames/caterpillar/leaf.tscn")

@onready var leaves: Node2D = $Leaves
@onready var leaf_timer: Timer = $LeafTimer

var velocity: float = 400


func _ready():
	leaf_timer.wait_time = randf_range(2.0, 5.0)
	leaf_timer.start()


func _process(delta):
	for leaf: Node2D in leaves.get_children(false):
		leaf.position.x -= velocity * delta


func _on_button_pressed():
	branch_pressed.emit()


func _on_leaf_timer_timeout():
	var leaf: Node2D = leaf_scene.instantiate()
	leaves.add_child(leaf)
	
	leaf_timer.wait_time = randf_range(2.0, 5.0)
	leaf_timer.start()

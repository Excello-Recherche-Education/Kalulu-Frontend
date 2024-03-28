extends Node2D
class_name Branch

signal branch_pressed()

const leaf_scene: PackedScene = preload("res://sources/minigames/caterpillar/leaf.tscn")
const berry_scene: PackedScene = preload("res://sources/minigames/caterpillar/berry.tscn")

@onready var leaves: Node2D = $Leaves
@onready var berries: Node2D = $Berries
@onready var leaf_timer: Timer = $LeafTimer

var velocity: float = 400


func _ready():
	leaf_timer.wait_time = randf_range(2.0, 5.0)
	leaf_timer.start()


func _process(delta):
	for leaf: Leaf in leaves.get_children():
		leaf.position.x -= velocity * delta
	for berry: Berry in berries.get_children():
		if not berry.is_eaten:
			berry.position.x -= velocity * delta
			if berry.is_old:
				berry.position.y += velocity * 4 * delta


func spawn_berry(gp: Dictionary):
	var berry : Berry = berry_scene.instantiate()
	berries.add_child(berry)
	berry.gp = gp


func clear_berries() -> void:
	for berry: Berry in berries.get_children():
		berry.is_old = true

# ---------- CONNECTIONS ---------- # 

func _on_button_pressed():
	branch_pressed.emit()


func _on_leaf_timer_timeout():
	var leaf: Node2D = leaf_scene.instantiate()
	leaves.add_child(leaf)
	
	leaf_timer.wait_time = randf_range(2.0, 5.0)
	leaf_timer.start()

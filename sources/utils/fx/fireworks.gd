extends Node

signal finished()

const Rocket: = preload("res://sources/utils/fx/rocket.gd")
const rocket_scene: PackedScene = preload("res://sources/utils/fx/rocket.tscn")

@export var number_of_rockets: int = 25

@onready var fire_delay_timer: Timer = $FireDelayTimer
@onready var starts: Array[Node] = $Starts.get_children()
@onready var ends: Array[Node] = $Ends.get_children()
@onready var rockets: Node2D = $Rockets


var count: int = 0


func start() -> void:
	count = 0
	_on_FireDelayTimer_timeout()


func _on_FireDelayTimer_timeout() -> void:
	if count >= number_of_rockets:
		finished.emit()
		return
	
	
	var start_node: Node2D = starts[randi() % starts.size()]
	var end_node: Node2D = ends[randi() % ends.size()]
	
	var rocket: Rocket = rocket_scene.instantiate()
	rockets.add_child(rocket)
	rocket.start(start_node.global_position, end_node.global_position + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0)))
	
	count += 1
	fire_delay_timer.start(randf_range(0.1, 0.25))

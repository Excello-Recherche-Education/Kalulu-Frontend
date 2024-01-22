extends Node

signal finished()

@export var number_of_rockets: = 25

@onready var fire_delay_timer: = $FireDelayTimer
@onready var starts: = $Starts.get_children()
@onready var ends: = $Ends.get_children()
@onready var rockets: = $Rockets

const firework_class: = preload("res://sources/utils/fx/rocket.tscn")

var count: = 0


func start() -> void:
	count = 0
	_on_FireDelayTimer_timeout()


func _on_FireDelayTimer_timeout() -> void:
	if count >= number_of_rockets:
		finished.emit()
		return
	
	var start_point: Vector2 = starts[randi() % starts.size()].global_position
	var end_point: Vector2 = ends[randi() % ends.size()].global_position
	
	var rocket: = firework_class.instantiate()
	rockets.add_child(rocket)
	rocket.start(start_point, end_point + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0)))
	
	count += 1
	fire_delay_timer.start(randf_range(0.1, 0.25))

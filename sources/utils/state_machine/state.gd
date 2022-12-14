extends Node
class_name State

@export var can_be_previous: = true

var state_machine: StateMachine


func _init() -> void:
	add_to_group("state")


func enter_state(_msg: Dictionary = {}) -> void:
	pass


func exit_state() -> void:
	pass


func state_process(_delta: float) -> void:
	pass


func state_physics_process(_delta: float) -> void:
	pass


func state_unhandled_input(_event: InputEvent) -> void:
	pass


func go_to_state(state_path: String, msg: Dictionary = {}) -> void:
	state_machine.go_to_state(state_path, msg)

extends Node
class_name StateMachine

signal state_changed(state_path, msg)

@export_node_path(Node) var initial_state_path: NodePath

var state: State = null
var current_msg: = {}
var previous_state: State = null
var previous_msg: = {}
var _is_active: = false
var is_active: = false:
	get: return _get_is_active()
	set(value): _set_is_active(value)


func _ready() -> void:
	self.is_active = false
	
	var children: = get_children()
	for node in children:
		children.append_array(node.get_children())
		if node is State:
			node.state_machine = self


func start() -> void:
	go_to_state(initial_state_path)
	self.is_active = true


func _process(delta: float) -> void:
	if state:
		state.state_process(delta)


func _physics_process(delta: float) -> void:
	if state:
		state.state_physics_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if state:
		state.state_unhandled_input(event)


func go_to_state(state_path: String, msg:= {}):
	var new_state: State = null
	if state_path == "Previous":
		if previous_state == null:
			push_error("No previous state at this point")
			return
		new_state = previous_state
		for key in previous_msg.keys():
			if not msg.has(key):
				msg[key] = previous_msg[key]
	else:
		if not has_node(state_path):
			push_error("State not found :" + state_path)
			return
		new_state = get_node(state_path)
	
	if state and state.can_be_previous:
		previous_msg = current_msg
		previous_state = state
	
	if state:
		state.exit_state()
	
	self.state = new_state
	state.enter_state(msg)
	current_msg = msg
	
	emit_signal("state_changed", state_path, msg)


func _set_is_active(value: bool) -> void:
	_is_active = value
	
	set_process(value)
	set_physics_process(value)
	set_process_unhandled_input(value)


func _get_is_active() -> bool:
	return _is_active

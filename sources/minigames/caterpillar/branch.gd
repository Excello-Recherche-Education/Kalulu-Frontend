@tool
class_name Branch
extends Node2D

signal branch_pressed()
signal berry_pressed(gp: Dictionary)

const LEAF_SCENE: PackedScene = preload("res://sources/minigames/caterpillar/leaf.tscn")
const BERRY_SCENE: PackedScene = preload("res://sources/minigames/caterpillar/berry.tscn")

var velocity: float = 0.0
var is_highlighting: bool = false:
	set = _set_highlighting
var is_running: bool = true

@onready var leaves: Node2D = $Leaves
@onready var berries: Node2D = $Berries
@onready var leaf_timer: Timer = $LeafTimer


func _set_highlighting(value: bool) -> void:
	is_highlighting = value
	for berry: Berry in berries.get_children():
		if is_highlighting:
			berry.highlight()


func _ready() -> void:
	# Adds some leaves from start
	var pos: float = -leaves.position.x + velocity * randf_range(0,2)
	while pos < 0:
		var leaf: Leaf = LEAF_SCENE.instantiate()
		leaves.add_child(leaf)
		leaf.position.x = pos
		pos = pos + velocity * randf_range(2, 5)
	
	if not Engine.is_editor_hint():
		leaf_timer.wait_time = randf_range(2.0, 5.0)
		leaf_timer.start()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_running:
		return
	
	for leaf: Leaf in leaves.get_children():
		leaf.position.x -= velocity * delta
	for berry: Berry in berries.get_children():
		if not berry.is_eaten:
			berry.position.x -= velocity * delta


func spawn_berry(gp: Dictionary, is_distractor: bool) -> void:
	var berry: Berry = BERRY_SCENE.instantiate()
	berries.add_child(berry)
	berry.gp = gp
	berry.is_distractor = is_distractor
	if is_highlighting:
		berry.highlight()
	
	berry.pressed.connect(_on_berry_pressed)


func clear_berries() -> void:
	for berry: Berry in berries.get_children():
		berry.fall()

# ---------- CONNECTIONS ---------- # 

func _on_button_pressed() -> void:
	branch_pressed.emit()


func _on_leaf_timer_timeout() -> void:
	var leaf: Leaf = LEAF_SCENE.instantiate()
	leaves.add_child(leaf)
	
	leaf_timer.wait_time = randf_range(2.0, 5.0)
	leaf_timer.start()


func _on_berry_pressed(gp: Dictionary) -> void:
	berry_pressed.emit(gp)

@tool
extends Node2D

# Namespace
const CaterpillarHead: = preload("res://sources/minigames/caterpillar/caterpillar_head.gd")
const CaterpillarBody: = preload("res://sources/minigames/caterpillar/caterpillar_body.gd")
const Berry: = preload("res://sources/minigames/caterpillar/berry.gd")

signal berry_eaten(berry: Berry)

const body_part_scene: PackedScene = preload("res://sources/minigames/caterpillar/caterpillar_body.tscn")

const body_part_width: int = 128
const body_part_move_time: float = 0.25
const body_part_wait_time: float = 0.04

@onready var head: CaterpillarHead = $Head
@onready var body_parts: Node2D = $BodyParts
@onready var tail: Node2D = $Tail

var is_moving: bool = false
var is_eating: bool = false


func move(y : float) -> void:
	if is_moving or is_eating:
		return
	
	is_moving = true
	var coroutine: = Coroutine.new()
	
	# Move head
	coroutine.add_future(_tween_body_part(head, y).finished)
	
	# Move body
	for i: int in body_parts.get_child_count(false):
		await get_tree().create_timer(body_part_wait_time).timeout
		var body_part: CaterpillarBody = body_parts.get_child(-i-1)
		coroutine.add_future(_tween_body_part(body_part, y).finished)
	
	# Move tail
	await get_tree().create_timer(body_part_wait_time).timeout
	coroutine.add_future(_tween_body_part(tail, y).finished)
	
	await coroutine.join_all()
	is_moving = false


func _tween_body_part(part: Node2D, y: float) -> Tween:
	var tween: = create_tween()
	tween.tween_property(part, "global_position:y", y, body_part_move_time)
	return tween


func eat_berry(berry: Berry) -> void:
	is_eating = true
	
	var body_part: CaterpillarBody
	var tween: = create_tween()
	
	# Check if there is only one empty body part
	if body_parts.get_child_count() == 1:
		var current_body_part: = body_parts.get_child(0) as CaterpillarBody
		if not current_body_part.gp:
			body_part = current_body_part
	
	if not body_part:
		var pos: Vector2 = Vector2(head.position.x + body_part_width, head.position.y)
	
		body_part = body_part_scene.instantiate()
		body_parts.add_child(body_part)
		body_part.position = pos
		#body_part.modulate.a = 0
		body_part.scale.x = 0
		
		tween.tween_property(head, "position", pos, .2)
		tween.parallel().tween_property(berry, "global_position:x",head.global_position.x + body_part_width * 2, .2)
		tween.parallel().tween_property(berry, "modulate:a", 0, .2)
		#tween.parallel().tween_property(body_part, "modulate:a", 1, .5)
		tween.parallel().tween_property(body_part, "scale:x", 1, .2)
	else:
		tween.tween_property(berry, "global_position:x", head.global_position.x + body_part_width * 2, 0.2)
		tween.parallel().tween_property(berry, "modulate:a", 0, 1)
	
	head.eat()
	body_part.gp = berry.gp
	
	await tween.finished
	
	body_part.right()
	
	is_eating = false


func spit_berry(berry: Berry) -> void:
	is_eating = true
	
	var pos_x : float = berry.global_position.x
	
	var tween: = create_tween()
	tween.tween_property(berry, "global_position:x", head.global_position.x + body_part_width * 3, 0.1)
	await head.eat()
	
	tween = create_tween()
	tween.tween_property(berry, "global_position:x", pos_x, 0.1)
	berry.wrong()
	await head.spit()
	tween = create_tween()
	tween.tween_property(berry, "modulate:a", 0, 1)
	
	is_eating = false


func reset() -> void:
	# Move the head and the body parts back
	var tween: = create_tween()
	tween.tween_property(head, "position:x", 0, 0.2)
	
	for i: int in range(1, body_parts.get_child_count()):
		tween.parallel().tween_property(body_parts.get_child(i), "position:x", 0, 0.2)
	
	# Clear text on the first body part
	var body_part: CaterpillarBody = body_parts.get_child(0)
	body_part.gp = {}
	
	await tween.finished
	
	# Remove the old parts
	for i: int in range(1, body_parts.get_child_count()):
		body_parts.get_child(i).queue_free()


func _on_eat_area_2d_area_entered(area: Area2D) -> void:
	if area is Berry and !is_moving:
		var berry: = area as Berry
		berry.is_eaten = true
		berry_eaten.emit(berry)

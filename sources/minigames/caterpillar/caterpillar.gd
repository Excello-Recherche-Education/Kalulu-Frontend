@tool
extends Node2D
class_name Caterpillar

@onready var head: CaterpillarHead = $Head
@onready var body_parts: Node2D = $BodyParts
@onready var tail: Node2D = $Tail

var is_moving: bool = false


func move(y : float) -> void:
	if is_moving:
		return
	
	is_moving = true
	var move_y: float = head.global_position.y - y
	var coroutine: = Coroutine.new()
	
	# Move head
	coroutine.add_future(_tween_body_part(head, move_y).finished)
	
	# Move body
	for body_part: CaterpillarBody in body_parts.get_children(false):
		await get_tree().create_timer(0.1).timeout
		coroutine.add_future(_tween_body_part(body_part, move_y).finished)
	
	# Move tail
	await get_tree().create_timer(0.1).timeout
	coroutine.add_future(_tween_body_part(tail, move_y).finished)
	
	await coroutine.join_all()
	is_moving = false


func _tween_body_part(part: Node2D, move_y: float) -> Tween:
	var tween: = create_tween()
	tween.tween_property(part, "global_position", Vector2(part.global_position.x, part.global_position.y - move_y), 0.5)
	return tween

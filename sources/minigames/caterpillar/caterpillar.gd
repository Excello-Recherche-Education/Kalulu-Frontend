@tool
extends Node2D
class_name Caterpillar

signal berry_eaten(berry: Berry)

const body_part_scene: PackedScene = preload("res://sources/minigames/caterpillar/caterpillar_body.tscn")

const body_part_width: int = 64

@onready var head: CaterpillarHead = $Head
@onready var body_parts: Node2D = $BodyParts
@onready var tail: Node2D = $Tail

var is_moving: bool = false
var is_eating: bool = false


func move(y : float) -> void:
	if is_moving or is_eating:
		return
	
	is_moving = true
	var move_y: float = head.global_position.y - y
	var coroutine: = Coroutine.new()
	
	# Move head
	coroutine.add_future(_tween_body_part(head, move_y).finished)
	
	# Move body
	for i: int in body_parts.get_child_count(false):
		await get_tree().create_timer(0.01).timeout
		var body_part: CaterpillarBody = body_parts.get_child(-i-1)
		coroutine.add_future(_tween_body_part(body_part, move_y).finished)
	
	# Move tail
	await get_tree().create_timer(0.01).timeout
	coroutine.add_future(_tween_body_part(tail, move_y).finished)
	
	await coroutine.join_all()
	is_moving = false


func _tween_body_part(part: Node2D, move_y: float) -> Tween:
	var tween: = create_tween()
	tween.tween_property(part, "global_position:y", part.global_position.y - move_y, 0.2)
	return tween


func eat_berry(berry: Berry) -> void:
	is_eating = true
	
	var body_part: CaterpillarBody
	var tween: = create_tween()
	
	# Check if there is only one empty body part
	if body_parts.get_child_count() == 1:
		var current_body_part = body_parts.get_child(0) as CaterpillarBody
		if not current_body_part.gp:
			body_part = current_body_part
	
	if not body_part:
		var pos: Vector2 = Vector2(head.position.x + body_part_width, head.position.y)
	
		body_part = body_part_scene.instantiate()
		body_parts.add_child(body_part)
		body_part.position = pos
		body_part.modulate.a = 0
		
		tween.tween_property(head, "position", pos, 0.2)
		tween.parallel().tween_property(berry, "global_position", Vector2(head.global_position.x + body_part_width * 2, head.global_position.y), 0.2)
		tween.parallel().tween_property(berry, "modulate:a", 0, 1)
		tween.parallel().tween_property(body_part, "modulate:a", 1, 1)
	else:
		tween.tween_property(berry, "global_position", Vector2(head.global_position.x + body_part_width * 2, head.global_position.y), 0.2)
		tween.parallel().tween_property(berry, "modulate:a", 0, 1)
	
	
	head.eat()
	body_part.gp = berry.gp
	
	await tween.finished
	
	body_part.right()
	
	is_eating = false


func spit_berry(berry: Berry) -> void:
	head.spit()
	await berry.wrong()
	berry.queue_free()


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
		area.is_eaten = true
		berry_eaten.emit(area)

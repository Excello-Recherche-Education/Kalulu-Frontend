class_name Caterpillar
extends Node2D

signal berry_eaten(berry: Berry)

const BODY_PART_SCENE: PackedScene = preload("res://sources/minigames/caterpillar/caterpillar_body.tscn")
const BODY_SIDE_SCENE: PackedScene = preload("res://sources/minigames/caterpillar/caterpillar_body_side.tscn")
const BODY_PART_MOVE_TIME: float = 0.25
const BODY_PART_WAIT_TIME: float = 0.02
const SIDE_WIDTH: int = 11 # Side is 11 pixels wide
const BODY_PART_POSITION_X_MARGIN: int = 20 # Equals to the width of the graphics "left" + "right" of the body part, which are 10 pixels each

var is_switching_branch: bool = false
var is_eating: bool = false

@onready var head: CaterpillarHead = $Head
@onready var body_parts: Node2D = $BodyParts
@onready var tail: Node2D = $Tail
@onready var animated_tail: AnimatedSprite2D = $Tail/AnimatedSprite2D


func idle() -> void:
	for body_part: Node in body_parts.get_children():
		if body_part is CaterpillarBody:
			(body_part as CaterpillarBody).idle()
	head.pause_animation()
	animated_tail.pause()


func walk() -> void:
	for body_part: Node in body_parts.get_children():
		if body_part is CaterpillarBody:
			(body_part as CaterpillarBody).walk()
	head.resume_animation()
	animated_tail.play()


func move(distance: float) -> void:
	if is_switching_branch or is_eating or head.is_paused:
		return
	
	idle()
	is_switching_branch = true
	var coroutine: Coroutine = Coroutine.new()
	
	# Move head
	coroutine.add_future(_tween_body_part(head, distance).finished)
	
	# Move body
	for index: int in range(body_parts.get_child_count(false)):
		await get_tree().create_timer(BODY_PART_WAIT_TIME).timeout
		var body_part: Node = body_parts.get_child(-index-1)
		if body_part is Node2D:
			coroutine.add_future(_tween_body_part(body_part as Node2D, distance).finished)
	
	# Move tail
	var scene_tree: SceneTree = get_tree()
	if scene_tree != null: # Is not in editor mode
		await get_tree().create_timer(BODY_PART_WAIT_TIME).timeout
	
	coroutine.add_future(_tween_body_part(tail, distance).finished)
	
	await coroutine.join_all()
	is_switching_branch = false
	walk()


func _tween_body_part(part: Node2D, y_position: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(part, "global_position:y", y_position, BODY_PART_MOVE_TIME)
	return tween


func eat_berry(berry: Berry) -> void:
	is_eating = true
	
	var body_part: CaterpillarBody
	var tween: Tween = create_tween()
	
	body_part = BODY_PART_SCENE.instantiate()
	body_parts.add_child(body_part)
	body_part.gp = berry.gp
	
	var new_body_pos: Vector2 = Vector2(head.position.x, head.position.y)
	var new_body_part_size: float = body_part.get_width()
	var new_head_pos: Vector2 = Vector2(head.position.x + new_body_part_size  + BODY_PART_POSITION_X_MARGIN, head.position.y)
	if body_parts.get_child_count() > 1:
		var body_side: Node2D = BODY_SIDE_SCENE.instantiate()
		body_parts.add_child(body_side)
		body_side.position = Vector2(head.position.x, head.position.y)
		new_body_pos = new_body_pos + Vector2(SIDE_WIDTH, 0)
		new_head_pos = new_head_pos + Vector2(SIDE_WIDTH, 0)
	body_part.position = new_body_pos
	
	tween.tween_property(head, "position", new_head_pos, .3)
	tween.parallel().tween_property(berry, "scale:x", 0.1, .25)
	tween.parallel().tween_property(berry, "scale:y", 0.1, .25)
	tween.parallel().tween_property(berry, "position:y", -100, .25)
	tween.parallel().tween_property(berry, "global_position:x", body_part.global_position.x, .6)
	
	head.eat()
	
	await tween.finished
	
	body_part.right()
	berry.queue_free()
	is_eating = false


func spit_berry(berry: Berry) -> void:
	is_eating = true
	
	var pos_x: float = berry.global_position.x
	
	# Eat the berry
	var tween: Tween = create_tween()
	tween.parallel().tween_property(berry, "scale:x", 0.1, .2)
	tween.parallel().tween_property(berry, "scale:y", 0.1, .2)
	tween.parallel().tween_property(berry, "position:y", -100, .25)
	tween.tween_property(berry, "global_position:x",head.global_position.x, .2)
	await head.eat()
	
	# Spit the berry
	head.spit()
	tween = create_tween()
	tween.tween_property(berry, "global_position:x", pos_x, 0.2)
	tween.parallel().tween_property(berry, "scale:x", 1, .2)
	tween.parallel().tween_property(berry, "scale:y", 1, .2)
	tween.parallel().tween_property(berry, "position:y", 0, .25)
	await tween.finished
	await berry.wrong()
	
	# Make the berry disappear
	tween = create_tween()
	tween.tween_property(berry, "modulate:a", 0, 1)
	await tween.finished
	
	is_eating = false


func reset() -> void:
	# Move the head and the body parts back
	var tween: Tween = create_tween()
	tween.tween_property(head, "position:x", 165, 0.5)
	
	for index: int in range(0, body_parts.get_child_count()):
		tween.parallel().tween_property(body_parts.get_child(index), "modulate:a", 0, 0.5)
	
	await tween.finished
	
	# Remove the old parts
	for index: int in range(0, body_parts.get_child_count()):
		body_parts.get_child(index).queue_free()


func _on_eat_area_2d_area_entered(area: Area2D) -> void:
	if area is Berry and !is_switching_branch:
		var berry: Berry = area as Berry
		berry.is_eaten = true
		berry_eaten.emit(berry)

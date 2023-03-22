extends Node2D

signal flooded

@export var jump_distance: = 240.0:
	set(value):
		jump_distance = value
		if jump_area_collision:
			jump_area_collision.position = Vector2(jump_distance / 2.0, 0.0)
			jump_area_collision.shape.height = jump_distance * 1.5

@onready var sprite: = $AnimatedSprite2D
@onready var jump_area: = $JumpArea
@onready var jump_area_collision: = $JumpArea/CollisionShape2D
@onready var frog_area: = $FrogArea

var follow_mouse: = false
var is_jumping: = false
var land_area: Area2D


func _ready():
	jump_distance = jump_distance


func _physics_process(_delta: float) -> void:
	if follow_mouse:
		var direction: = _get_mouse_direction()
		jump_area.rotation = direction.angle()
	
	if not is_jumping:
		if land_area != null:
			global_position = land_area.global_position


func _unhandled_input(event: InputEvent) -> void:
	if not is_jumping:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				follow_mouse = event.pressed
				
				if not event.pressed:
					var direction: = _get_mouse_direction()
					_jump(direction)


func _jump(direction: Vector2) -> void:
	_search_for_land_area()
	
	# Checking if there is somewhere to land
	var area: Area2D
	var dist: = jump_distance * 2.0
	for other_area in jump_area.get_overlapping_areas():
		if other_area != frog_area and other_area != land_area:
			var other_dist: float = (other_area.global_position - global_position).length()
			if area == null or other_dist < dist:
				area = other_area
				dist = other_dist
	
	land_area = null
	var destination: = global_position + jump_distance * direction
	if area != null:
		destination = area.global_position
	
	# actual jump
	is_jumping = true
	sprite.play("jump_side")
	var tween: = create_tween()
	tween.tween_property(self, "global_position", destination, 0.1)
	await tween.finished
	
	# Landing
	land_area = area
	sprite.play("idle_side")
	
	if area:
		if area.owner is Lilypad:
			var lilypad: = area.owner
			if not lilypad.frog_landed():
				flooded.emit()
	else:
		flooded.emit()
	
	is_jumping = false


func _search_for_land_area() -> void:
	var overlapping_areas: Array = frog_area.get_overlapping_areas()
	if overlapping_areas.size() != 0:
		land_area = overlapping_areas[0]
	else:
		land_area = null


func _reset() -> void:
	land_area = null


func _on_animated_sprite_2d_animation_finished() -> void:
	sprite.play("idle_side")


func _get_mouse_direction() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized()

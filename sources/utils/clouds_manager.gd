extends Node2D

@export var min_speed: float = 20.0
@export var max_speed: float = 60.0
@export var min_y: float = 20.0
@export var max_y: float = 200.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.3

var cloud_speeds: Dictionary[Sprite2D, float] = {}
var screen_width: float = 0.0


func _ready() -> void:
	randomize()
	screen_width = get_viewport_rect().size.x
	for cloud: Node in get_children():
		if cloud is Sprite2D:
			_init_cloud_start(cloud as Sprite2D)
		else:
			Log.error("CloudManager: A child cloud is not a Sprite2D, this should not be possible")


func _process(delta: float) -> void:
	var new_width: float = get_viewport_rect().size.x
	if new_width != screen_width:
		screen_width = new_width
		
	for cloud: Sprite2D in get_children():
		var speed: float = cloud_speeds[cloud]
		cloud.position.x -= speed * delta
		
		if cloud.position.x < -cloud.texture.get_width():
			_reset_cloud(cloud)


func _depth_factor_for_cloud(cloud: Sprite2D) -> float:
	# Normalise la hauteur sur 0 a 1
	var factor: float = (cloud.position.y - min_y) / float(max_y - min_y)
	return clampf(factor, 0.0, 1.0)


func _apply_parallax_speed(cloud: Sprite2D) -> float:
	var factor: float = _depth_factor_for_cloud(cloud)
	return lerp(min_speed, max_speed, factor)


func _apply_parallax_scale(cloud: Sprite2D) -> void:
	var factor: float = _depth_factor_for_cloud(cloud)
	var target_scale: float = lerpf(min_scale, max_scale, factor)
	cloud.scale = Vector2(target_scale, target_scale)


func _init_cloud_start(cloud: Sprite2D) -> void:
	cloud.position.x = randf_range(0, screen_width)
	cloud.position.y = randf_range(min_y, max_y)
	
	cloud_speeds[cloud] = _apply_parallax_speed(cloud)
	_apply_parallax_scale(cloud)


func _reset_cloud(cloud: Sprite2D) -> void:
	cloud.position.x = screen_width + cloud.texture.get_width() * 0.5
	cloud.position.y = randf_range(min_y, max_y)
	
	cloud_speeds[cloud] = _apply_parallax_speed(cloud)
	_apply_parallax_scale(cloud)

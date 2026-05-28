class_name CloudManager
extends Node2D

@export var min_speed: float = 20.0
@export var max_speed: float = 60.0
@export var min_y: float = 20.0
@export var max_y: float = 200.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.3
# 0 = background-locked, 1 = matches scroll, >1 = foreground.
@export var min_parallax_factor: float = 1.0
@export var max_parallax_factor: float = 1.0
# 0 falls back to viewport width (legacy minigame behavior).
@export var spawn_width: float = 0.0
@export var clouds_per_screen: int = 0

var scroll_offset: float = 0.0
# Without max_scroll, far clouds (parallax < 1) can land at drift_x values no
# scroll position ever exposes; configure_world() should set this.
var max_scroll: float = 0.0
var cloud_speeds: Dictionary[Sprite2D, float] = {}
var cloud_drift_x: Dictionary[Sprite2D, float] = {}
var cloud_parallax: Dictionary[Sprite2D, float] = {}
var screen_width: float = 0.0


func _ready() -> void:
	randomize()
	screen_width = get_viewport_rect().size.x
	_initialize_clouds()


func _process(delta: float) -> void:
	var new_width: float = get_viewport_rect().size.x
	if new_width != screen_width:
		screen_width = new_width

	var world_anchored: bool = spawn_width > 0.0

	for cloud: Node in get_children():
		if not (cloud is Sprite2D):
			continue
		var sprite: Sprite2D = cloud as Sprite2D
		var speed: float = cloud_speeds.get(sprite, 0.0)
		var parallax: float = cloud_parallax.get(sprite, 1.0)
		var drift_x: float = cloud_drift_x.get(sprite, sprite.position.x) - speed * delta
		cloud_drift_x[sprite] = drift_x
		var rendered_x: float = drift_x - scroll_offset * parallax
		sprite.position.x = rendered_x

		# World-anchored mode recycles in world space; legacy mode in viewport space.
		if world_anchored:
			if drift_x < -sprite.texture.get_width():
				_reset_cloud(sprite)
		else:
			if rendered_x < -sprite.texture.get_width():
				_reset_cloud(sprite)


func configure_world(world_width: float, p_max_scroll: float = -1.0, override_clouds_per_screen: int = -1) -> void:
	if override_clouds_per_screen >= 0:
		clouds_per_screen = override_clouds_per_screen
	set_world_bounds(world_width, p_max_scroll)
	screen_width = get_viewport_rect().size.x
	_initialize_clouds()


func set_world_bounds(world_width: float, p_max_scroll: float = -1.0) -> void:
	spawn_width = world_width
	max_scroll = p_max_scroll if p_max_scroll >= 0.0 else world_width


func _initialize_clouds() -> void:
	_populate_extra_clouds()
	cloud_speeds.clear()
	cloud_drift_x.clear()
	cloud_parallax.clear()

	var sprites: Array[Sprite2D] = []
	for cloud: Node in get_children():
		if cloud is Sprite2D:
			sprites.append(cloud as Sprite2D)
		else:
			Log.error("CloudsManager: A child cloud is not a Sprite2D, this should not be possible")

	# Avoid duplicated templates landing in adjacent stratified slots.
	sprites.shuffle()

	var slot_count: int = sprites.size()
	for index: int in range(slot_count):
		_init_cloud_start(sprites[index], index, slot_count)


func _populate_extra_clouds() -> void:
	if clouds_per_screen <= 0 or spawn_width <= 0.0:
		return
	var viewport_w: float = max(1.0, screen_width)
	var screens: int = maxi(1, ceili(spawn_width / viewport_w))
	var target_count: int = clouds_per_screen * screens

	var template_clouds: Array[Sprite2D] = []
	for child: Node in get_children():
		if child is Sprite2D:
			template_clouds.append(child as Sprite2D)
	if template_clouds.is_empty():
		return

	var to_add: int = target_count - template_clouds.size()
	for index: int in range(to_add):
		var template: Sprite2D = template_clouds[index % template_clouds.size()]
		var clone: Sprite2D = template.duplicate() as Sprite2D
		add_child(clone)


func _depth_factor_for_cloud(cloud: Sprite2D) -> float:
	var factor: float = (cloud.position.y - min_y) / float(max_y - min_y)
	return clampf(factor, 0.0, 1.0)


func _apply_parallax_speed(cloud: Sprite2D) -> float:
	var factor: float = _depth_factor_for_cloud(cloud)
	return lerpf(min_speed, max_speed, factor)


func _apply_parallax_scale(cloud: Sprite2D) -> void:
	var factor: float = _depth_factor_for_cloud(cloud)
	var target_scale: float = lerpf(min_scale, max_scale, factor)
	cloud.scale = Vector2(target_scale, target_scale)


func _apply_parallax_factor(cloud: Sprite2D) -> float:
	var factor: float = _depth_factor_for_cloud(cloud)
	return lerpf(min_parallax_factor, max_parallax_factor, factor)


func _spawn_range() -> float:
	return spawn_width if spawn_width > 0.0 else screen_width


func _init_cloud_start(cloud: Sprite2D, slot_index: int = 0, slot_count: int = 1) -> void:
	cloud.position.y = randf_range(min_y, max_y)
	cloud_parallax[cloud] = _apply_parallax_factor(cloud)
	cloud_speeds[cloud] = _apply_parallax_speed(cloud)
	_apply_parallax_scale(cloud)

	var parallax: float = cloud_parallax[cloud]
	var drift_x: float
	if max_scroll > 0.0 and slot_count > 1:
		# Stratify in scroll space and multiply by parallax so drift_x stays
		# within the cloud's reachable range.
		var scroll_slot_width: float = max_scroll / float(slot_count)
		var slot_min_scroll: float = float(slot_index) * scroll_slot_width
		var slot_max_scroll: float = float(slot_index + 1) * scroll_slot_width
		var target_scroll: float = randf_range(slot_min_scroll, slot_max_scroll)
		var horiz_jitter: float = randf_range(0.0, screen_width)
		drift_x = target_scroll * parallax + horiz_jitter
	elif spawn_width > 0.0 and slot_count > 1:
		var slot_width: float = spawn_width / float(slot_count)
		drift_x = randf_range(float(slot_index) * slot_width, float(slot_index + 1) * slot_width)
	else:
		drift_x = randf_range(0.0, _spawn_range())

	cloud_drift_x[cloud] = drift_x
	cloud.position.x = drift_x - scroll_offset * parallax


func _reset_cloud(cloud: Sprite2D) -> void:
	cloud.position.y = randf_range(min_y, max_y)
	cloud_parallax[cloud] = _apply_parallax_factor(cloud)
	cloud_speeds[cloud] = _apply_parallax_speed(cloud)
	_apply_parallax_scale(cloud)

	var parallax: float = cloud_parallax[cloud]
	if max_scroll > 0.0:
		# Respawn at the right edge of this cloud's reachable range, not the world's.
		var max_visibility_drift_x: float = max_scroll * parallax + screen_width + cloud.texture.get_width() * 0.5
		cloud_drift_x[cloud] = max_visibility_drift_x
		cloud.position.x = max_visibility_drift_x - scroll_offset * parallax
	elif spawn_width > 0.0:
		cloud_drift_x[cloud] = spawn_width + cloud.texture.get_width() * 0.5
		cloud.position.x = cloud_drift_x[cloud] - scroll_offset * parallax
	else:
		var target_rendered_x: float = screen_width + cloud.texture.get_width() * 0.5
		cloud_drift_x[cloud] = target_rendered_x + scroll_offset * parallax
		cloud.position.x = target_rendered_x

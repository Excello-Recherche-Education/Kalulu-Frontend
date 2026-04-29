extends Node2D

@export var min_speed: float = 20.0
@export var max_speed: float = 60.0
@export var min_y: float = 20.0
@export var max_y: float = 200.0
@export var min_scale: float = 0.6
@export var max_scale: float = 1.3

# Parallax factor applied to the externally provided scroll_offset.
# 0.0 = cloud is fully decoupled from the scroll (background-locked),
# 1.0 = cloud moves at the same speed as the scroll,
# > 1.0 = cloud moves faster than the scroll (foreground feel).
# The actual factor for each cloud is interpolated between min/max
# using the same depth_factor used for speed and scale (closer clouds get the max value).
@export var min_parallax_factor: float = 1.0
@export var max_parallax_factor: float = 1.0

# Total horizontal world width across which clouds are initially spread.
# When 0, defaults to the viewport width (legacy behavior used by minigames).
@export var spawn_width: float = 0.0

# When > 0 and spawn_width > 0, the manager duplicates its existing children
# to reach roughly clouds_per_screen * (spawn_width / viewport_width) clouds.
# 0 means no auto-population (only the children authored in the scene).
@export var clouds_per_screen: int = 0

# Externally driven scroll value (e.g. the Gardens horizontal scroll offset).
# Each cloud's rendered X is computed as drift_x - scroll_offset * cloud_parallax_factor.
var scroll_offset: float = 0.0

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

		# Recycling strategy depends on whether we're in world-anchored mode
		# (gardens-like: drift_x lives in world coordinates, recycle when it
		# falls past the world's left edge) or in legacy viewport-anchored mode
		# (minigames: a single fixed screen, recycle on viewport exit).
		if world_anchored:
			if drift_x < -sprite.texture.get_width():
				_reset_cloud(sprite)
		else:
			if rendered_x < -sprite.texture.get_width():
				_reset_cloud(sprite)


# Public API: configure the world width clouds spread across, and (re)populate
# extra clouds to keep density consistent. Safe to call multiple times.
func configure_world(world_width: float, override_clouds_per_screen: int = -1) -> void:
	if override_clouds_per_screen >= 0:
		clouds_per_screen = override_clouds_per_screen
	spawn_width = world_width
	if screen_width <= 0.0:
		screen_width = get_viewport_rect().size.x
	_initialize_clouds()


func _initialize_clouds() -> void:
	_populate_extra_clouds()
	cloud_speeds.clear()
	cloud_drift_x.clear()
	cloud_parallax.clear()
	for cloud: Node in get_children():
		if cloud is Sprite2D:
			_init_cloud_start(cloud as Sprite2D)
		else:
			Log.error("CloudsManager: A child cloud is not a Sprite2D, this should not be possible")


func _populate_extra_clouds() -> void:
	if clouds_per_screen <= 0 or spawn_width <= 0.0:
		return
	var viewport_w: float = max(1.0, screen_width)
	var screens: int = max(1, int(ceil(spawn_width / viewport_w)))
	var target_count: int = clouds_per_screen * screens

	var template_clouds: Array[Sprite2D] = []
	for child: Node in get_children():
		if child is Sprite2D:
			template_clouds.append(child as Sprite2D)
	if template_clouds.is_empty():
		return

	var to_add: int = target_count - template_clouds.size()
	for i: int in range(to_add):
		var template: Sprite2D = template_clouds[i % template_clouds.size()]
		var clone: Sprite2D = template.duplicate() as Sprite2D
		add_child(clone)


func _depth_factor_for_cloud(cloud: Sprite2D) -> float:
	# Normalise la hauteur sur 0 a 1
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


func _init_cloud_start(cloud: Sprite2D) -> void:
	cloud.position.y = randf_range(min_y, max_y)
	var drift_x: float = randf_range(0.0, _spawn_range())
	cloud_drift_x[cloud] = drift_x
	cloud_parallax[cloud] = _apply_parallax_factor(cloud)
	cloud_speeds[cloud] = _apply_parallax_speed(cloud)
	_apply_parallax_scale(cloud)
	cloud.position.x = drift_x - scroll_offset * cloud_parallax[cloud]


func _reset_cloud(cloud: Sprite2D) -> void:
	cloud.position.y = randf_range(min_y, max_y)
	cloud_parallax[cloud] = _apply_parallax_factor(cloud)
	cloud_speeds[cloud] = _apply_parallax_speed(cloud)
	_apply_parallax_scale(cloud)

	if spawn_width > 0.0:
		# World-anchored mode (gardens): the cloud drifted past the left edge
		# of the world, so wrap it back to the right edge of the world. Its
		# rendered position is whatever the current scroll dictates.
		cloud_drift_x[cloud] = spawn_width + cloud.texture.get_width() * 0.5
		cloud.position.x = cloud_drift_x[cloud] - scroll_offset * cloud_parallax[cloud]
	else:
		# Legacy viewport-anchored mode (minigames): place the cloud just past
		# the right edge of the viewport.
		var target_rendered_x: float = screen_width + cloud.texture.get_width() * 0.5
		cloud_drift_x[cloud] = target_rendered_x + scroll_offset * cloud_parallax[cloud]
		cloud.position.x = target_rendered_x

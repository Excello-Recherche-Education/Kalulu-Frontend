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

# Maximum scroll value the parent will pass through scroll_offset. Set via
# configure_world(); a non-zero value lets _init_cloud_start spread clouds
# evenly across the actual scroll range, which matters when parallax_factor
# is below 1.0 — without this, far clouds (smaller parallax) end up in
# drift_x positions the user can never bring into the viewport. When 0,
# the manager falls back to spawn_width-based stratification.
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


# Public API: configure the world the parent scrolls across.
#   world_width      — total horizontal extent of the scrollable content;
#                      drives the population of extra clouds.
#   p_max_scroll     — the largest scroll value the parent will pass via
#                      scroll_offset (typically world_width minus the
#                      visible viewport). When omitted (negative), defaults
#                      to world_width as a coarse fallback.
# Safe to call multiple times.
func configure_world(world_width: float, p_max_scroll: float = -1.0, override_clouds_per_screen: int = -1) -> void:
	if override_clouds_per_screen >= 0:
		clouds_per_screen = override_clouds_per_screen
	spawn_width = world_width
	max_scroll = p_max_scroll if p_max_scroll >= 0.0 else world_width
	# Always refresh screen_width here — by the time the parent calls this,
	# the viewport is sized correctly even if our _ready ran beforehand.
	screen_width = get_viewport_rect().size.x
	_initialize_clouds()


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

	# Shuffle so that identical cloud textures (the duplicated templates) don't
	# end up in adjacent stratified slots in tree order.
	sprites.shuffle()

	var slot_count: int = sprites.size()
	for i: int in range(slot_count):
		_init_cloud_start(sprites[i], i, slot_count)


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


func _init_cloud_start(cloud: Sprite2D, slot_index: int = 0, slot_count: int = 1) -> void:
	cloud.position.y = randf_range(min_y, max_y)
	# Compute parallax/speed/scale first so drift_x can take the cloud's
	# parallax into account.
	cloud_parallax[cloud] = _apply_parallax_factor(cloud)
	cloud_speeds[cloud] = _apply_parallax_speed(cloud)
	_apply_parallax_scale(cloud)

	var parallax: float = cloud_parallax[cloud]
	var drift_x: float
	if max_scroll > 0.0 and slot_count > 1:
		# Stratify in *scroll* space: each cloud is assigned a target scroll
		# value within its own slot of [0, max_scroll], then drift_x is
		# placed so the cloud is visible somewhere in the viewport when the
		# parent's scroll matches that target. Multiplying by parallax keeps
		# the cloud inside its actual reachable drift_x range — without
		# this, far clouds (parallax < 1) spread across the full world
		# would end up at drift_x values no scroll value can ever expose.
		var scroll_slot_width: float = max_scroll / float(slot_count)
		var slot_min_scroll: float = float(slot_index) * scroll_slot_width
		var slot_max_scroll: float = float(slot_index + 1) * scroll_slot_width
		var target_scroll: float = randf_range(slot_min_scroll, slot_max_scroll)
		var horiz_jitter: float = randf_range(0.0, screen_width)
		drift_x = target_scroll * parallax + horiz_jitter
	elif spawn_width > 0.0 and slot_count > 1:
		# Fallback (no max_scroll info): stratify in world space directly.
		# Far clouds (parallax < 1) may have dead zones in the upper half
		# of the world here, but configure_world callers should pass max_scroll.
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
		# Respawn at the right edge of *this cloud's* visibility range. With
		# parallax < 1 this is well below the world's right edge — the
		# cloud now drifts left through the scroll positions where it can
		# actually be seen, instead of sitting forever in unreachable
		# drift_x territory.
		var max_visibility_drift_x: float = max_scroll * parallax + screen_width + cloud.texture.get_width() * 0.5
		cloud_drift_x[cloud] = max_visibility_drift_x
		cloud.position.x = max_visibility_drift_x - scroll_offset * parallax
	elif spawn_width > 0.0:
		# Fallback world-anchored mode (no max_scroll info): wrap to the
		# right edge of the world.
		cloud_drift_x[cloud] = spawn_width + cloud.texture.get_width() * 0.5
		cloud.position.x = cloud_drift_x[cloud] - scroll_offset * parallax
	else:
		# Legacy viewport-anchored mode (minigames): place the cloud just
		# past the right edge of the viewport.
		var target_rendered_x: float = screen_width + cloud.texture.get_width() * 0.5
		cloud_drift_x[cloud] = target_rendered_x + scroll_offset * parallax
		cloud.position.x = target_rendered_x

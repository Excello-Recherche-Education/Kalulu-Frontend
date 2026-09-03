class_name Fireworks
extends Node
## The burst of fireworks over a finished minigame.
##
## Named by path rather than preloaded: firework.png is 3200x1600, about 20 MB, and
## this node sits in base_minigame, so every minigame carried it whether or not it
## was ever won. A device running light graphics skips the celebration entirely --
## the victory screen already says the game is won -- and play() finishes at once so
## the callers that await it carry on. See HeavyGraphics.

signal finished()

const FIREWORK_SCENE_PATH: String = "res://sources/utils/fx/firework.tscn"

@export var fireworks_count: int = 50
@export var screen_size: Vector2 = Vector2(2560, 1800)
@export var min_spawn_delay: float = 0.01
@export var max_spawn_delay: float = 0.09
@export var min_scale: float = 0.5
@export var max_scale: float = 1.0
@export var spawn_rect: Rect2 = Rect2()

## The single firework, fetched on the first celebration and kept after that.
var firework_scene: PackedScene = null
var _colors: Array[Color] = [
	Color.RED,
	Color.ORANGE,
	Color.YELLOW,
	Color.GREEN,
	Color.CYAN,
	Color.BLUE,
	Color.MAGENTA,
	Color(1.0, 0.5, 1.0)
]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _remaining: int = 0


func _ready() -> void:
	_rng.randomize()


func set_colors(colors: Array[Color]) -> void:
	if colors == null or colors.is_empty():
		Log.warn("Fireworks: set_colors(): empty or null array, keeping default colors.")
		return
	_colors = colors


func set_spawn_rect(rect: Rect2) -> void:
	spawn_rect = rect


func play() -> void:
	if not firework_scene:
		firework_scene = HeavyGraphics.load_resource(FIREWORK_SCENE_PATH) as PackedScene
	if firework_scene == null:
		# Either the device is running light, or the scene is missing; both mean
		# there is nothing to show and the caller is waiting on `finished`.
		if HeavyGraphics.enabled():
			Log.error("Fireworks: Cannot load %s" % FIREWORK_SCENE_PATH)
		emit_signal("finished")
		return
	if fireworks_count <= 0:
		emit_signal("finished")
		return
	_remaining = fireworks_count
	_spawn_fireworks_async()


func _spawn_fireworks_async() -> void:
	for _index: int in fireworks_count:
		_spawn_one_firework()
		var delay: float = _rng.randf_range(min_spawn_delay, max_spawn_delay)
		await get_tree().create_timer(delay).timeout


func _spawn_one_firework() -> void:
	var firework: Firework = firework_scene.instantiate()
	if firework == null:
		_remaining -= 1
		return
	var active_spawn_rect: Rect2 = spawn_rect if spawn_rect.has_area() else Rect2(Vector2.ZERO, screen_size)
	var spawn_end: Vector2 = active_spawn_rect.position + active_spawn_rect.size
	firework.position = Vector2(
		_rng.randf_range(active_spawn_rect.position.x, spawn_end.x),
		_rng.randf_range(active_spawn_rect.position.y, spawn_end.y)
	)
	add_child(firework)
	var color: Color = _colors[_rng.randi_range(0, _colors.size() - 1)]
	firework.play(color, _rng.randf_range(min_scale, max_scale))
	if firework.has_signal("finished"):
		firework.connect("finished", Callable(self, "_on_one_firework_finished"), CONNECT_ONE_SHOT)
	else:
		Log.error("Fireworks: Firework does not have a signal \"finished\"")
		var timer: SceneTreeTimer = get_tree().create_timer(1.5)
		timer.timeout.connect(Callable(self, "_on_one_firework_finished"), CONNECT_ONE_SHOT)


func _on_one_firework_finished() -> void:
	_remaining -= 1
	if _remaining <= 0:
		emit_signal("finished")

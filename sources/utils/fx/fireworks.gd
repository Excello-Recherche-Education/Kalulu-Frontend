class_name Fireworks
extends Node

signal finished()

@export var firework_scene: PackedScene = preload("res://sources/utils/fx/firework.tscn")
@export var fireworks_count: int = 50
@export var screen_size: Vector2 = Vector2(2560, 1800)

@export var min_spawn_delay: float = 0.01
@export var max_spawn_delay: float = 0.09
@export var min_scale: float = 0.5
@export var max_scale: float = 1.0

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


func play() -> void:
	if firework_scene == null:
		Log.error("Fireworks: firework_scene is null.")
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
	firework.position = Vector2(_rng.randf_range(0.0, screen_size.x), _rng.randf_range(0.0, screen_size.y))
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

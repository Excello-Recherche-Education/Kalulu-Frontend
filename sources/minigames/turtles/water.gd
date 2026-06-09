class_name Water
extends TextureRect

const WATER_RING_SCENE: PackedScene = preload("res://sources/utils/fx/water_ring.tscn")
# Up to MAX_TURTLE_COUNT (5) turtles each loop the swim animation roughly
# every 0.7s, so ~7-8 rings/second. The pool absorbs the bursts without
# instantiate/queue_free churn on every loop.
const POOL_SIZE: int = 12

@export var ring_color: Color

var _available_rings: Array[WaterRingFX] = []


func _ready() -> void:
	for _index: int in POOL_SIZE:
		var fx: WaterRingFX = WATER_RING_SCENE.instantiate()
		fx.modulate = ring_color
		fx.hide()
		add_child(fx)
		_available_rings.append(fx)


func spawn_water_ring(pos: Vector2) -> void:
	if _available_rings.is_empty():
		return
	var fx: WaterRingFX = _available_rings.pop_back()
	fx.position = pos
	fx.show()
	await fx.play()
	fx.hide()
	_available_rings.append(fx)

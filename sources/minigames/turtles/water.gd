class_name Water
extends TextureRect

const WATER_RING_SCENE: PackedScene = preload("res://sources/utils/fx/water_ring.tscn")
# Rings are checked out for the full 3.0s particle lifetime.
# Worst case: 5 turtles (MAX_TURTLE_COUNT) each looping the swim animation
# every 8/12 = 0.667s emit ~7.5 rings/sec → ~23 concurrent in flight.
# We pre-allocate 24 and grow on demand if real usage ever exceeds that.
const POOL_SIZE: int = 24

@export var ring_color: Color

var _available_rings: Array[WaterRingFX] = []


func _ready() -> void:
	for _index: int in POOL_SIZE:
		_available_rings.append(_make_ring())


func spawn_water_ring(pos: Vector2) -> void:
	var fx: WaterRingFX = _available_rings.pop_back() if not _available_rings.is_empty() else _make_ring()
	fx.position = pos
	fx.show()
	await fx.play()
	fx.hide()
	_available_rings.append(fx)


func _make_ring() -> WaterRingFX:
	var fx: WaterRingFX = WATER_RING_SCENE.instantiate()
	fx.modulate = ring_color
	fx.hide()
	add_child(fx)
	return fx

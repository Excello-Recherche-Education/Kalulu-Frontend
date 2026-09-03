class_name Water
extends TextureRect
## The sea the turtles swim in, and the rings they leave behind them.
##
## All of it is decoration: the water is a shader over a painted background and the
## rings are particles, and the game is played entirely on the turtles above them.
## So none of it is named by the scene -- see HeavyGraphics -- and on a device
## running light graphics none of it is loaded and the sea is simply not drawn.

const WATER_RING_SCENE_PATH: String = "res://sources/utils/fx/water_ring.tscn"
const WATER_MATERIAL_PATH: String = "res://sources/minigames/turtles/turtles_water_material.tres"
const WATER_TEXTURE_PATH: String = "res://assets/minigames/turtles/graphic/turtle_background.png"
# Rings are checked out for the full 3.0s particle lifetime.
# Worst case: 5 turtles (MAX_TURTLE_COUNT) each looping the swim animation
# every 8/12 = 0.667s emit ~7.5 rings/sec → ~23 concurrent in flight.
# We pre-allocate 24 and grow on demand if real usage ever exceeds that.
const POOL_SIZE: int = 24

@export var ring_color: Color

var _available_rings: Array[WaterRingFX] = []
## The ring particles, or null on a device running light graphics -- which is also
## what spawn_water_ring() reads to know there is nothing to spawn.
var _ring_scene: PackedScene = null


func _ready() -> void:
	texture = HeavyGraphics.load_texture(WATER_TEXTURE_PATH)
	material = HeavyGraphics.load_resource(WATER_MATERIAL_PATH) as Material
	_ring_scene = HeavyGraphics.load_resource(WATER_RING_SCENE_PATH) as PackedScene
	if not _ring_scene:
		return
	for _index: int in POOL_SIZE:
		_available_rings.append(_make_ring())


func spawn_water_ring(pos: Vector2) -> void:
	if not _ring_scene:
		return
	var fx: WaterRingFX = _available_rings.pop_back() if not _available_rings.is_empty() else _make_ring()
	fx.position = pos
	fx.show()
	await fx.play()
	fx.hide()
	_available_rings.append(fx)


func _make_ring() -> WaterRingFX:
	var fx: WaterRingFX = _ring_scene.instantiate()
	fx.modulate = ring_color
	fx.hide()
	add_child(fx)
	return fx

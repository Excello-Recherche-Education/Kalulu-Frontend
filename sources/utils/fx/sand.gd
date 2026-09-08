@tool
class_name SandVFX
extends Control
## The sand a crab kicks up as it climbs out of its hole.
##
## Decoration, and a device running light graphics does without it -- see
## HeavyGraphics. The grains are small (seven 128x128 files), so what is really
## saved is the GPU throwing up to eighteen particles every time a crab moves, on
## every hole in the game.
##
## The opting out happens here rather than at the nine places hole.gd drives this,
## so all of them keep working unchanged and none of them has to know.

## The grains, one picked at random per burst. Paths rather than preloads, so a
## light device loads none of them.
const TEXTURE_PATHS: Array[String] = [
	"res://assets/vfx/sand_01.png",
	"res://assets/vfx/sand_02.png",
	"res://assets/vfx/sand_03.png",
	"res://assets/vfx/sand_04.png",
	"res://assets/vfx/sand_05.png",
	"res://assets/vfx/sand_06.png",
	"res://assets/vfx/sand_07.png",
]

var is_playing: bool = false
## The grains that were loaded, or empty on a device running light -- which is also
## what play() and start() read to know there is no sand to throw.
var _textures: Array[Texture2D] = []

@onready var particles: GPUParticles2D = $Particles
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.wait_time = particles.lifetime
	for path: String in TEXTURE_PATHS:
		var grain: Texture2D = HeavyGraphics.load_texture(path)
		if grain:
			_textures.append(grain)
	if _textures.is_empty():
		particles.emitting = false
		particles.hide()


func play() -> void:
	if _textures.is_empty():
		return
	particles.texture = _textures.pick_random()
	particles.amount = randi_range(6, 18)
	particles.restart()


func start() -> void:
	if _textures.is_empty():
		return
	is_playing = true
	_on_timer_timeout()


func stop() -> void:
	is_playing = false
	timer.stop()


func _on_timer_timeout() -> void:
	play()
	timer.start()

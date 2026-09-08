class_name LazySprite2D
extends Sprite2D
## A Sprite2D whose picture is named by path rather than held by the scene.
##
## The Sprite2D counterpart of LazyTextureRect, for the decoration that is placed
## in world space rather than laid out. Same reason, same behaviour.

## The picture to draw, or empty for a sprite whose owner sets it (see load_from).
@export_file("*.png") var texture_path: String = ""


func _ready() -> void:
	load_from(texture_path)


## Draws the picture at `path`, or nothing at all on a device running light.
func load_from(path: String) -> void:
	texture_path = path
	texture = HeavyGraphics.load_texture(path)

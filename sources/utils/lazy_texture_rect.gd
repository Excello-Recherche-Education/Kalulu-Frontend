class_name LazyTextureRect
extends TextureRect
## A TextureRect whose picture is named by path rather than held by the scene.
##
## The point is what the scene does *not* say: a `texture = ExtResource(...)` is
## loaded whenever the scene is, so a device running light graphics would pay for
## every background before deciding not to draw one. Naming the file instead leaves
## the loading to HeavyGraphics, which declines it. See HeavyGraphics.

## The picture to draw, or empty for a rect whose owner sets it (see load_from).
@export_file("*.png") var texture_path: String = ""


func _ready() -> void:
	load_from(texture_path)


## Draws the picture at `path`, or nothing at all on a device running light.
func load_from(path: String) -> void:
	texture_path = path
	texture = HeavyGraphics.load_texture(path)

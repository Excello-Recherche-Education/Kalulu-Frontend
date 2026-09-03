class_name HeavyGraphics
extends RefCounted
## The decorative artwork, and the one switch that turns it off.
##
## Some of what the game draws is there to make the world pleasant rather than to
## teach anything: the backgrounds behind the minigames, the clouds drifting over
## them, the animal friends watching the boss, the moving water in the turtle game.
## Together they are most of the texture memory the game asks for -- the boss's
## Kalulu sheet alone is 2400x2400 -- and on a cheap tablet that is the difference
## between a game that runs and one the system kills.
##
## Turning the switch off has to mean two things, and only the second is obvious:
##
##   - the artwork is not drawn, and
##   - it was never loaded to begin with.
##
## A texture named by a scene is loaded when that scene is, so hiding a node after
## the fact saves nothing at all. That is why nothing reached through here is a
## `preload` or a `texture = ExtResource(...)` in a scene: every one of them is a
## path, and load_texture() is what turns a path into a texture -- or into null,
## on a device that asked for the light version.


## True on a device that can afford the decoration. Everything below is drawn only
## while this holds.
static func enabled() -> bool:
	return not UserDataManager.get_light_graphics()


## The texture at `path`, or null on a device running light.
##
## Null rather than a placeholder: a TextureRect with no texture draws nothing and
## takes no space, which is exactly what is wanted.
static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not enabled():
		return null
	return load(path) as Texture2D


## The resource at `path`, or null on a device running light.
##
## For the pieces that are not textures -- a shader material, a particle scene --
## and that would otherwise be pulled in by the scene that uses them.
static func load_resource(path: String) -> Resource:
	if path.is_empty() or not enabled():
		return null
	return load(path)

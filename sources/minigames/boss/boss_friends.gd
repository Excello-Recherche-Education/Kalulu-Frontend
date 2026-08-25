class_name BossFriends
extends Node2D

## The animal friends that keep the player company in the boss minigame.
##
## The boss minigame used to fill this role by instantiating the eight animal
## scenes from the other minigames. Those scenes reference their full
## spritesheets -- around 383 MB of imported texture data between them, several
## of which the boss never shows a single pixel of -- to draw eight small
## sprites that never move, and that the boss immediately stops on frame 0.
## On low-end Android hardware that alone could stall the scene for seconds, or
## get the app killed for running out of memory.
##
## Only the frames the boss actually plays are kept, in atlases sized for how
## small each friend is really drawn. To regenerate them and this scene:
##
##     godot --headless --path . res://tools/measure_boss_friends.tscn
##     python3 tools/generate_boss_friends_atlas.py
##     godot --headless --path . res://tools/build_boss_friends.tscn

## Animation each friend plays on a win, keyed by node name. A friend that is
## absent keeps showing its idle frame, which is what the animal scenes did as
## well: the jellyfish's victory animation played on its hidden arms layer, and
## the monkey, turtle and frog replayed the very animation they idle on.
const VICTORY_ANIMATIONS: Dictionary[StringName, StringName] = {
	&"Monkey": &"idle",
	&"Turtle": &"swim",
	&"Penguin": &"happy",
	&"Frog": &"idle_front",
	&"Crab": &"right",
	&"Parakeet": &"happy",
	&"Ant": &"success",
}


## Puts every friend back on the first frame of its idle animation.
func idle() -> void:
	for sprite: AnimatedSprite2D in _animated_sprites():
		sprite.stop()


## Plays each friend's celebration. Friends without one stay on their idle frame.
func victory() -> void:
	for sprite: AnimatedSprite2D in _animated_sprites():
		var animation: StringName = VICTORY_ANIMATIONS.get(sprite.name, &"")
		if animation.is_empty() or not sprite.sprite_frames.has_animation(animation):
			continue
		sprite.play(animation)


func _animated_sprites() -> Array[AnimatedSprite2D]:
	var sprites: Array[AnimatedSprite2D] = []
	for child: Node in get_children():
		if child is AnimatedSprite2D:
			sprites.append(child)
	return sprites

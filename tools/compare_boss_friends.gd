extends Node

## Renders the boss minigame's animal friends the old way and the new way and
## writes both frames to disk, so they can be pixel-diffed. This is the check
## that the slim atlases and the rebuilt scenes land on exactly the same pixels
## as instantiating the eight animal scenes did.
##
## Must run WITHOUT --headless; the dummy renderer produces empty frames.
##   godot --path <project> --resolution 320x200 res://tools/compare_boss_friends.tscn

const OLD_OUTPUT: String = "user://boss_friends_old.png"
const NEW_OUTPUT: String = "user://boss_friends_new.png"

const VIEWPORT_SIZE: Vector2i = Vector2i(2560, 1800)
const FRONT_ORIGIN: Vector2 = Vector2(1676, 1280)

const TURTLE_FRIEND_SPRITE_FRAMES_PATH: String = "res://sources/minigames/turtles/purple_turtle_animations.tres"
const ANIMAL_SCENES: Dictionary = {
	"monkey": "res://sources/minigames/monkeys/monkey.tscn",
	"turtle": "res://sources/minigames/turtles/turtle.tscn",
	"penguin": "res://sources/minigames/penguin/penguin.tscn",
	"frog": "res://sources/minigames/frog/frog.tscn",
	"crab": "res://sources/minigames/crabs/crab/crab.tscn",
	"parakeet": "res://sources/minigames/parakeets/parakeet.tscn",
	"ant": "res://sources/minigames/ants/ant.tscn",
	"jellyfish": "res://sources/minigames/jellyfish/jellyfish.tscn",
}

const NEW_FRONT_SCENE: String = "res://sources/minigames/boss/boss_friends.tscn"
const NEW_BEHIND_SCENE: String = "res://sources/minigames/boss/boss_friends_behind.tscn"


func _ready() -> void:
	var old_image: Image = await _render(_build_old)
	old_image.save_png(OLD_OUTPUT)
	print("wrote ", ProjectSettings.globalize_path(OLD_OUTPUT))

	var new_image: Image = await _render(_build_new)
	new_image.save_png(NEW_OUTPUT)
	print("wrote ", ProjectSettings.globalize_path(NEW_OUTPUT))

	get_tree().quit()


func _render(builder: Callable) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var front: Node2D = Node2D.new()
	front.position = FRONT_ORIGIN
	var behind: Node2D = Node2D.new()
	# Behind-the-frame friends are positioned in GameRoot space already.
	viewport.add_child(behind)
	viewport.add_child(front)

	builder.call(front, behind)

	for _i: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image


func _build_old(front: Node2D, behind: Node2D) -> void:
	var roots: Dictionary = {}

	var monkey: Node = (load(ANIMAL_SCENES.monkey) as PackedScene).instantiate()
	monkey.position = Vector2(125, 62)
	monkey.scale = Vector2(0.7, 0.7)
	front.add_child(monkey)
	roots["monkey"] = monkey

	var turtle: Node = (load(ANIMAL_SCENES.turtle) as PackedScene).instantiate()
	turtle.position = Vector2(-220, 120)
	turtle.rotation = 1.5707964
	turtle.scale = Vector2(0.18, 0.18)
	front.add_child(turtle)
	turtle.sprite_frames = load(TURTLE_FRIEND_SPRITE_FRAMES_PATH)
	roots["turtle"] = turtle

	var penguin: Node = (load(ANIMAL_SCENES.penguin) as PackedScene).instantiate()
	penguin.position = Vector2(28, 114)
	penguin.scale = Vector2(0.3, 0.3)
	front.add_child(penguin)
	roots["penguin"] = penguin

	var frog: Node = (load(ANIMAL_SCENES.frog) as PackedScene).instantiate()
	frog.offset_left = -43.999985
	frog.offset_top = 112.0
	frog.offset_right = -43.999985
	frog.offset_bottom = 112.0
	frog.scale = Vector2(0.4, 0.4)
	front.add_child(frog)
	roots["frog"] = frog

	var crab: Node = (load(ANIMAL_SCENES.crab) as PackedScene).instantiate()
	crab.offset_left = -220.0
	crab.offset_top = 32.0
	crab.offset_right = 148.0
	crab.offset_bottom = 352.0
	crab.scale = Vector2(0.45, 0.45)
	front.add_child(crab)
	roots["crab"] = crab

	var parakeet: Node = (load(ANIMAL_SCENES.parakeet) as PackedScene).instantiate()
	parakeet.position = Vector2(124, -103)
	parakeet.scale = Vector2(0.09, 0.09)
	front.add_child(parakeet)
	roots["parakeet"] = parakeet

	var ant: Node = (load(ANIMAL_SCENES.ant) as PackedScene).instantiate()
	ant.position = Vector2(228, 132)
	ant.scale = Vector2(0.17, 0.17)
	front.add_child(ant)
	roots["ant"] = ant

	var jellyfish: Node = (load(ANIMAL_SCENES.jellyfish) as PackedScene).instantiate()
	jellyfish.offset_left = 1449.0001
	jellyfish.offset_top = 1301.0001
	jellyfish.offset_right = 1849.0001
	jellyfish.offset_bottom = 1701.0001
	jellyfish.scale = Vector2(0.45, 0.45)
	jellyfish.boss = true
	behind.add_child(jellyfish)
	roots["jellyfish"] = jellyfish

	for name: String in roots:
		roots[name].idle_boss()


func _build_new(front: Node2D, behind: Node2D) -> void:
	var friends: Node = (load(NEW_FRONT_SCENE) as PackedScene).instantiate()
	front.add_child(friends)
	var friends_behind: Node = (load(NEW_BEHIND_SCENE) as PackedScene).instantiate()
	behind.add_child(friends_behind)
	friends.idle()
	friends_behind.idle()

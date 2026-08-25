extends Node

## Measures the texture memory the boss minigame's friends cost, either the old
## way (instantiating the eight animal scenes) or the new way (the two slim
## friend scenes). Run each in its own process so the resource cache of one does
## not colour the other, and WITHOUT --headless so there is a real renderer:
##
##   godot --path <project> --resolution 320x200 res://tools/measure_boss_friends_vram.tscn -- old
##   godot --path <project> --resolution 320x200 res://tools/measure_boss_friends_vram.tscn -- new

const TURTLE_FRIEND_SPRITE_FRAMES_PATH: String = "res://sources/minigames/turtles/purple_turtle_animations.tres"


func _ready() -> void:
	var mode: String = "new"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]

	for _i: int in range(10):
		await get_tree().process_frame
	var baseline: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	var start: int = Time.get_ticks_msec()
	if mode == "old":
		_build_old()
	else:
		_build_new()
	var instantiate_ms: int = Time.get_ticks_msec() - start

	for _i: int in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	print("RESULT mode=%s texture_mem_delta_mb=%.2f baseline_mb=%.2f instantiate_ms=%d" % [
		mode, (after - baseline) / 1048576.0, baseline / 1048576.0, instantiate_ms
	])
	get_tree().quit()


func _build_new() -> void:
	var front: Node2D = Node2D.new()
	front.position = Vector2(1676, 1280)
	add_child(front)
	var behind: Node2D = Node2D.new()
	add_child(behind)

	var friends: Node = (load("res://sources/minigames/boss/boss_friends.tscn") as PackedScene).instantiate()
	front.add_child(friends)
	var friends_behind: Node = (load("res://sources/minigames/boss/boss_friends_behind.tscn") as PackedScene).instantiate()
	behind.add_child(friends_behind)
	friends.idle()
	friends_behind.idle()


func _build_old() -> void:
	var front: Node2D = Node2D.new()
	front.position = Vector2(1676, 1280)
	add_child(front)
	var behind: Node2D = Node2D.new()
	add_child(behind)

	var roots: Dictionary = {}

	var monkey: Node = (load("res://sources/minigames/monkeys/monkey.tscn") as PackedScene).instantiate()
	monkey.position = Vector2(125, 62)
	monkey.scale = Vector2(0.7, 0.7)
	front.add_child(monkey)
	roots["monkey"] = monkey

	var turtle: Node = (load("res://sources/minigames/turtles/turtle.tscn") as PackedScene).instantiate()
	turtle.position = Vector2(-220, 120)
	turtle.rotation = 1.5707964
	turtle.scale = Vector2(0.18, 0.18)
	front.add_child(turtle)
	turtle.sprite_frames = load(TURTLE_FRIEND_SPRITE_FRAMES_PATH)
	roots["turtle"] = turtle

	var penguin: Node = (load("res://sources/minigames/penguin/penguin.tscn") as PackedScene).instantiate()
	penguin.position = Vector2(28, 114)
	penguin.scale = Vector2(0.3, 0.3)
	front.add_child(penguin)
	roots["penguin"] = penguin

	var frog: Node = (load("res://sources/minigames/frog/frog.tscn") as PackedScene).instantiate()
	frog.offset_left = -43.999985
	frog.offset_top = 112.0
	frog.offset_right = -43.999985
	frog.offset_bottom = 112.0
	frog.scale = Vector2(0.4, 0.4)
	front.add_child(frog)
	roots["frog"] = frog

	var crab: Node = (load("res://sources/minigames/crabs/crab/crab.tscn") as PackedScene).instantiate()
	crab.offset_left = -220.0
	crab.offset_top = 32.0
	crab.offset_right = 148.0
	crab.offset_bottom = 352.0
	crab.scale = Vector2(0.45, 0.45)
	front.add_child(crab)
	roots["crab"] = crab

	var parakeet: Node = (load("res://sources/minigames/parakeets/parakeet.tscn") as PackedScene).instantiate()
	parakeet.position = Vector2(124, -103)
	parakeet.scale = Vector2(0.09, 0.09)
	front.add_child(parakeet)
	roots["parakeet"] = parakeet

	var ant: Node = (load("res://sources/minigames/ants/ant.tscn") as PackedScene).instantiate()
	ant.position = Vector2(228, 132)
	ant.scale = Vector2(0.17, 0.17)
	front.add_child(ant)
	roots["ant"] = ant

	var jellyfish: Node = (load("res://sources/minigames/jellyfish/jellyfish.tscn") as PackedScene).instantiate()
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

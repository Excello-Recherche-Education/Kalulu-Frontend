extends Node

## Loads and instantiates the boss minigame far enough to confirm the scene and
## its friends come up without errors.

func _ready() -> void:
	var scene: PackedScene = load("res://sources/minigames/boss/boss_minigame.tscn")
	if not scene:
		print("SMOKE FAIL: boss_minigame.tscn did not load")
		get_tree().quit(1)
		return
	var boss: Node = scene.instantiate()
	add_child(boss)
	for _i: int in range(10):
		await get_tree().process_frame

	var friends: Node = boss.get_node_or_null("GameRoot/Friends/BossFriends")
	var behind: Node = boss.get_node_or_null("GameRoot/Friends_Behind_Frame/BossFriendsBehind")
	print("SMOKE friends=%s (%d sprites) behind=%s (%d sprites)" % [
		friends != null, friends.get_child_count() if friends else -1,
		behind != null, behind.get_child_count() if behind else -1,
	])

	# Exercise the win path, which is what plays the celebration animations.
	boss.win_with_friends()
	for _i: int in range(5):
		await get_tree().process_frame

	var playing: Array[String] = []
	if friends:
		for child: Node in friends.get_children():
			if child is AnimatedSprite2D and (child as AnimatedSprite2D).is_playing():
				playing.append("%s:%s" % [child.name, (child as AnimatedSprite2D).animation])
	print("SMOKE victory playing: ", ", ".join(playing))
	print("SMOKE OK")
	get_tree().quit()

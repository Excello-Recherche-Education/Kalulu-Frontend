extends Node

## Drives the reward's reading-Kalulu lifecycle and reports texture memory at each
## step, to confirm the deferred load still produces a working Kalulu and that
## dismissing it actually gives the memory back.
##
##   godot --path <project> --resolution 320x200 res://tools/verify_brain_reward.tscn

const SCRIPT_PATH: String = "res://sources/brain/brain_reward.gd"
const SCENE_PATH: String = "res://sources/kalulu_animator_reading.tscn"


func _mb() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


func _settle(frames: int = 20) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _ready() -> void:
	await _settle(10)
	var base: float = _mb()

	var reward: Node = load(SCRIPT_PATH).new()
	add_child(reward)
	reward._build_runtime()
	await _settle()
	print("STEP setup                 mem=%+.1f MB   kalulu_instantiated=%s" % [
		_mb() - base, reward._reading_kalulu != null])

	# What play() does first.
	ResourceLoader.load_threaded_request(SCENE_PATH)
	await reward._build_reading_kalulu()
	await _settle()
	var kalulu: AnimatedSprite2D = reward._reading_kalulu
	print("STEP after build           mem=%+.1f MB   kalulu_instantiated=%s" % [
		_mb() - base, kalulu != null])
	if not kalulu:
		print("VERIFY FAIL: no Kalulu was built")
		get_tree().quit(1)
		return

	var animations: Array = []
	for a: StringName in kalulu.sprite_frames.get_animation_names():
		animations.append(String(a))
	print("STEP animations available  %s" % [animations])
	print("STEP position              %s   parent=%s" % [kalulu.position, kalulu.get_parent().get_class()])

	# Exercise the animations the sequence plays.
	for animation: StringName in [&"Show", &"Talk", &"Idle"]:
		kalulu.show()
		kalulu.play(animation)
		await _settle(3)
		print("STEP play(%-6s)         playing=%s frame=%d" % [animation, kalulu.is_playing(), kalulu.frame])

	# Now dismiss, which should free it.
	await reward._hide_kalulu()
	await _settle(30)
	print("STEP after dismiss         mem=%+.1f MB   kalulu_instantiated=%s" % [
		_mb() - base, reward._reading_kalulu != null])

	# And a replay must be able to build it again.
	ResourceLoader.load_threaded_request(SCENE_PATH)
	await reward._build_reading_kalulu()
	await _settle()
	print("STEP replay rebuild        mem=%+.1f MB   kalulu_instantiated=%s" % [
		_mb() - base, reward._reading_kalulu != null])

	print("VERIFY OK")
	get_tree().quit()

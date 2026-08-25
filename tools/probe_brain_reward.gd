extends Node

## Measures the texture memory brain_reward.gd pins the moment the SCRIPT loads --
## which is when anything first references BrainReward, not when a reward plays.
## Loaded dynamically on purpose: naming the class directly would make it a
## compile-time dependency of this probe, so it would already be resident before
## the baseline is taken.
##
##   godot --path <project> --resolution 320x200 res://tools/probe_brain_reward.tscn

const SCRIPT_PATH: String = "res://sources/brain/brain_reward.gd"


func _ready() -> void:
	for _i: int in range(10):
		await get_tree().process_frame
	var baseline: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	var start: int = Time.get_ticks_msec()
	var script: GDScript = load(SCRIPT_PATH)
	var load_ms: int = Time.get_ticks_msec() - start
	if not script:
		print("BRAINREWARD FAIL could not load script")
		get_tree().quit(1)
		return

	for _i: int in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)

	print("BRAINREWARD script_load_texture_mb=%.1f load_ms=%d" % [
		(after - baseline) / 1048576.0, load_ms])
	get_tree().quit()

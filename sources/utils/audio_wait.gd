class_name AudioWait
extends RefCounted
## Waits for the sound on an audio player to end, without trusting its finished signal.
##
## finished is only emitted once a sound has actually been mixed to its end. When the
## device's audio output has stopped -- seen in 3.1.5 on a tablet whose sound system
## had died, until it was locked and unlocked -- nothing is mixed, playing stays true
## and finished never comes, so every `await player.finished` waits forever. It also
## never comes after stop(). This counts the stream's remaining length down instead,
## and ends early when the player stops, so it resolves whether or not anything is
## heard.
##
## Time is only counted on frames where the player itself processes, so a pausable
## player paused with the tree holds the wait with it, and one that runs while the
## tree is paused -- Kalulu's speech -- keeps counting.
##
## Pass an AudioStreamPlayer or an AudioStreamPlayer2D, after play(). A looping stream
## is waited on for one pass.


static func until_done(player: Node) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var stream: AudioStream = player.get("stream") as AudioStream
	# has_stream_playback, not playing: playing reads false while a pausable player is
	# paused with the tree, which would end the wait at the first pause.
	if not stream or not player.call("has_stream_playback"):
		return

	var pitch: float = maxf(player.get("pitch_scale") as float, 0.01)
	var remaining: float = (stream.get_length() - (player.call("get_playback_position") as float)) / pitch
	var tree: SceneTree = player.get_tree()
	# Wall-clock time since the call rather than frame deltas: the first frame's delta
	# also covers whatever ran before the wait began -- often the sound being loaded --
	# and would end the wait early by that much. The sound plays in real time too.
	var last_tick: int = Time.get_ticks_usec()
	while remaining > 0.0:
		await tree.process_frame
		# Freed or taken out of the tree during the wait: nothing left to wait for.
		if not is_instance_valid(player) or not player.is_inside_tree():
			return
		# Stopped by hand, or ended normally -- whichever comes first.
		if not player.call("has_stream_playback"):
			return
		var now: int = Time.get_ticks_usec()
		if player.can_process():
			remaining -= (now - last_tick) / 1_000_000.0
		last_tick = now

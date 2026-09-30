extends GutTest

# AudioWait.until_done has to resolve whether or not the device is producing sound.
# A dead audio output is reproduced with a stand-in player: a playback that exists
# forever with its position stuck at zero, which is exactly what a real player shows
# when nothing is being mixed -- and why its finished signal never comes.

const SOUND_LENGTH: float = 0.3


class DeadAudioPlayer:
	extends Node

	var stream: AudioStream
	var pitch_scale: float = 1.0
	var has_playback: bool = true

	func has_stream_playback() -> bool:
		return has_playback

	func get_playback_position() -> float:
		return 0.0


func _silent_stream(length: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(length * stream.mix_rate) * 2)
	stream.data = data
	return stream


func _dead_player(length: float = SOUND_LENGTH) -> DeadAudioPlayer:
	var player: DeadAudioPlayer = DeadAudioPlayer.new()
	player.stream = _silent_stream(length)
	add_child_autofree(player)
	return player


# Resolves the wait in the background and reports when it did, in seconds.
func _time_wait(player: Node, done: Array[float]) -> void:
	var start: int = Time.get_ticks_msec()
	await AudioWait.until_done(player)
	done[0] = (Time.get_ticks_msec() - start) / 1000.0


func _wait_until(done: Array[float], seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while done[0] < 0.0 and Time.get_ticks_msec() - start < seconds * 1000.0:
		await get_tree().process_frame


func test_dead_audio_still_ends_after_the_sound_length() -> void:
	var player: DeadAudioPlayer = _dead_player()
	var done: Array[float] = [-1.0]
	_time_wait(player, done)
	await _wait_until(done, 3.0)
	assert_gt(done[0], 0.0, "a sound nobody hears must still end, or the game freezes")
	assert_gt(done[0], SOUND_LENGTH - 0.05, "and not before the sound would have ended")
	assert_lt(done[0], SOUND_LENGTH + 0.5, "nor long after it")


func test_stopping_ends_the_wait_at_once() -> void:
	var player: DeadAudioPlayer = _dead_player(5.0)
	var done: Array[float] = [-1.0]
	_time_wait(player, done)
	await get_tree().process_frame
	player.has_playback = false
	await _wait_until(done, 1.0)
	assert_gt(done[0], -1.0, "stop() leaves no playback, which is what the pass button relies on")
	assert_lt(done[0], 1.0, "and it must not wait out the rest of the sound")


func test_nothing_playing_returns_immediately() -> void:
	var player: DeadAudioPlayer = _dead_player()
	player.has_playback = false
	var done: Array[float] = [-1.0]
	_time_wait(player, done)
	assert_gt(done[0], -1.0, "with no playback there is nothing to wait for")


func test_a_freed_player_ends_the_wait() -> void:
	var player: DeadAudioPlayer = DeadAudioPlayer.new()
	player.stream = _silent_stream(5.0)
	add_child(player)
	var done: Array[float] = [-1.0]
	_time_wait(player, done)
	await get_tree().process_frame
	player.free()
	await _wait_until(done, 1.0)
	assert_gt(done[0], -1.0, "a player freed mid-wait must not strand the caller")


func test_a_paused_pausable_player_holds_the_wait() -> void:
	var player: DeadAudioPlayer = _dead_player()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	var done: Array[float] = [-1.0]
	_time_wait(player, done)
	get_tree().paused = true
	# Twice the sound's length, spent paused: none of it may count.
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < SOUND_LENGTH * 2000.0:
		await get_tree().process_frame
	var ended_while_paused: bool = done[0] >= 0.0
	get_tree().paused = false
	await _wait_until(done, 3.0)
	assert_false(ended_while_paused, "the pause button has to hold the sound's wait with it")
	assert_gt(done[0], SOUND_LENGTH * 2.0, "and the wait resumes once the tree runs again")


func test_a_player_that_runs_while_paused_keeps_counting() -> void:
	# Kalulu's speech plays while minigame_ui has the tree paused.
	var player: DeadAudioPlayer = _dead_player()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var done: Array[float] = [-1.0]
	get_tree().paused = true
	_time_wait(player, done)
	await _wait_until(done, 3.0)
	get_tree().paused = false
	assert_gt(done[0], 0.0, "a speech played over a paused tree must still end")
	assert_lt(done[0], SOUND_LENGTH + 0.5, "at its own length")


func test_a_real_player_ends_with_its_sound() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = _silent_stream(SOUND_LENGTH)
	add_child_autofree(player)
	player.play()
	var done: Array[float] = [-1.0]
	_time_wait(player, done)
	await _wait_until(done, 3.0)
	assert_gt(done[0], 0.0, "a sound that is actually mixed ends too")
	assert_lt(done[0], SOUND_LENGTH + 0.5, "at its own length")

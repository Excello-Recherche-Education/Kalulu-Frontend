class_name BrainReward
extends Node

## Orchestrates the celebratory "reward" animation on the brain screen after the
## player beats the final boss. Triggered by clicking the treasure chest: the first
## time on the closed chest, then replayable on the open one. Sequence: treasure
## opens -> pause -> gardens turn purple one by one -> brain body turns purple ->
## brain fades out (leaving the starry sky) -> the reading Kalulu shows, speaks,
## then idles; clicking dismisses it (Hide) and the brain is restored.
##
## The endgame music runs under the whole sequence, from the click on the chest to the
## click that dismisses Kalulu — ducked to half while Kalulu talks, then faded out on
## the dismissing click. See _start_music() / _fade_out_music().

# Purple tones sampled from the target design; tweak here to taste.
const GARDEN_BACKGROUND_PURPLE: Color = Color("842984")
const GARDEN_VICTORY_ASSET_PURPLE: Color = Color("32113c")
const BRAIN_PURPLE: Color = Color("7b3a8c")
const RECOLOR_SHADER: Shader = preload("res://resources/shaders/recolor.gdshader")
# A path, not a preload: this scene's spritesheet is 7500x7501 of lossless art,
# 286 MB of texture memory, and a const preload would pull it in the moment
# anything so much as referenced BrainReward. It is loaded in the background
# when a reward starts and freed once Kalulu is dismissed.
const READING_KALULU_SCENE_PATH: String = "res://sources/kalulu_animator_reading.tscn"
const RIGHT_STARS_FX_SCENE: PackedScene = preload("res://sources/utils/fx/right_stars.tscn")
const FIREWORKS_SCENE: PackedScene = preload("res://sources/utils/fx/fireworks.tscn")
const WIN_SOUND_FX: AudioStreamMP3 = preload("res://assets/sfx/sfx_game_over_win.mp3")
const ENDGAME_MUSIC: AudioStreamMP3 = preload("res://assets/music/endgame.mp3")
# Amplitudes rather than decibels, so "half the volume while Kalulu talks" reads as
# what it is. The fade-out is a straight ramp down to silence for the same reason: a
# ramp in decibels would be inaudible for most of its length and then cut.
const MUSIC_FULL_VOLUME: float = 1.0
const MUSIC_TALK_VOLUME: float = 0.5
const MUSIC_FADE_OUT_DURATION: float = 1.39
const GARDEN_TINT_DURATION: float = 0.5
const BRAIN_TINT_DURATION: float = 2.0
const BRAIN_FADE_DURATION: float = 3.0
const RESTORE_DURATION: float = 1.0
const TREASURE_PAUSE: float = 1.0
const GARDEN_FIREWORKS_COUNT: int = 12
const GARDEN_FIREWORKS_LEAD_IN: float = 0.5
const GARDEN_FIREWORKS_MIN_DELAY: float = 0.0
const GARDEN_FIREWORKS_MAX_DELAY: float = 0.005
const GARDEN_FIREWORKS_MIN_SCALE: float = 0.12
const GARDEN_FIREWORKS_MAX_SCALE: float = 0.22
const GARDEN_FIREWORKS_RECT_EXPAND_RATIO: float = 0.05

# References into the brain scene, provided by Brain via setup().
var _brain_map: TextureRect
var _treasure: TreasureChest
var _gardens: Array[Garden] = []
var _ui_layer: CanvasLayer
# Runtime nodes built in _build_runtime().
var _overlay_layer: CanvasLayer
var _reading_kalulu: AnimatedSprite2D
var _click_catcher: Button
var _voice_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_fade_tween: Tween
var _brain_material: ShaderMaterial
var _is_playing: bool = false
var _speech: AudioStream


func setup(brain_map: TextureRect, treasure: TreasureChest, gardens: Array[Garden], ui_layer: CanvasLayer) -> void:
	_brain_map = brain_map
	_treasure = treasure
	_gardens = gardens
	_ui_layer = ui_layer
	_build_runtime()


func is_playing() -> bool:
	return _is_playing


# Runs the full reward sequence. `open_treasure` is true only for the very first
# play; on replays the chest is already open, so steps 1-2 (open + pause) are
# skipped.
func play(open_treasure: bool) -> void:
	if _is_playing:
		return
	_is_playing = true

	# Hide the back / kalulu buttons for the duration of the animation.
	_ui_layer.hide()
	_start_music()

	# Ask for the reading Kalulu now and carry on: the treasure, the garden tints
	# and the brain fade below run for several seconds, which is long enough to
	# hide the load completely.
	ResourceLoader.load_threaded_request(READING_KALULU_SCENE_PATH)

	if open_treasure:
		await _open_treasure()
		await get_tree().create_timer(TREASURE_PAUSE).timeout

	await _tint_gardens()
	await _tint_brain()
	await _fade_out_brain()
	await _show_and_speak()
	# The sequence now waits for the player's click; _on_click_catcher_pressed()
	# hides Kalulu, restores the brain and clears _is_playing.


#region Runtime setup

func _build_runtime() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)

	# Full-screen transparent catcher so a tap anywhere dismisses Kalulu.
	_click_catcher = Button.new()
	_click_catcher.flat = true
	_click_catcher.focus_mode = Control.FOCUS_NONE
	_click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_catcher.hide()
	_click_catcher.pressed.connect(_on_click_catcher_pressed)
	_overlay_layer.add_child(_click_catcher)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = &"Voice"
	add_child(_voice_player)

	# Its own player rather than MusicManager's: that one loops whatever it is given, and
	# the endgame track is meant to be heard once, from the chest to the last click.
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.stream = ENDGAME_MUSIC
	add_child(_music_player)

	_speech = Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "victory"))

#endregion

#region Sequence steps

func _open_treasure() -> void:
	# TODO: replace this placeholder star burst with the final "big victory" FX.
	var fx: Node2D = RIGHT_STARS_FX_SCENE.instantiate() as Node2D
	fx.scale = Vector2(3.0, 3.0)
	fx.position = _treasure.get_visible_center()
	_overlay_layer.add_child(fx)
	_voice_player.stream = WIN_SOUND_FX
	_voice_player.play()
	(fx as RightStarsFX).play()
	# Swap the texture mid-burst so the FX masks the closed -> open transition.
	await get_tree().create_timer(0.25).timeout
	_treasure.set_opened(true)
	await get_tree().create_timer(1.0).timeout
	fx.queue_free()


func _tint_gardens() -> void:
	for garden: Garden in _gardens:
		_play_garden_fireworks(garden)
		await get_tree().create_timer(GARDEN_FIREWORKS_LEAD_IN).timeout
		var materials: Array[ShaderMaterial] = garden.apply_recolor(GARDEN_BACKGROUND_PURPLE, GARDEN_VICTORY_ASSET_PURPLE)
		if materials.is_empty():
			continue
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		for material: ShaderMaterial in materials:
			tween.tween_property(material, "shader_parameter/mix_amount", 1.0, GARDEN_TINT_DURATION)
		await tween.finished


func _tint_brain() -> void:
	_brain_material = ShaderMaterial.new()
	_brain_material.shader = RECOLOR_SHADER
	_brain_material.set_shader_parameter("target_color", BRAIN_PURPLE)
	_brain_material.set_shader_parameter("mix_amount", 0.0)
	_brain_map.material = _brain_material
	var tween: Tween = create_tween()
	tween.tween_property(_brain_material, "shader_parameter/mix_amount", 1.0, BRAIN_TINT_DURATION)
	await tween.finished


func _fade_out_brain() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_brain_map, "modulate:a", 0.0, BRAIN_FADE_DURATION)
	await tween.finished


func _play_garden_fireworks(garden: Garden) -> void:
	var fireworks: Fireworks = FIREWORKS_SCENE.instantiate() as Fireworks
	if fireworks == null:
		return
	fireworks.fireworks_count = GARDEN_FIREWORKS_COUNT
	fireworks.min_spawn_delay = GARDEN_FIREWORKS_MIN_DELAY
	fireworks.max_spawn_delay = GARDEN_FIREWORKS_MAX_DELAY
	fireworks.min_scale = GARDEN_FIREWORKS_MIN_SCALE
	fireworks.max_scale = GARDEN_FIREWORKS_MAX_SCALE
	fireworks.set_colors(_garden_firework_colors(garden.get_reward_color()))
	fireworks.set_spawn_rect(_expand_rect(garden.get_reward_rect(), GARDEN_FIREWORKS_RECT_EXPAND_RATIO))
	fireworks.finished.connect(Callable(fireworks, "queue_free"), CONNECT_ONE_SHOT)
	_overlay_layer.add_child(fireworks)
	fireworks.play()


func _garden_firework_colors(garden_color: Color) -> Array[Color]:
	garden_color.a = 1.0
	var colors: Array[Color] = []
	colors.append(garden_color)
	colors.append(garden_color.lightened(0.25))
	colors.append(garden_color.lightened(0.45))
	return colors


func _expand_rect(rect: Rect2, expand_ratio: float) -> Rect2:
	if not rect.has_area():
		return rect
	var expand: Vector2 = rect.size * expand_ratio
	return Rect2(rect.position - expand, rect.size + expand * 2.0)


## Instantiates the reading Kalulu from the load play() kicked off, waiting for it
## if the sequence somehow outran it.
func _build_reading_kalulu() -> void:
	if _reading_kalulu:
		return

	while ResourceLoader.load_threaded_get_status(READING_KALULU_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var scene: PackedScene
	if ResourceLoader.load_threaded_get_status(READING_KALULU_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		scene = ResourceLoader.load_threaded_get(READING_KALULU_SCENE_PATH) as PackedScene
	else:
		# No request outstanding, or it failed; a blocking load still beats no Kalulu.
		scene = load(READING_KALULU_SCENE_PATH) as PackedScene
	if not scene:
		return

	_reading_kalulu = scene.instantiate() as AnimatedSprite2D
	_reading_kalulu.position = Vector2(1280, 900)
	_reading_kalulu.hide()
	_overlay_layer.add_child(_reading_kalulu)


func _show_and_speak() -> void:
	await _build_reading_kalulu()
	if not _reading_kalulu:
		Log.error("BrainReward: the reading Kalulu could not be loaded")
		_click_catcher.show()
		return
	_reading_kalulu.show()
	_reading_kalulu.play(&"Show")
	await _reading_kalulu.animation_finished
	_reading_kalulu.play(&"Talk")
	if _speech:
		# Down to half for as long as the speech lasts, back to full right after: the
		# music keeps the scene alive without ever talking over Kalulu.
		_music_player.volume_linear = MUSIC_TALK_VOLUME
		_voice_player.stream = _speech
		_voice_player.play()
		await _voice_player.finished
		_music_player.volume_linear = MUSIC_FULL_VOLUME
	else:
		Log.warn("BrainReward: victory speech not found")
		await get_tree().create_timer(1.5).timeout
	# kalulu_animator.gd auto-cycles Idle/Idle_blink from here.
	_reading_kalulu.play(&"Idle")
	_click_catcher.show()

#endregion

#region Music

# Starts the endgame track from the top, at full volume whatever the previous run left
# behind. The ambient garden track is stopped instead of being mixed underneath: both go
# through the Music bus, and two tracks at once turn the celebration into noise.
func _start_music() -> void:
	_kill_music_fade()
	(MusicManager as MusicManagerClass).stop()
	_music_player.volume_linear = MUSIC_FULL_VOLUME
	_music_player.play()


# Lets the music bow out under the closing moves rather than cut on the click. A track
# that already ran to its end needs no fade, and either way the ambient garden track only
# comes back once the endgame one is silent.
func _fade_out_music() -> void:
	_kill_music_fade()
	if not _music_player.playing:
		_restore_ambient_music()
		return
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music_player, "volume_linear", 0.0, MUSIC_FADE_OUT_DURATION)
	_music_fade_tween.tween_callback(_music_player.stop)
	_music_fade_tween.tween_callback(_restore_ambient_music)


# A replay can be started while the previous fade is still running — _is_playing clears
# before the 1.39 s are up — so the tween has to be dropped before it stops a track that
# is no longer the one it was fading.
func _kill_music_fade() -> void:
	if _music_fade_tween:
		_music_fade_tween.kill()
		_music_fade_tween = null


func _restore_ambient_music() -> void:
	(MusicManager as MusicManagerClass).play((MusicManager as MusicManagerClass).Track.GARDEN)

#endregion

#region Dismiss & restore

func _on_click_catcher_pressed() -> void:
	_click_catcher.hide()
	# Not awaited: the fade runs under the Hide animation and the brain being restored.
	_fade_out_music()
	await _hide_kalulu()
	await _restore_brain()
	_is_playing = false


func _hide_kalulu() -> void:
	if not _reading_kalulu:
		return
	_reading_kalulu.play(&"Hide")
	await _reading_kalulu.animation_finished
	_reading_kalulu.hide()
	# Freed rather than kept for a replay the player may never ask for. play()
	# starts the background load again if they do.
	_reading_kalulu.queue_free()
	_reading_kalulu = null


func _restore_brain() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_brain_map, "modulate:a", 1.0, RESTORE_DURATION)
	if _brain_material:
		tween.tween_property(_brain_material, "shader_parameter/mix_amount", 0.0, RESTORE_DURATION)
	for garden: Garden in _gardens:
		for material: ShaderMaterial in garden.get_recolor_materials():
			tween.tween_property(material, "shader_parameter/mix_amount", 0.0, RESTORE_DURATION)
	await tween.finished
	# Detach the materials so the authored look is pixel-exact again.
	_brain_map.material = null
	_brain_material = null
	for garden: Garden in _gardens:
		garden.clear_recolor()
	_ui_layer.show()

#endregion

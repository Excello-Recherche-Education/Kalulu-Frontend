extends Control
## Kalulu coming over to explain something, in a minigame, a garden or a menu.
##
## His spritesheet is 3600x4801 -- about 69 MB of texture -- and this scene sits in
## every screen that can call him: all eleven minigames through minigame_ui, plus
## the gardens, the brain and the sign-in screen. On a device running light graphics
## that is far too much to hold for a character most children never tap, so there he
## is fetched on the first speech instead and kept from then on. A device drawing the
## full artwork still gets him at load, as before, so nothing pauses mid-game.
##
## Either way the scene does not name him -- see HeavyGraphics for why that is the
## part that matters.

signal speech_ended()

const SHOW_SOUND: AudioStreamMP3 = preload("res://assets/kalulu/audio/ui_button_on.mp3")
const HIDE_SOUND: AudioStreamMP3 = preload("res://assets/kalulu/audio/ui_button_off.mp3")
const KALULU_ANIMATOR_SCENE_PATH: String = "res://sources/kalulu_animator.tscn"

## Kalulu himself, once he has been fetched.
var kalulu_sprite: AnimatedSprite2D = null

@onready var kalulu_sprite_slot: Node2D = $KaluluSprite
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	hide()
	if HeavyGraphics.enabled():
		_fetch_kalulu()


## Brings Kalulu in, once. Cheap to call again.
func _fetch_kalulu() -> void:
	if kalulu_sprite:
		return
	var scene: PackedScene = load(KALULU_ANIMATOR_SCENE_PATH) as PackedScene
	if not scene:
		Log.error("Kalulu: Cannot load %s" % KALULU_ANIMATOR_SCENE_PATH)
		return
	kalulu_sprite = scene.instantiate()
	kalulu_sprite_slot.add_child(kalulu_sprite)
	# Behind the pass button, which is the slot's other child and has to stay on top.
	kalulu_sprite_slot.move_child(kalulu_sprite, 0)


func play_kalulu_speech(speech: AudioStream, show_animation: bool = true, hide_animation: bool = true) -> void:
	# The first tap on a light device is where Kalulu is actually paid for.
	_fetch_kalulu()
	if not kalulu_sprite:
		Log.error("Kalulu: Cannot speak without a sprite")
		speech_ended.emit()
		return
	var ind: int = AudioServer.get_bus_index("Music")
	var music_volume: float = AudioServer.get_bus_volume_db(ind)
	AudioServer.set_bus_volume_db(ind, -80.0)
	if show_animation:
		show()
		
		audio_player.stream = SHOW_SOUND
		audio_player.play()
		
		kalulu_sprite.play("Show")
		await kalulu_sprite.animation_finished
	
	if speech:
		kalulu_sprite.play("Talk")
		audio_player.stream = speech
		audio_player.play()
		await audio_player.finished
	else:
		Log.warn("Kalulu: Speech not found")
	
	if hide_animation:
		audio_player.stream = HIDE_SOUND
		audio_player.play()
		
		kalulu_sprite.play("Hide")
		await kalulu_sprite.animation_finished
		hide()
	
	AudioServer.set_bus_volume_db(ind, music_volume)
	speech_ended.emit()


func _on_pass_button_pressed() -> void:
	if audio_player.playing:
		audio_player.stop()
		audio_player.finished.emit()

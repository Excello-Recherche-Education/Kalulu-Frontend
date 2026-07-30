extends Control
## Kalulu greets the user, then hands over to the welcome or access-code screen.
##
## The second of the two welcoming pages. It only ever appears when the greeting
## speech is available -- EntryFlow skips straight past it otherwise -- so there
## is no silent-screen case to handle here.
##
## Tapping anywhere skips ahead, the same affordance the old main menu had: its
## "Play" button was a fully transparent control covering the whole screen.

var is_leaving: bool = false

@onready var speech_player: AudioStreamPlayer = %SpeechPlayer
@onready var sprite: AnimatedSprite2D = %Sprite
@onready var continue_button: Button = %ContinueButton
@onready var wordmark: Panel = %Wordmark
@onready var title: TextureRect = %Title


func _ready() -> void:
	Log.info("KaluluGreeting: Loaded")
	# The wordmark asset is white on transparent, for the old title screen where
	# it sat straight on the night sky. The redesign sets it in navy inside a
	# white pill, which needs no new artwork: tint the glyphs and put a rounded
	# panel behind them.
	var pill: StyleBoxFlat = MenuTheme.flat_stylebox(Color.WHITE, int(wordmark.size.y / 2.0))
	wordmark.add_theme_stylebox_override("panel", pill)
	title.modulate = Design.NAVY
	continue_button.pressed.connect(_leave)
	OpeningCurtain.open()
	await _speak()
	_leave()


func _speak() -> void:
	var speech: AudioStream = Database.load_external_sound(EntryFlow.greeting_speech_path())
	if not speech:
		# EntryFlow checked the file was there, so reaching this means it is
		# unreadable rather than absent. Nothing to wait for; move on.
		Log.warn("KaluluGreeting: Greeting speech could not be loaded")
		return
	sprite.play("Talk")
	speech_player.stream = speech
	speech_player.play()
	await speech_player.finished
	sprite.play("Idle")


func _leave() -> void:
	# The speech finishing and a tap race each other, and both lead here.
	if is_leaving:
		return
	is_leaving = true
	speech_player.stop()
	var next: String = EntryFlow.scene_after_greeting()
	Log.info("KaluluGreeting: Continuing to %s" % next)
	await OpeningCurtain.close()
	var error: Error = get_tree().change_scene_to_file(next)
	if error != OK:
		Log.error(error_string(error))
		is_leaving = false

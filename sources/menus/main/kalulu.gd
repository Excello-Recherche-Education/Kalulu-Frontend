extends Control

@onready var speech_player : AudioStreamPlayer = $SpeechPlayer
@onready var sprite: AnimatedSprite2D = $Sprite

var tuto_speech :AudioStreamMP3
var feedback_speech :AudioStreamMP3

var isSpeaking : bool = false :
	set(value):
		isSpeaking = value
		elapsedTime = 0
		if isSpeaking:
			sprite.play("Tc_Talk1")
		else:
			sprite.play("Tc_Idle1")
var elapsedTime : float = 0.0


func _ready() -> void:
	tuto_speech = Database.load_external_sound(Database.get_kalulu_speech_path("title_screen", "tuto_welcome_oneshot"))
	feedback_speech = Database.load_external_sound(Database.get_kalulu_speech_path("title_screen", "feedback_welcome"))
	_play_speech(tuto_speech)


func _process(delta: float) -> void:
	if not visible:
		return
	
	if not sprite.is_playing():
		sprite.play("Tc_Idle1")
	
	if not isSpeaking:
		elapsedTime += delta
	if elapsedTime > 20:
		start_speech()

func _play_speech(speech : AudioStream) -> void:
	if not speech:
		Logger.warn("Kalulu: Speech not found")
		isSpeaking = false
		return
	
	isSpeaking = true
	
	speech_player.stream = speech
	speech_player.play()
	await speech_player.finished
	
	isSpeaking = false


func start_speech() -> void:
	_play_speech(feedback_speech)


func stop_speech() -> void:
	sprite.stop()
	speech_player.stop()
	isSpeaking = false

extends Control

@onready var speech_player : AudioStreamPlayer = $SpeechPlayer
@onready var sprite: = $Sprite

const tuto_speech_path : String = "main_menu/audio/title_screen_tuto_welcome_oneshot.mp3"
const feedback_speech_path :String = "main_menu/audio/title_screen_feedback_welcome.mp3"

var isSpeaking : bool = false :
	set(value):
		isSpeaking = value
		elapsedTime = 0
var elapsedTime : float = 0.0


func _ready():
	_play_speech(Database.get_audio_stream_for_path(tuto_speech_path))


func _process(delta):
	if not visible:
		return
	
	if not isSpeaking:
		elapsedTime += delta
	if elapsedTime > 20:
		start_speech()

func _play_speech(speech : AudioStream):
	isSpeaking = true
	
	sprite.play("Tc_Talk1")
	speech_player.stream = speech
	speech_player.play()
	
	await speech_player.finished
	
	sprite.play("Tc_Idle1")
	
	isSpeaking = false


func start_speech():
	_play_speech(Database.get_audio_stream_for_path(feedback_speech_path))


func stop_speech():
	sprite.stop()
	speech_player.stop()
	isSpeaking = false

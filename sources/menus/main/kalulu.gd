extends Control

@onready var speech_player : AudioStreamPlayer = $SpeechPlayer
@onready var sprite: = $Sprite

var tuto_speech_path : String = "main_menu/audio/title_screen_tuto_welcome_oneshot.mp3"
var feedback_speech :String = "main_menu/audio/title_screen_feedback_welcome.mp3"

var isSpeaking : bool = false
var elapsedTime : float = 0.0

func _ready():
	# TODO Revoir quel speech lancer au démarrage
	_play_speech(Database.get_audio_stream_for_path(tuto_speech_path))


func _process(delta):
	if not isSpeaking:
		elapsedTime += delta
	if elapsedTime > 20:
		_play_speech(Database.get_audio_stream_for_path(feedback_speech))
		elapsedTime = 0.0


func _play_speech(speech : AudioStream):
	isSpeaking = true
	
	sprite.play("Tc_Talk1")
	speech_player.stream = speech
	speech_player.play()
	
	await speech_player.finished
	
	sprite.play("Tc_Idle1")
	
	isSpeaking = false

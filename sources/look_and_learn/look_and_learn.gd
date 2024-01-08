extends Control

@export var current_button_pressed: = 0

@onready var animation_player: = $AnimationPlayer
@onready var audio_player: = $AudioStreamPlayer
@onready var video_player: = %VideoStreamPlayer
@onready var image: = %Image
@onready var grapheme_label: = %GraphemeLabel
@onready var tracing_manager: = %TracingManager
@onready var grapheme_particles: = $GraphemeParticles

var current_grapheme: = "a"

var current_video: = 0
var videos: = []

var current_image_and_sound: = 0
var images: = []
var sounds: = []


func _ready() -> void:
	setup()


func setup() -> void:
	grapheme_label.text = current_grapheme.to_lower() + " " + current_grapheme.to_upper()
	grapheme_particles.emitting = true
	
	videos = []
	Database.db.query("Select VideoPath FROM GPsVideosPaths INNER JOIN GPs WHERE GPs.Grapheme = '" + current_grapheme + "'")
	for r in Database.db.query_result:
		videos.append(load(r["VideoPath"]))
	
	images = []
	sounds = []
	Database.db.query("Select ImagePath, SoundPath FROM GPsImagesAndSoundsPaths INNER JOIN GPs WHERE GPs.Grapheme = '" + current_grapheme + "'")
	for r in Database.db.query_result:
		images.append(load(r["ImagePath"]))
		sounds.append(load(r["SoundPath"]))


func play_videos() -> void:
	if current_video >= videos.size():
		animation_player.play("end_videos")
	else:
		video_player.stream = videos[current_video]
		video_player.play()
		
		current_video += 1


func play_images_and_sounds()  -> void:
	if current_image_and_sound >= images.size() or current_image_and_sound >= sounds.size():
		animation_player.play("end_images_and_sounds")
	else:
		image.texture = images[current_image_and_sound]
		audio_player.stream = sounds[current_image_and_sound]
		audio_player.play() 
		
		current_image_and_sound += 1


func load_tracing() -> void:
	tracing_manager.setup(current_grapheme)


func play_tracing() -> void:
	tracing_manager.start()


func _on_grapheme_button_pressed() -> void:
	match current_button_pressed:
		0:
			animation_player.play("to_videos")
			current_button_pressed += 1
		1:
			animation_player.play("to_images_and_sounds")
			current_button_pressed += 1
		2:
			animation_player.play("to_tracing")
			current_button_pressed += 1


func _on_video_stream_player_finished() -> void:
	play_videos()


func _on_audio_stream_player_finished() -> void:
	play_images_and_sounds()


func _on_tracing_manager_finished() -> void:
	animation_player.play("end_tracing")

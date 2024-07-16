extends Control

@export var lesson_nb: = 1
@export var current_button_pressed: = 0

@onready var animation_player: = $AnimationPlayer
@onready var audio_player: = $AudioStreamPlayer
@onready var video_player: = %VideoStreamPlayer
@onready var image: = %Image
@onready var grapheme_label: = %GraphemeLabel
@onready var tracing_manager: = %TracingManager
@onready var grapheme_particles: = $GraphemeParticles

const Gardens: = preload("res://sources/gardens/gardens.gd")
const resource_folder: = "res://language_resources/"
const language_folder: = "french/"
const image_folder: = "look_and_learn/images/"
const sound_folder: = "look_and_learn/sounds/"
const video_folder: = "look_and_learn/video/"
const video_extension: = ".ogv"
const image_extension: = ".png"
const sound_extension: = ".mp3"

var gp_list: Array[Dictionary]

var current_video: = 0
var videos: = []

var current_image_and_sound: = 0
var images: = []
var sounds: = []

static var transition_data: Dictionary
var gardens_data: Dictionary


var current_tracing: = 0


func _ready() -> void:
	MusicManager.stop()
	
	gardens_data = transition_data
	transition_data = {}
	lesson_nb = gardens_data.get("current_lesson_number", lesson_nb)
	setup()
	OpeningCurtain.open()


func setup() -> void:
	gp_list = Database.get_GP_for_lesson(lesson_nb, true, true)
	
	current_video = 0
	current_image_and_sound = 0
	current_tracing = 0
	
	images = []
	sounds = []
	videos = []
	
	var gp_display: = []
	for gp in gp_list:
		var gp_image: = Database.get_gp_look_and_learn_image(gp)
		var gp_sound: = Database.get_gp_look_and_learn_sound(gp)
		var gp_video: = Database.get_gp_look_and_learn_video(gp)
		
		if gp_image and gp_sound and gp_video:
			images.append(gp_image)
			sounds.append(gp_sound)
			videos.append(gp_video)
			
			gp_display.append(gp)
	
	if gp_display.is_empty():
		gp_display.append(gp_list[0])
	
	grapheme_label.text = ""
	for gp in gp_display:
		grapheme_label.text += "%s" % gp.Grapheme


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
	await tracing_manager.setup(gp_list[current_tracing]["Grapheme"])
	current_tracing += 1


func play_tracing() -> void:
	tracing_manager.start()


func _on_grapheme_button_pressed() -> void:
	var loop: = true
	while loop:
		match current_button_pressed:
			0:
				if images.is_empty() or sounds.is_empty():
					current_button_pressed += 1
				else:
					animation_player.play("to_videos")
					current_button_pressed += 1
					loop = false
			1:
				if videos.is_empty():
					current_button_pressed += 1
				else:
					animation_player.play("to_images_and_sounds")
					current_button_pressed += 1
					loop = false
			2:
				animation_player.play("to_tracing")
				current_button_pressed += 1
				loop = false


func _on_video_stream_player_finished() -> void:
	play_videos()


func _on_audio_stream_player_finished() -> void:
	play_images_and_sounds()


func _on_tracing_manager_finished() -> void:
	if current_tracing < gp_list.size():
		await tracing_manager.setup(gp_list[current_tracing]["Grapheme"])
		tracing_manager.start()
		current_tracing += 1
	else:
		UserDataManager.student_progression.look_and_learn_completed(lesson_nb)
		animation_player.play("end_tracing")
		await animation_player.animation_finished
		
		_back_to_gardens()



func _back_to_gardens() -> void:
	await OpeningCurtain.close()
	
	Gardens.transition_data = gardens_data
	get_tree().change_scene_to_file("res://sources/gardens/gardens.tscn")


func _on_garden_button_pressed() -> void:
	_back_to_gardens()

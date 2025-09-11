extends Control
class_name LookAndLearn

@export var lesson_nb: int = 1
@export var current_button_pressed: int = 0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var video_player: VideoStreamPlayer = %VideoStreamPlayer
@onready var image: TextureRect = %Image
@onready var grapheme_label: Label = %GraphemeLabel
@onready var tracing_manager: TracingManager = %TracingManager
@onready var grapheme_particles: GPUParticles2D = $GraphemeParticles


var gp_list: Array[Dictionary] = []
var current_video: int = 0
var videos: Array[VideoStream] = []

var current_image_and_sound: int = 0
var images: Array[Texture] = []
var sounds: Array[AudioStream] = []

static var transition_data: Dictionary = {}
var gardens_data: Dictionary = {}


var current_tracing: int = 0


func _ready() -> void:
	MusicManager.stop()
	
	gardens_data = transition_data
	transition_data = {}
	lesson_nb = gardens_data.get("current_lesson_number", lesson_nb)
	Logger.trace("LookAndLearn: Starting lesson %d" % lesson_nb)
	setup()
	await OpeningCurtain.open()


func setup() -> void:
	gp_list = Database.get_gps_for_lesson(lesson_nb, true, true)
	
	if gp_list.size() <= 0:
		Logger.error("LookAndLearn: setup() did not found any GP for lesson " + str(lesson_nb))
		await OpeningCurtain.open()
		_on_tracing_manager_finished()
		return
	
	current_video = 0
	current_image_and_sound = 0
	current_tracing = 0
	
	images = []
	sounds = []
	videos = []
	
	var gp_display: PackedStringArray = PackedStringArray()
	for gp: Dictionary in gp_list:
		var gp_image: Texture = Database.get_gp_look_and_learn_image(gp)
		var gp_sound: AudioStream = Database.get_gp_look_and_learn_sound(gp)
		var gp_video: VideoStream = Database.get_gp_look_and_learn_video(gp)
		
		if gp_video:
			videos.append(gp_video)
		
		if gp_image and gp_sound:
			images.append(gp_image)
			sounds.append(gp_sound)
		
		var tracing_data: Dictionary = tracing_manager._get_letter_tracings(gp.Grapheme as String)
		if tracing_data.upper:
			gp_display.append((gp.Grapheme as String).to_upper())
		if tracing_data.lower:
			gp_display.append((gp.Grapheme as String).to_lower())
	
	if gp_display.is_empty():
		gp_display.append(gp_list[0].Grapheme as String)
	
	grapheme_label.text = " ".join(gp_display)


func play_videos() -> void:
	if current_video >= videos.size():
		animation_player.play("end_videos")
	else:
		video_player.stream = videos[current_video]
		video_player.play()
		
		current_video += 1


func play_images_and_sounds() -> void:
	if current_image_and_sound >= images.size() or current_image_and_sound >= sounds.size():
		animation_player.play("end_images_and_sounds")
	else:
		image.texture = images[current_image_and_sound]
		audio_player.stream = sounds[current_image_and_sound]
		audio_player.play() 
		
		current_image_and_sound += 1


func load_tracing() -> void:
	await tracing_manager.setup(gp_list[current_tracing]["Grapheme"] as String)
	current_tracing += 1


func play_tracing() -> void:
	tracing_manager.start()


func _on_grapheme_button_pressed() -> void:
	var loop: bool = true
	while loop:
		match current_button_pressed:
			0:
				current_button_pressed += 1
				if videos.is_empty():
					Logger.warn("LookAndLearn: Skipping video because empty in lesson %d" % lesson_nb)
					continue
				animation_player.play("to_videos")
				loop = false
			1:
				current_button_pressed += 1
				if images.is_empty() or sounds.is_empty():
					Logger.warn("LookAndLearn: Skipping image&sound because empty in lesson %d" % lesson_nb)
					continue
				animation_player.play("to_images_and_sounds")
				loop = false
			2:
				current_button_pressed += 1
				animation_player.play("to_tracing")
				loop = false


func _on_video_stream_player_finished() -> void:
	await get_tree().create_timer(1).timeout
	play_videos()


func _on_audio_stream_player_finished() -> void:
	await get_tree().create_timer(1).timeout
	play_images_and_sounds()


func _on_tracing_manager_finished() -> void:
	if current_tracing < gp_list.size():
		await tracing_manager.setup(gp_list[current_tracing]["Grapheme"] as String)
		tracing_manager.start()
		current_tracing += 1
	else:
		animation_player.play("end_tracing")
		gardens_data.first_clear = UserDataManager.student_progression.look_and_learn_completed(lesson_nb)
		gardens_data.look_and_learn_completed = true
		_back_to_gardens()



func _back_to_gardens() -> void:
	await OpeningCurtain.close()
	
	Gardens.transition_data = gardens_data
	get_tree().change_scene_to_file("res://sources/gardens/gardens.tscn")


func _on_garden_button_pressed() -> void:
	_back_to_gardens()

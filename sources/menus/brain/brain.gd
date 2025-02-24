@tool
extends Control

const Gardens: = preload("res://sources/gardens/gardens.gd")
const gardens_scene: = preload("res://sources/gardens/gardens.tscn")
const Kalulu: = preload("res://sources/minigames/base/kalulu.gd")

@export var locked_color: Color
@export var unlocked_colors: Array[Color]
@export var gardens_layout: GardensLayout

@onready var kalulu: Kalulu = $Kalulu
@onready var kalulu_button: = %KaluluButton
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

@onready var garden_buttons: Array[TextureButton] = [
	%GardenButton1,
	%GardenButton2,
	%GardenButton3,
	%GardenButton4,
	%GardenButton5,
	%GardenButton6,
	%GardenButton7,
	%GardenButton8,
	%GardenButton9,
	%GardenButton10,
	%GardenButton11,
	%GardenButton12,
	%GardenButton13,
	%GardenButton14,
	%GardenButton15,
	%GardenButton16,
	%GardenButton17,
	%GardenButton18,
	%GardenButton19,
	%GardenButton20,
]

@onready var particles: Array[GPUParticles2D] = [
	%Particles1,
	%Particles2,
	%Particles3,
	%Particles4,
	%Particles5,
	%Particles6,
	%Particles7,
	%Particles8,
	%Particles9,
	%Particles10,
	%Particles11,
	%Particles12,
	%Particles13,
	%Particles14,
	%Particles15,
	%Particles16,
	%Particles17,
	%Particles18,
	%Particles19,
	%Particles20,
]

@onready var tutorial_speeches: Array[AudioStream]= [
	Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "intro_1")),
	Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "intro_2")),
	Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "intro_3"))
]

@onready var help_speech: AudioStream = Database.load_external_sound(Database.get_kalulu_speech_path("brain_screen", "help"))

func _ready() -> void:
	for i in range(garden_buttons.size()):
		garden_buttons[i].pressed.connect(_on_garden_button_pressed.bind(i))
	
	var lesson_ind: = 1
	for i in range(gardens_layout.gardens.size()):
		var can_emit: = true
		if UserDataManager.student_progression.unlocks.has(lesson_ind) and UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] != UserProgression.Status.Locked:
			garden_buttons[i].disabled = false
			garden_buttons[i].self_modulate = unlocked_colors[i]
		else:
			garden_buttons[i].disabled = true
			garden_buttons[i].self_modulate = locked_color
			can_emit = false
		
		var emitting: = false
		for _j in range(gardens_layout.gardens[i].lesson_buttons.size()):
			if can_emit and not emitting:
				emitting = false
				for game: UserProgression.Status in UserDataManager.student_progression.unlocks[lesson_ind]["games"]:
					if game == UserProgression.Status.Unlocked or game == UserProgression.Status.Locked:
						emitting = true
						break
			lesson_ind += 1
		
		particles[i].emitting = emitting
		
		
	await OpeningCurtain.open()
	
	if not UserDataManager.is_speech_played("brain"):
		_play_tutorial()

func _play_tutorial() -> void:
	var tutorial_count: = 0
	
	kalulu_button.hide()
	while tutorial_count < tutorial_speeches.size():
		await kalulu.play_kalulu_speech(tutorial_speeches[tutorial_count])
		tutorial_count += 1
	
	UserDataManager.mark_speech_as_played("brain")
	
	kalulu_button.show()


func _on_garden_button_pressed(button_number: int) -> void:
	audio_stream_player.play()
	await OpeningCurtain.close()
	
	var gardens: Gardens = gardens_scene.instantiate()
	gardens.starting_garden = button_number
	get_tree().root.add_child(gardens)
	get_tree().current_scene = gardens
	queue_free()


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	UserDataManager.logout_student()
	get_tree().change_scene_to_file("res://sources/menus/login/login.tscn")


func _on_kalulu_button_pressed() -> void:
	kalulu_button.hide()
	await kalulu.play_kalulu_speech(help_speech)
	kalulu_button.show()

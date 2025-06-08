@tool
extends Control

const GARDENS_SCENE: PackedScene = preload("res://sources/gardens/gardens.tscn")
const Kalulu: = preload("res://sources/minigames/base/kalulu.gd")

@export var locked_color: Color
@export var unlocked_colors: Array[Color] = []
@export var gardens_layout: GardensLayout

@onready var kalulu: Kalulu = $Kalulu
@onready var kalulu_button: TextureButton = %KaluluButton
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
	UserDataManager.start_synchronization_timer()
	
	for index: int in range(garden_buttons.size()):
		garden_buttons[index].pressed.connect(_on_garden_button_pressed.bind(index))
	
	var lesson_ind: int = 1
	for index: int in range(gardens_layout.gardens.size()):
		var can_emit: bool = true
		if UserDataManager.student_progression.unlocks.has(lesson_ind) and UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] != StudentProgression.Status.Locked:
			garden_buttons[index].disabled = false
			garden_buttons[index].self_modulate = unlocked_colors[index]
		else:
			garden_buttons[index].disabled = true
			garden_buttons[index].self_modulate = locked_color
			can_emit = false
		
		var emitting: bool = false
		for _index2: int in range(gardens_layout.gardens[index].lesson_buttons.size()):
			if can_emit and not emitting:
				emitting = false
				for game: StudentProgression.Status in UserDataManager.student_progression.unlocks[lesson_ind]["games"]:
					if game == StudentProgression.Status.Unlocked or game == StudentProgression.Status.Locked:
						emitting = true
						break
			lesson_ind += 1
		
		particles[index].emitting = emitting
		
		
	await OpeningCurtain.open()
	
	if not UserDataManager.is_speech_played("brain"):
		_play_tutorial()


func _play_tutorial() -> void:
	var tutorial_count: int = 0
	
	kalulu_button.hide()
	while tutorial_count < tutorial_speeches.size():
		if tutorial_count == 0: # first speech : play "show"
			await kalulu.play_kalulu_speech(tutorial_speeches[tutorial_count], true, false)
		elif tutorial_count + 1 < tutorial_speeches.size():
			await kalulu.play_kalulu_speech(tutorial_speeches[tutorial_count], false, false)
		else: # last speech : play "hide"
			await kalulu.play_kalulu_speech(tutorial_speeches[tutorial_count], false, true)
		tutorial_count += 1
		await get_tree().create_timer(0.5).timeout
	
	UserDataManager.mark_speech_as_played("brain")
	
	kalulu_button.show()


func _on_garden_button_pressed(button_number: int) -> void:
	audio_stream_player.play()
	await OpeningCurtain.close()
	
	var gardens: Gardens = GARDENS_SCENE.instantiate()
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

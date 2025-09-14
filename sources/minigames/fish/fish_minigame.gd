@tool
extends Minigame

signal beacon_fish_dropped(is_answered_real: bool)

const FISH_TEXTURE_RECT_SCENE: PackedScene = preload("res://sources/minigames/fish/fish_texture_rect.tscn")

@export var game_duration: int = 4 * 60
@export var minimum_correct_ratio: float = 0.8
@export var winning_color: Color = Color.WHITE
@export var max_words_count: int = 15

var tween: Tween
var words_to_present: Array[String] = []
var words_to_present_next: Array[String] = []
var progress_gauge_max_margin: float = 0.95
var total_number_of_words: int = 30
var tutorial_count: int = 0

@onready var fish_start_zone: Control = %FishStartZone
@onready var beacon1: SpriteControl = %Beacon1
@onready var beacon2: SpriteControl = %Beacon2
@onready var path_follow: PathFollow2D = %PathFollow2D
@onready var label: Label = %Label
@onready var false_wrong_fx: WrongFX = %FalseWrongFX
@onready var false_right_fx: RightFX = %FalseRightFX
@onready var real_wrong_fx: WrongFX = %RealWrongFX
@onready var real_right_fx: RightFX = %RealRightFX
@onready var fish_animated_sprite: AnimatedSprite2D = %FishAnimatedSprite
@onready var progress_gauge: PercentMarginContainer = %ProgressionGaugePercentMarginContainer
@onready var progress_gauge_goal: PercentMarginContainer = %ProgressionGaugeGoalPercentMarginContainer2
@onready var progress_gauge_internal: NinePatchRect = %ProgressionGaugeInternal


func _fish_get_drag_data(_at_position: Vector2) -> Variant:
	var fish_texture_rect: Control = FISH_TEXTURE_RECT_SCENE.instantiate()
	fish_texture_rect.size = Vector2(200, 200)
	set_drag_preview(fish_texture_rect)
	return true


func _ready() -> void:
	super()
	fish_start_zone.set_drag_forwarding(_fish_get_drag_data, Callable(), Callable())
	(beacon1 as Control).set_drag_forwarding(Callable(), _beacon_can_drop_data, _beacon1_drop_data)
	(beacon2 as Control).set_drag_forwarding(Callable(), _beacon_can_drop_data, _beacon2_drop_data)
	minigame_ui.progression_container.hide()
	minigame_ui.progression_gauge.hide()
	label.hide()
	@warning_ignore("UNSAFE_PROPERTY_ACCESS")
	progress_gauge_max_margin = progress_gauge.margin_top_ratio
	
	# Skips the whole tutorial
	if UserDataManager.is_speech_played(Type.keys()[minigame_name] as String):
		tutorial_count = 2


func _find_stimuli_and_distractions() -> void:
	var data_array: Array[Dictionary] = Database.get_pseudowords_for_lesson(lesson_nb)
	if data_array.size() <= 0:
		Logger.error("FishMinigame: Cannot start fish minigame since data is empty for lesson %d" % lesson_nb)
		return
	data_array.shuffle()
	words_to_present.clear()
	words_to_present_next.clear()
	for data: Dictionary in data_array:
		stimuli.append(data.Word)
		distractions.append(data.Pseudoword)
		if stimuli.size() >= max_words_count:
			break
	for word: String in stimuli:
		words_to_present.append(word)
	for word: String in distractions:
		words_to_present.append(word)
	words_to_present.shuffle()
	if tutorial_count == 0:
		words_to_present.erase(stimuli[0])
		words_to_present.erase(distractions[0])
		words_to_present.insert(0, distractions[0])
		words_to_present.insert(0, stimuli[0])
	total_number_of_words = words_to_present.size()
	progress_gauge_goal.margin_top_ratio = (1. - minimum_correct_ratio) * progress_gauge_max_margin


func _start() -> void:
	super()
	tween = create_tween()
	tween.tween_property(path_follow, "progress_ratio", 1, game_duration)
	tween.finished.connect(_on_time_out)
	_present_next_word()


func _present_next_word() -> void:
	if words_to_present.is_empty():
		if words_to_present_next.is_empty():
			_win()
			return
		words_to_present = words_to_present_next
		words_to_present.shuffle()
		words_to_present_next = []
	label.show()
	label.text = words_to_present[0]
	if tutorial_count == 0:
		var speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "intro_test_game_first_word"))
		minigame_ui.play_kalulu_speech(speech)
		await minigame_ui.kalulu_speech_ended


func _on_time_out() -> void:
	if _get_win_ratio() >= minimum_correct_ratio:
		_win()
	else:
		_lose()


func _beacon_can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data


func _beacon1_drop_data(_at_position: Vector2, _data: Variant) -> void:
	fish_animated_sprite.play("left")
	await fish_animated_sprite.animation_finished
	beacon_fish_dropped.emit(false)


func _beacon2_drop_data(_at_position: Vector2, _data: Variant) -> void:
	fish_animated_sprite.play("right")
	await fish_animated_sprite.animation_finished
	beacon_fish_dropped.emit(true)


func _on_beacon_fish_dropped(is_answered_real: bool) -> void:
	var is_really_real: bool = words_to_present[0] in stimuli
	var is_correct: bool = is_answered_real == is_really_real
	if is_correct:
		if is_answered_real:
			real_right_fx.play()
		else:
			false_right_fx.play()
		words_to_present.pop_front()
		if tutorial_count == 0:
			var speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "win_test_game_first_word"))
			minigame_ui.play_kalulu_speech(speech)
			await minigame_ui.kalulu_speech_ended
			tutorial_count += 1
		elif tutorial_count == 1:
			var speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "win_test_game_second_word"))
			minigame_ui.play_kalulu_speech(speech)
			await minigame_ui.kalulu_speech_ended
			tutorial_count += 1
	else:
		if is_answered_real:
			real_wrong_fx.play()
		else:
			false_wrong_fx.play()
		words_to_present_next.append(words_to_present.pop_front())
		if tutorial_count == 0:
			var speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "lose_test_game_first_word"))
			minigame_ui.play_kalulu_speech(speech)
			await minigame_ui.kalulu_speech_ended
			tutorial_count += 1
		elif tutorial_count == 1:
			var speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "lose_test_game_second_word"))
			minigame_ui.play_kalulu_speech(speech)
			await minigame_ui.kalulu_speech_ended
			tutorial_count += 1
	_update_progression_gauge()
	_present_next_word()


func _update_progression_gauge() -> void:
	progress_gauge.margin_top_ratio = progress_gauge_max_margin - progress_gauge_max_margin / total_number_of_words * (total_number_of_words - words_to_present.size() - words_to_present_next.size())
	if _get_win_ratio() >= minimum_correct_ratio:
		progress_gauge_internal.modulate = winning_color


func _get_win_ratio() -> float:
	return 1. - float(words_to_present.size() + words_to_present_next.size()) / total_number_of_words


func _on_fish_animated_sprite_animation_finished() -> void:
	fish_animated_sprite.play("idle")

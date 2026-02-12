extends Minigame

const FINAL_BOSS_GAME_DURATION: int = 20 * 60
const FINAL_BOSS_TOTAL_WORDS: int = 180

@export var game_duration: int = 4 * 60
@export var minimum_correct_ratio: float = 0.8
@export var winning_color: Color = Color.WHITE
@export var max_words_count: int = 15

var sun_tween: Tween
var words_to_present: Array[String] = []
var words_to_present_next: Array[String] = []
var progress_gauge_max_margin: float = 0.95
var total_number_of_words: int = 30
var tutorial_count: int = 0
var _boss_session_index: int = -1
var _boss_answer_start_ms: int = 0
var default_label_settings: LabelSettings
var default_label_background_color: Color
var _correct_answer_tween: Tween

@onready var text_start_zone: Control = %ControlText
@onready var texture_button_bin: TextureButton = $GameRoot/TextureButtonBin
@onready var texture_button_book: TextureButton = $GameRoot/TextureButtonBook
@onready var path_follow: PathFollow2D = %PathFollow2D
@onready var texture_rect_text_box: TextureRect = %TextureRectTextBox
@onready var label: Label = %Label
@onready var progress_gauge: PercentMarginContainer = %ProgressionGaugePercentMarginContainer
@onready var progress_gauge_goal: PercentMarginContainer = %ProgressionGaugeGoalPercentMarginContainer2
@onready var progress_gauge_internal: NinePatchRect = %ProgressionGaugeInternal
@onready var adult_block: AdultBlock = %AdultBlock
@onready var kalulu_boss: KaluluBoss = %KaluluBoss
@onready var wrong_fx: WrongFX = %WrongFX
@onready var right_stars: RightStarsFX = $GameRoot/Right_Stars
@onready var frame_exit: Sprite2D = $GameRoot/Frame/FrameExit
@onready var turtle: Turtle = $GameRoot/Friends/Turtle
@onready var frog: Frog = $GameRoot/Friends/Frog
@onready var crab: Crab = $GameRoot/Friends/Crab
@onready var penguin: Penguin = $GameRoot/Friends/Penguin
@onready var monkey: Monkey = $GameRoot/Friends/Monkey
@onready var parakeet: Parakeet = $GameRoot/Friends/Parakeet
@onready var ant: Ant = $GameRoot/Friends/Ant
@onready var jellyfish: Jellyfish = $GameRoot/Friends_Behind_Frame/Jellyfish


func _ready() -> void:
	super()
	if not is_final_boss:
		frame_exit.show()
	setup_animal_friends()
	fireworks.set_colors([Color("#bca4ff"), Color("#f5a8c8"), Color("#ffbf94")])
	if adult_block and adult_block.has_signal("unlocked"):
		adult_block.unlocked.connect(_on_adult_block_unlocked)
	text_start_zone.set_drag_forwarding(_text_get_drag_data, Callable(), Callable())
	(texture_button_bin as Control).set_drag_forwarding(Callable(), _button_can_drop_data, _button_bin_drop_data)
	(texture_button_book as Control).set_drag_forwarding(Callable(), _button_can_drop_data, _button_book_drop_data)
	minigame_ui.progression_container.hide()
	minigame_ui.progression_gauge.hide()
	label.hide()
	@warning_ignore("UNSAFE_PROPERTY_ACCESS")
	progress_gauge_max_margin = progress_gauge.margin_top_ratio
	
	default_label_settings = label.label_settings
	default_label_background_color = texture_rect_text_box.self_modulate
	
	# Skips the whole tutorial
	if UserDataManager.is_speech_played(Type.keys()[minigame_name] as String):
		tutorial_count = 2


func setup_animal_friends() -> void:
	turtle.idle_boss()
	frog.idle_boss()
	crab.idle_boss()
	penguin.idle_boss()
	monkey.idle_boss()
	parakeet.idle_boss()
	ant.idle_boss()
	jellyfish.idle_boss()


func win_with_friends() -> void:
	turtle.victory_boss()
	frog.victory_boss()
	crab.victory_boss()
	penguin.victory_boss()
	monkey.victory_boss()
	parakeet.victory_boss()
	ant.victory_boss()
	jellyfish.victory_boss()


func _text_get_drag_data(_at_position: Vector2) -> Variant:
	var duplicated: Control = text_start_zone.duplicate()
	duplicated.set_scale(Vector2(0.6, 0.6))
	duplicated.set_modulate(Color(1, 1, 1, 0.4))
	set_drag_preview(duplicated)
	return true


func _find_stimuli_and_distractions() -> void:
	var data_array: Array[Dictionary] = Database.get_pseudowords_for_lesson(lesson_nb)
	if data_array.size() <= 0:
		Log.error("BossMinigame: Cannot start boss minigame since data is empty for lesson %d" % lesson_nb)
		return
	data_array.shuffle()
	if is_final_boss:
		max_words_count = data_array.size()
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
	if is_final_boss:
		game_duration = FINAL_BOSS_GAME_DURATION
		total_number_of_words = FINAL_BOSS_TOTAL_WORDS
		_ensure_words_to_present_count(FINAL_BOSS_TOTAL_WORDS)
	progress_gauge_goal.margin_top_ratio = (1. - minimum_correct_ratio) * progress_gauge_max_margin


func _start() -> void:
	super()
	if _is_boss_session() and _boss_session_index == -1:
		_boss_session_index = UserDataManager.start_boss_session(int(Time.get_unix_time_from_system()))
	sun_tween = create_tween()
	sun_tween.tween_property(path_follow, "progress_ratio", 1, game_duration)
	sun_tween.finished.connect(_on_time_out)
	_present_next_word()


func _present_next_word() -> void:
	if words_to_present.is_empty():
		if words_to_present_next.is_empty():
			if _get_win_ratio() >= minimum_correct_ratio:
				_win()
			else:
				_lose()
			return
		words_to_present = words_to_present_next
		words_to_present.shuffle()
		words_to_present_next = []
	label.show()
	label.text = words_to_present[0]
	if _is_boss_session():
		_boss_answer_start_ms = Time.get_ticks_msec()
	if tutorial_count == 0:
		var speech: AudioStreamMP3 = Database.load_external_sound(Database.get_kalulu_speech_path(Type.keys()[minigame_name] as String, "intro_test_game_first_word"))
		minigame_ui.play_kalulu_speech(speech)
		await minigame_ui.kalulu_speech_ended


func _on_time_out() -> void:
	if _get_win_ratio() >= minimum_correct_ratio:
		_win()
	else:
		_lose()


func _button_can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data


func _button_bin_drop_data(_at_position: Vector2, _data: Variant) -> void:
	_on_answer_dropped(false)


func _button_book_drop_data(_at_position: Vector2, _data: Variant) -> void:
	_on_answer_dropped(true)


func _on_texture_button_bin_pressed() -> void:
	_on_answer_dropped(false)


func _on_texture_button_book_pressed() -> void:
	_on_answer_dropped(true)


func _on_answer_dropped(is_answered_real: bool) -> void:
	if words_to_present.size() < 1:
		Log.error("BossMinigame: Cannot process answer because there is no words to present")
		return
	texture_button_bin.set_disabled(true)
	texture_button_book.set_disabled(true)
	var is_really_real: bool = words_to_present[0] in stimuli
	var is_correct: bool = is_answered_real == is_really_real
	var response_log: Dictionary = {"word": words_to_present[0], "is_real_answer": is_answered_real}
	var awaited_response: Dictionary = {"word": words_to_present[0], "is_real_answer": is_really_real}
	_log_new_response(response_log, awaited_response)
	if _is_boss_session() and _boss_session_index >= 0:
		var response_time_ms: int = max(0, Time.get_ticks_msec() - _boss_answer_start_ms)
		UserDataManager.record_boss_answer(
			_boss_session_index,
			is_really_real,
			words_to_present[0].length(),
			response_time_ms,
			is_correct
		)
	if is_correct:
		label.label_settings = label.label_settings.duplicate()
		label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL
		texture_rect_text_box.self_modulate = Minigame.LABEL_COLOR_WIN
		var target_button: Control = texture_button_book if is_answered_real else texture_button_bin
		if is_answered_real:
			right_stars.global_position = texture_button_book.global_position + texture_button_book.get_size() / 2
			right_stars.replay()
		else:
			right_stars.global_position = texture_button_bin.global_position + texture_button_bin.get_size() / 2
			right_stars.replay()
		words_to_present.pop_front()
		await _play_correct_answer_animation(target_button)
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
		label.label_settings = label.label_settings.duplicate()
		label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL
		texture_rect_text_box.self_modulate = Minigame.LABEL_COLOR_LOSE
		if is_answered_real:
			wrong_fx.global_position = texture_button_book.global_position + texture_button_book.get_size() / 2
			wrong_fx.play()
		else:
			wrong_fx.global_position = texture_button_bin.global_position + texture_button_bin.get_size() / 2
			wrong_fx.play()
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
	await get_tree().create_timer(1).timeout
	label.label_settings = default_label_settings
	texture_rect_text_box.self_modulate = default_label_background_color
	texture_button_bin.set_disabled(false)
	texture_button_book.set_disabled(false)
	_update_progression_gauge()
	_present_next_word()
	text_start_zone.show()


func _center_global(control: Control) -> Vector2:
	var rect: Rect2 = control.get_global_rect()
	var scaled_half: Vector2 = (rect.size * control.scale) * 0.5
	return rect.position + scaled_half


func _play_correct_answer_animation(target_button: Control) -> void:
	if not is_instance_valid(text_start_zone) or not is_instance_valid(target_button):
		return

	if _correct_answer_tween and _correct_answer_tween.is_running():
		_correct_answer_tween.kill()

	var duplicated: Control = text_start_zone.duplicate()

	if text_start_zone.is_visible_in_tree():
		text_start_zone.hide()
	else:
		duplicated.show()

	duplicated.name = "CorrectAnswerWord"
	duplicated.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Place duplicated so that its center matches the original center.
	# (We set position after adding as child to ensure layout/size is correct)
	text_start_zone.get_parent().add_child(duplicated)
	duplicated.scale = text_start_zone.scale

	# Force layout to be up-to-date (helps if sizes depend on theme/text)
	duplicated.queue_redraw()
	duplicated.minimum_size_changed.emit()

	var start_center: Vector2 = _center_global(text_start_zone)
	var end_center: Vector2 = _center_global(target_button)

	# Initialize duplicated at start center
	var dup_half: Vector2 = duplicated.size * duplicated.scale * 0.5
	duplicated.global_position = start_center - dup_half

	var arc_height: float = max(200.0, start_center.distance_to(end_center) * 0.5)
	var control_position: Vector2 = (start_center + end_center) * 0.5 + Vector2(0.0, -arc_height)

	_correct_answer_tween = create_tween()
	_correct_answer_tween.tween_method(
		func(progress: float) -> void:
			var new_center: Vector2 = _quadratic_bezier(start_center, control_position, end_center, progress)
			var half: Vector2 = duplicated.size * duplicated.scale * 0.5
			duplicated.global_position = new_center - half
			duplicated.scale = text_start_zone.scale.lerp(Vector2(0.2, 0.2), progress),
		0.0,
		1.0,
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await _correct_answer_tween.finished

	if is_instance_valid(duplicated):
		duplicated.queue_free()


func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, progress: float) -> Vector2:
	var one_minus: float = 1.0 - progress
	return one_minus * one_minus * start + 2.0 * one_minus * progress * control + progress * progress * end


func _update_progression_gauge() -> void:
	progress_gauge.margin_top_ratio = progress_gauge_max_margin - progress_gauge_max_margin / total_number_of_words * (total_number_of_words - words_to_present.size() - words_to_present_next.size())
	if _get_win_ratio() >= minimum_correct_ratio:
		progress_gauge_internal.modulate = winning_color


func _get_win_ratio() -> float:
	return 1. - float(words_to_present.size() + words_to_present_next.size()) / total_number_of_words


func _ensure_words_to_present_count(target_count: int) -> void:
	if words_to_present.is_empty():
		return
	var base_pool: Array[String] = words_to_present.duplicate()
	while words_to_present.size() < target_count:
		base_pool.shuffle()
		words_to_present.append_array(base_pool)
	if words_to_present.size() > target_count:
		words_to_present.resize(target_count)


func show_adult_block() -> void:
	if adult_block and adult_block.has_method("show_block"):
		adult_block.call("show_block")


func _on_adult_block_unlocked() -> void:
	await _reset()


func _win() -> void:
	if _is_boss_session() and _boss_session_index >= 0:
		UserDataManager.finish_boss_session(_boss_session_index, true)
	win_with_friends()
	await kalulu_boss.happy()
	await super()


func _lose() -> void:
	if _is_boss_session() and _boss_session_index >= 0:
		UserDataManager.finish_boss_session(_boss_session_index, false)
	await kalulu_boss.sad()
	await super()


func _is_boss_session() -> bool:
	return is_final_boss or gardens_data.has("boss_gate_lesson")

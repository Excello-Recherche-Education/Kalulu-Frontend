extends Minigame

signal beacon_fish_dropped(is_answered_real: bool)

const fish_texture_rect_scene: = preload("res://sources/minigames/fish/fish_texture_rect.tscn")

@onready var fish_start_zone: = %FishStartZone
@onready var beacon1: = %Beacon1
@onready var beacon2: = %Beacon2
@onready var path_follow: = %PathFollow2D
@onready var label: = %Label
@onready var false_wrong_fx: = %FalseWrongFX
@onready var false_right_fx: = %FalseRightFX
@onready var real_wrong_fx: = %RealWrongFX
@onready var real_right_fx: = %RealRightFX
@onready var fish_animated_sprite: = %FishAnimatedSprite

@export var game_duration: = 4 * 60

var tween: Tween
var words_to_present: Array[String] = []
var words_to_present_next: Array[String] = []


func _fish_get_drag_data(_at_position: Vector2) -> Variant:
	var fish_texture_rect: Control = fish_texture_rect_scene.instantiate()
	fish_texture_rect.size = Vector2(200, 200)
	set_drag_preview(fish_texture_rect)
	return true


func _ready() -> void:
	super()
	fish_start_zone.set_drag_forwarding(_fish_get_drag_data, Callable(), Callable())
	beacon1.set_drag_forwarding(Callable(), _beacon_can_drop_data, _beacon1_drop_data)
	beacon2.set_drag_forwarding(Callable(), _beacon_can_drop_data, _beacon2_drop_data)
	minigame_ui.lives_container.hide()
	minigame_ui.progression_container.hide()
	minigame_ui.progression_gauge.hide()
	label.hide()


func _find_stimuli_and_distractions() -> void:
	stimuli = [
		"il",
		"ma",
		"mal",
		"lama",
		"lasso",
		"va",
		"ri",
		"vol",
		"sur",
		"allé",
		"vélo",
		"roulé",
		"amour",
		"né",
		"un",
		"une",
		"rat",
		"lame",
		"sale",
		"olive",
		"ville",
		"je",
		"le",
		"fée",
		"sol",
		"fort",
		"joli",
		"niche"
	]
	distractions = [
		"ul",
		"um",
		"lum",
		"muma",
		"slaso",
		"oa",
		"ir",
		"vul",
		"sru",
		"léli",
		"lévu",
		"louré",
		"aroum",
		"én",
		"na",
		"enu",
		"tra",
		"mila",
		"esla",
		"olvie",
		"vlile",
		"uj",
		"ul",
		"ifé",
		"slo",
		"trof",
		"lijo",
		"chani"
	]
	words_to_present.clear()
	words_to_present_next.clear()
	for word: String in stimuli:
		words_to_present.append(word)
	for word: String in distractions:
		words_to_present.append(word)
	words_to_present.shuffle()


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


func _on_time_out() -> void:
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
	var is_really_real: = words_to_present[0] in stimuli
	var is_correct: = is_answered_real == is_really_real
	if is_correct:
		if is_answered_real:
			real_right_fx.play()
		else:
			false_right_fx.play()
		words_to_present.pop_front()
	else:
		if is_answered_real:
			real_wrong_fx.play()
		else:
			false_wrong_fx.play()
		words_to_present_next.append(words_to_present.pop_front())


func _on_fish_animated_sprite_animation_finished() -> void:
	fish_animated_sprite.play("idle")

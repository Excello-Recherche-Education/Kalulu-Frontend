@tool
extends Minigame

const Monkey: = preload("res://sources/minigames/monkeys/monkey.gd")

const difficulty_settings: = {
	0 : {"distractors_count": 1},
	1 : {"distractors_count": 2},
	2 : {"distractors_count": 3},
	3 : {"distractors_count": 4},
	4 : {"distractors_count": 5},
}

@export var difficulty: = 1
@export var lesson_nb: = 4
@export var words_count: = 3

@onready var monkeys_node: = $GameRoot/Monkeys
@onready var possible_positions_parent: = $GameRoot/PalmTreeMonkeys
@onready var king: = $GameRoot/PlamTreeKing/KingMonkey
@onready var word_label: = $GameRoot/TextPlank/MarginContainer/Label

var monkeys: Array[Monkey] = []
var _current_letter: = 0: set = _set_current_letter


# Find and set the parameters of the minigame, like the number of lives or the victory conditions.
func _setup_minigame() -> void:
	super._setup_minigame()
	
	var max_difficulty: = 0
	for d in difficulty_settings.keys():
		if d > max_difficulty:
			max_difficulty = d
	
	if difficulty > max_difficulty:
		difficulty = max_difficulty
	
	var settings: Dictionary = difficulty_settings[difficulty]
	
	var possible_positions: = possible_positions_parent.get_children()
	for i in settings.distractors_count + 1:
		var monkey: Monkey = Monkey.instantiate()
		monkeys_node.add_child(monkey)
		monkey.global_position = possible_positions[i].global_position
		monkey.dragged_into.connect(_on_coconut_drag_end)
		monkeys.append(monkey)
	
	# Will set up first word and monkeys
	current_progression = 0
	
	monkeys_node.set_drag_forwarding(Callable(), _monkeys_can_drop_data, _monkeys_drop_data)



func set_current_progression(p_current_progression: int) -> void:
	super(p_current_progression)
	word_label.text = "_".repeat(stimuli[current_progression].Word.length())
	_current_letter = 0


func _set_current_letter(p_current_letter: int) -> void:
	_current_letter = p_current_letter
	var ind_good: = randi_range(0, monkeys.size() - 1)
	var grapheme_distractions: Array = distractions[current_progression][_current_letter]
	grapheme_distractions.shuffle()
	for i in monkeys.size():
		var monkey: = monkeys[i]
		if i == ind_good:
			monkey.stimulus = stimuli[current_progression].GPs[_current_letter]
		elif i < ind_good:
			monkey.stimulus = grapheme_distractions[min(i, grapheme_distractions.size() - 1)]
		else:
			monkey.stimulus = grapheme_distractions[min(i - 1, grapheme_distractions.size() - 1)]


## this is to use the drag and drop feature without its icons
#func _process(delta: float) -> void:
#	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	var words_list: = Database.get_words_for_lesson(lesson_nb)
	words_list.shuffle()
	stimuli = []
	distractions = []
	for i in words_count:
		var word = words_list[i].Word
		var GPs: = Database.get_GP_from_word(word)
		stimuli.append({
			Word = word,
			GPs = GPs,
		})
		var grapheme_distractions: = []
		for GP in GPs:
			grapheme_distractions.append(Database.get_grapheme_distrators_for_grapheme(GP.Grapheme, lesson_nb))
		distractions.append(grapheme_distractions)


func _monkeys_drop_data(at_position: Vector2, data) -> void:
	_on_coconut_drag_end(at_position - data.start_position)


func _monkeys_can_drop_data(_at_position: Vector2, _data) -> bool:
	return true


func _on_coconut_drag_end(vector: Vector2) -> void:
	print(vector.x)

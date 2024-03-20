extends Minigame
class_name HearAndSequentialsStepsMinigame

# TODO Remove when the jellyfish_minigame branch is merged and rebased
@export var difficulty: = 1
@export var lesson_nb: = 4

# Find the stimuli and distractions of the minigame.
func _find_stimuli_and_distractions() -> void:
	var words_list: = Database.get_words_for_lesson(lesson_nb)
	words_list.shuffle()
	print(words_list)
	for i in max_progression:
		var word = words_list[i].Word
		var GPs: = Database.get_GP_from_word(word)
		stimuli.append({
			Word = word,
			GPs = GPs,
		})
		var grapheme_distractions: = []
		for GP in GPs:
			grapheme_distractions.append(Database.get_distractors_for_grapheme(GP.Grapheme, lesson_nb))
		distractions.append(grapheme_distractions)

extends GutTest
## The word pool and its distractors have to be indexed the same way.
##
## WordsMinigame keeps one set of distractors per stimulus, and reads the stimulus
## with a modulo so a pool shorter than max_progression repeats rather than running
## out. The distractors were read straight, so the moment the pool did come out short
## the game went out of range partway through and stopped on a dead screen.
##
## A pool can come out short whenever the current lesson has no usable word -- every
## one of them lacking a recording, which the resolver added in 3.1.5 now filters on
## -- and the previous lessons supply fewer than max_progression. CrabsMinigame and
## JellyfishMinigame both already wrapped here; this is the one that did not.
##
## Asserted against the rule rather than against a running minigame: assigning
## current_progression drives the whole round -- the next word, its sound, the
## remediation scores -- and none of that is what went wrong here.

const WORD_A: Dictionary = {"ID": 1, "Word": "un"}
const WORD_B: Dictionary = {"ID": 2, "Word": "deux"}
## Two words' worth of distractors: one list per GP position, per word.
const TWO_WORDS_OF_DISTRACTORS: Array = [
	[[{"ID": 10}, {"ID": 11}]],
	[[{"ID": 20}]],
]


func test_the_distractors_wrap_with_the_stimuli() -> void:
	# A pool of two, a target of five: the run reaches progressions the pool has no
	# entry for, and the stimulus wraps back to the first word. Its distractors have
	# to come back with it.
	for progression: int in range(5):
		var index: int = WordsMinigame.distractor_index(progression, 2)
		assert_eq(index, progression % 2,
			"progression %d reads the set of the word it is repeating" % progression)
		assert_between(index, 0, 1, "and never off the end of the array")


func test_a_progression_within_the_pool_is_left_alone() -> void:
	# The ordinary case, which the modulo must not disturb.
	for progression: int in range(5):
		assert_eq(WordsMinigame.distractor_index(progression, 5), progression,
			"a pool as long as the target is read straight through")


func test_no_distractors_at_all_names_no_index() -> void:
	assert_eq(WordsMinigame.distractor_index(0, 0), -1, "nothing to index into")
	assert_eq(WordsMinigame.distractor_index(3, 0), -1, "and still nothing further in")


func test_the_queue_is_emptied_before_it_is_refilled() -> void:
	# Not through the tree: WordsMinigame._ready() would go looking for a language
	# pack, and the queue is the subject here.
	var minigame: WordsMinigame = autofree(WordsMinigame.new())
	minigame.stimuli = [WORD_A, WORD_B]
	minigame.distractions = TWO_WORDS_OF_DISTRACTORS.duplicate(true)

	minigame._reset_distractors_queue()
	assert_eq(minigame.current_gp_distractors_queue.size(), 2, "filled for the first GP")

	# Past the last GP of that word: there is nothing to offer, and the previous GP's
	# distractors must not be left lying in the queue for it to pick up.
	minigame.current_word_progression = 9
	minigame._reset_distractors_queue()
	assert_true(minigame.current_gp_distractors_queue.is_empty(),
		"the queue is emptied rather than left holding the previous GP's")
	# A blank is what the minigames already know how to draw.
	assert_eq_deep(minigame._get_distractor(), {})


func test_nothing_is_indexed_when_there_are_no_distractors_at_all() -> void:
	var minigame: WordsMinigame = autofree(WordsMinigame.new())
	minigame.stimuli = [WORD_A]
	minigame.distractions = []

	minigame._reset_distractors_queue()

	assert_true(minigame.current_gp_distractors_queue.is_empty(), "nothing to queue")
	# Nothing to read back either.
	assert_eq_deep(minigame._get_current_distractors(), [])

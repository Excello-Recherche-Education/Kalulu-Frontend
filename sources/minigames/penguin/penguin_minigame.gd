extends Minigame

# Namespace
const Penguin: = preload("res://sources/minigames/penguin/penguin.gd")

const penguin_scene: PackedScene = preload("res://sources/minigames/penguin/penguin.tscn")

const silent_phoneme: = "#"

@onready var main_penguin: Penguin = $GameRoot/Penguin
@onready var penguins_positions: Control = $GameRoot/PenguinsPositions

var current_word_progression: int = 0: set = _set_current_word_progression
var max_word_progression: int = 0

var penguins: Array[Penguin] = []


# Find words with silent GPs
func _find_stimuli_and_distractions() -> void:
	# TODO FOR TESTING
	Database.db.query("SELECT Words.ID, Words.Word, VerifiedCount.Count as GPsCount, MaxLessonNb as LessonNb, VerifiedCount.gpsid as GPs_IDs
FROM Words
	 INNER JOIN 
	(SELECT WordID, count() as Count FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		GROUP BY WordID 
		) TotalCount ON TotalCount.WordID = Words.ID 
	INNER JOIN 
	(SELECT WordID, count() as Count, max(LessonNb) as MaxLessonNb, group_concat(GPsInWords.GPID) as gpsid, group_concat(GPs.Phoneme) as gpphoneme FROM GPsInWords 
		INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
		INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb <= 20
		INNER JOIN GPs ON GPs.ID = GPsInWords.GPID
		GROUP BY WordID 
		) VerifiedCount ON VerifiedCount.WordID = Words.ID AND VerifiedCount.Count = TotalCount.Count
	INNER JOIN GPsInWords ON GPsInWords.WordID = Words.ID 
	INNER JOIN GPsInLessons ON GPsInLessons.GPID = GPsInWords.GPID 
	INNER JOIN Lessons ON Lessons.ID = GPsInLessons.LessonID  AND Lessons.LessonNb = 20
	WHERE TotalCount.Count <= 6 and TotalCount.Count >= 2 AND VerifiedCount.gpphoneme LIKE '%#%'
	ORDER BY LessonNb, GPsCount ASC")
	
	stimuli = Database.db.query_result
	stimuli.shuffle()
	
	while stimuli.size() > max_progression:
		stimuli.pop_front()
	
	for stimulus: Dictionary in stimuli:
		stimulus["GPs"] = Database.get_GP_from_word(stimulus.Word)
	
	print(stimuli)

# Launch the minigame
func _start() -> void:
	if stimuli.is_empty():
		_win()
		return
	_setup_word_progression()


# Setups the word progression for current progression
func _setup_word_progression() -> void:
	max_word_progression = 0
	
	# Make penguins go away TODO
	for penguin: Penguin in penguins:
		penguin.queue_free()
	penguins.clear()
	
	var stimulus: = _get_current_stimulus()
	
	var i: = 1
	for GP: Dictionary in stimulus.GPs:
		# Instantiate a new penguin
		var penguin: Penguin = penguin_scene.instantiate()
		penguins_positions.get_node("Pos" + str(i)).add_child(penguin)
		penguin.gp = GP
		penguin.pressed.connect(_on_snowball_thrown.bind(penguin))
		
		penguins.append(penguin)
		
		i += 1
		
		if GP.Phoneme == silent_phoneme:
			max_word_progression += 1
	current_word_progression = 0


# Get the current stimulus which needs to be found to increase progression
func _get_current_stimulus() -> Dictionary:
	if stimuli.size() == 0:
		return {}
	return stimuli[current_progression % stimuli.size()]


func _set_current_word_progression(p_current_word_progression: int) -> void:
	current_word_progression = p_current_word_progression
	
	if current_word_progression == max_word_progression:
		current_progression += 1
	else:
		@warning_ignore("redundant_await")
		await _on_current_word_progression_changed()


func _is_silent(gp: Dictionary) -> bool:
	return gp.Phoneme == silent_phoneme


func _on_snowball_thrown(pos: Vector2, penguin: Penguin) -> void:
	print(penguin.gp)
	
	# Disables all penguins
	for p: Penguin in penguins:
		p.set_button_enabled(false)
	
	# Throw the snowball TODO
	await main_penguin.throw(pos)
	
	# Checks if the GP pressed is silent
	if _is_silent(penguin.gp):
		current_word_progression += 1
	else:
		current_lives -= 1
	
	# Re-enables all penguins except the one pressed TODO
	for p: Penguin in penguins:
		p.set_button_enabled(true)


func _on_current_word_progression_changed() -> void:
	print("CURRENT WORD PROGRESSION CHANGED")
	pass


func _on_current_progression_changed() -> void:
	print("PROGRESSION CHANGED")
	if current_progression >= max_progression:
		return
	_setup_word_progression()

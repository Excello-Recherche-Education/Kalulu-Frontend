class_name LessonExerciseContainer
extends PanelContainer

# A lesson can hold 1–3 minigames. Slot 1 is always a real minigame (so a lesson
# always has at least one); slots 2 and 3 can be set to "None" (id 0) to leave
# them empty. Database.get_exercise_for_lesson() drops the zeros at read time.
const NONE_EXERCISE_ID: int = 0
const NONE_EXERCISE_LABEL: String = "None"

@export var lesson_number: int = -1:
	set = _set_lesson_number

var sentences_by_lesson: Dictionary = {}

@onready var lesson_id_label: Label = %LessonIDLabel
@onready var lesson_gps: HBoxContainer = %LessonGPs
@onready var exercise_buttons: Array[OptionButton] = [%ExerciseButton1, %ExerciseButton2, %ExerciseButton3]
@onready var ok_texture: TextureRect = %OKTexture
@onready var number_of_g_ps: Label = %NumberOfGPs
@onready var number_of_syllables: Label = %NumberOfSyllables
@onready var number_of_words: Label = %NumberOfWords
@onready var number_of_sentences: Label = %NumberOfSentences


func _ready() -> void:
	Database.db.query("Select * FROM ExerciseTypes")
	var exercise_types: Array[Dictionary] = []
	for element: Dictionary in Database.db.query_result:
		exercise_types.append(element.duplicate())

	for button_index: int in range(exercise_buttons.size()):
		var exercise_button: OptionButton = exercise_buttons[button_index]
		# Slots 2 and 3 can be emptied so a lesson may have fewer than 3 minigames.
		if button_index > 0:
			exercise_button.add_item(NONE_EXERCISE_LABEL, NONE_EXERCISE_ID)
		for element: Dictionary in exercise_types:
			exercise_button.add_item(element.Type as String, element.ID as int)


func _set_lesson_number(value: int) -> void:
	if value == lesson_number:
		return
	
	lesson_number = value
	lesson_id_label.text = str(lesson_number)
	for gp: Label in lesson_gps.get_children():
		gp.queue_free()
	
	Database.db.query("Select Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		WHERE LessonNb = " + str(lesson_number))
	
	for element: Dictionary in Database.db.query_result:
		var gp: Label = Label.new()
		gp.text = Database.get_gp_name(element)
		lesson_gps.add_child(gp)
	
	Database.db.query("Select Exercise1, Exercise2, Exercise3, LessonNb FROM LessonsExercises
	INNER JOIN Lessons ON Lessons.ID = LessonsExercises.LessonID
	WHERE LessonNb = " + str(lesson_number))
	
	for element: Dictionary in Database.db.query_result:
		exercise_buttons[0].select(exercise_buttons[0].get_item_index(element.Exercise1 as int))
		exercise_buttons[1].select(exercise_buttons[1].get_item_index(element.Exercise2 as int))
		exercise_buttons[2].select(exercise_buttons[2].get_item_index(element.Exercise3 as int))
		# Slot 1 must always be a real minigame (its dropdown has no "None" entry);
		# fall back to the first one if the stored data is empty/invalid so a lesson
		# never ends up with 0 minigames.
		if exercise_buttons[0].selected < 0:
			exercise_buttons[0].select(0)
	_refresh_exercise_dependencies()

	var gps_in_lesson: Array[Dictionary] = Database.get_gps_for_lesson(lesson_number, true)
	var syllables_in_lesson: Array[Dictionary] = Database.get_syllables_for_lesson(lesson_number)
	var words_in_lesson: Array[Dictionary] = Database.get_words_for_lesson(lesson_number)
	var sentences_in_lesson: Array = Database.get_sentences(lesson_number, false, sentences_by_lesson)
	
	number_of_g_ps.text = str(gps_in_lesson.size())
	number_of_syllables.text = str(syllables_in_lesson.size())
	number_of_words.text = str(words_in_lesson.size())
	number_of_sentences.text = str(sentences_in_lesson.size())
	
	ok_texture.show()


func _on_exercise_button_1_item_selected(_index: int) -> void:
	ok_texture.hide()


func _on_exercise_button_2_item_selected(_index: int) -> void:
	ok_texture.hide()
	_refresh_exercise_dependencies()


func _on_exercise_button_3_item_selected(_index: int) -> void:
	ok_texture.hide()


# Keeps minigames contiguous: an empty slot 2 forces slot 3 to be empty and
# disabled, so a lesson can only ever hold 1, 2 or 3 minigames played in order.
func _refresh_exercise_dependencies() -> void:
	var slot_2_empty: bool = exercise_buttons[1].get_selected_id() == NONE_EXERCISE_ID
	if slot_2_empty:
		exercise_buttons[2].select(exercise_buttons[2].get_item_index(NONE_EXERCISE_ID))
	exercise_buttons[2].disabled = slot_2_empty


func _on_save_button_pressed() -> void:
	Database.db.query("Select * FROM Lessons WHERE LessonNb = " + str(lesson_number))
	var lesson_id: int = Database.db.query_result[0].ID
	
	var exercise1: int = exercise_buttons[0].get_item_id(exercise_buttons[0].selected)
	var exercise2: int = exercise_buttons[1].get_item_id(exercise_buttons[1].selected)
	var exercise3: int = exercise_buttons[2].get_item_id(exercise_buttons[2].selected)
	var lesson_dict: Dictionary = {"Exercise1": exercise1, "Exercise2": exercise2, "Exercise3": exercise3}
	
	Database.db.query("Select * FROM LessonsExercises WHERE LessonID = " + str(lesson_id))
	if Database.db.query_result.is_empty():
		lesson_dict["LessonID"] = lesson_id
		Database.db.insert_row("LessonsExercises", lesson_dict)
	else:
		Database.db.update_rows("LessonsExercises", "LessonID=" + str(lesson_id), lesson_dict)
	
	ok_texture.show()

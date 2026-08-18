extends Control

const LESSON_EXERCISE_CONTAINER_SCENE: PackedScene = preload("res://sources/language_tool/lesson_exercises_container.tscn")

@onready var lessons_container: VBoxContainer = %LessonsContainer


func _ready() -> void:
	# A lesson can have fewer than 3 minigames: empty slots are stored as 0 in
	# Exercise2/Exercise3. Older packs put a foreign key on those columns, which
	# rejects 0 (no ExerciseTypes row has ID 0). Drop that constraint first so the
	# "None" option can be saved.
	_migrate_lessons_exercises_drop_exercise_fk()

	# ExerciseTypes mirrors Minigame.TYPE_NAMES, one row per minigame, and its ID is
	# what LessonsExercises stores -- so the row at a given ID must always hold the name
	# at that position. Keying the seeding on the ID rather than on the name is what
	# makes a rename work: seeding by name kept the row count intact, so nothing was
	# dropped, the new name was found nowhere and got appended as an extra row, leaving
	# the old name in place and a phantom row a lesson could then be assigned to.
	var query: String = "SELECT name FROM sqlite_master WHERE type='table' AND name='ExerciseTypes'"
	Database.db.query(query)
	if Database.db.query_result.is_empty():
		Database.db.query("CREATE TABLE ExerciseTypes (ID INTEGER PRIMARY KEY ASC AUTOINCREMENT UNIQUE NOT NULL, Type TEXT NOT NULL)")
	for type_index: int in range(Minigame.TYPE_NAMES.size()):
		var exercise_id: int = type_index + 1
		var exercise_name: String = Minigame.TYPE_NAMES[type_index]
		Database.db.query("SELECT Type FROM ExerciseTypes WHERE ID = %d" % exercise_id)
		if Database.db.query_result.is_empty():
			Database.db.insert_row("ExerciseTypes",
			{
				ID = exercise_id,
				Type = exercise_name,
			})
			continue
		var stored_name: String = Database.db.query_result[0].Type as String
		if stored_name != exercise_name:
			Log.info("LessonExercises: ExerciseType %d: %s -> %s" % [exercise_id, stored_name, exercise_name])
			Database.db.update_rows("ExerciseTypes", "ID = %d" % exercise_id,
			{
				Type = exercise_name,
			})
	# Rows past the enum are leftovers from a longer list, or from the name-based
	# seeding this replaced. Free any lesson slot still pointing at one before the row
	# goes: the foreign keys were dropped above, so such an ID would simply dangle, and
	# the gardens wheel has no icon for it. 0 is the "no minigame in this slot" value.
	var last_type_id: int = Minigame.TYPE_NAMES.size()
	var free_slot: String = "UPDATE LessonsExercises SET %s = 0 WHERE %s > %d"
	for column: String in ["Exercise1", "Exercise2", "Exercise3"]:
		Database.db.query(free_slot % [column, column, last_type_id])
	Database.db.query("DELETE FROM ExerciseTypes WHERE ID > %d" % last_type_id)
	
	query = "SELECT name FROM sqlite_master WHERE type='table' AND name='LessonsExercises'"
	Database.db.query(query)
	if Database.db.query_result.is_empty():
		# No foreign key on the Exercise columns: an empty slot is stored as 0 and a
		# lesson can hold 1–3 minigames (see Database.get_exercise_for_lesson).
		Database.db.query("CREATE TABLE 'LessonsExercises' (
			'ID'	INTEGER NOT NULL UNIQUE,
			'LessonID'	INTEGER NOT NULL,
			'Exercise1'	INTEGER NOT NULL,
			'Exercise2'	INTEGER NOT NULL,
			'Exercise3'	INTEGER NOT NULL,
			PRIMARY KEY('ID' AUTOINCREMENT),
			FOREIGN KEY('LessonID') REFERENCES 'Lessons'('ID') ON UPDATE CASCADE ON DELETE CASCADE
		)")
	
	var sentences_by_lesson: Dictionary = Database.get_sentences_by_lessons()
	Database.db.query("Select * FROM Lessons")
	for result: Dictionary in Database.db.query_result:
		var container: LessonExerciseContainer = LESSON_EXERCISE_CONTAINER_SCENE.instantiate()
		lessons_container.add_child(container)
		container.sentences_by_lesson = sentences_by_lesson
		container.lesson_number = result.LessonNb
		container._on_save_button_pressed()


# Recreates LessonsExercises without the foreign keys on Exercise1/2/3 (keeping
# the LessonID one) so empty slots can be stored as 0. Data is preserved. No-op
# when the table is missing or already migrated.
func _migrate_lessons_exercises_drop_exercise_fk() -> void:
	Database.db.query("PRAGMA foreign_key_list('LessonsExercises')")
	var references_exercise_types: bool = false
	for foreign_key: Dictionary in Database.db.query_result:
		if (foreign_key.get("table", "") as String) == "ExerciseTypes":
			references_exercise_types = true
			break
	if not references_exercise_types:
		return

	Database.db.query("PRAGMA foreign_keys = OFF")
	Database.db.query("BEGIN TRANSACTION")
	Database.db.query("CREATE TABLE 'LessonsExercises_new' (
		'ID'	INTEGER NOT NULL UNIQUE,
		'LessonID'	INTEGER NOT NULL,
		'Exercise1'	INTEGER NOT NULL,
		'Exercise2'	INTEGER NOT NULL,
		'Exercise3'	INTEGER NOT NULL,
		PRIMARY KEY('ID' AUTOINCREMENT),
		FOREIGN KEY('LessonID') REFERENCES 'Lessons'('ID') ON UPDATE CASCADE ON DELETE CASCADE
	)")
	Database.db.query("INSERT INTO LessonsExercises_new (ID, LessonID, Exercise1, Exercise2, Exercise3)
		SELECT ID, LessonID, Exercise1, Exercise2, Exercise3 FROM LessonsExercises")
	Database.db.query("DROP TABLE LessonsExercises")
	Database.db.query("ALTER TABLE LessonsExercises_new RENAME TO LessonsExercises")
	Database.db.query("COMMIT")
	Database.db.query("PRAGMA foreign_keys = ON")
	Log.info("LessonExercises: Migrated LessonsExercises to drop Exercise foreign keys (0 = no minigame is now allowed).")


func _on_save_button_pressed() -> void:
	for container: LessonExerciseContainer in lessons_container.get_children():
		container._on_save_button_pressed()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")

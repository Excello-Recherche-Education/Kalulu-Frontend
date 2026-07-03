extends Control

const LESSON_EXERCISE_CONTAINER_SCENE: PackedScene = preload("res://sources/language_tool/lesson_exercises_container.tscn")

@onready var lessons_container: VBoxContainer = %LessonsContainer


func _ready() -> void:
	# A lesson can have fewer than 3 minigames: empty slots are stored as 0 in
	# Exercise2/Exercise3. Older packs put a foreign key on those columns, which
	# rejects 0 (no ExerciseTypes row has ID 0). Drop that constraint first so the
	# "None" option can be saved.
	_migrate_lessons_exercises_drop_exercise_fk()

	# Retrocompatibility
	Database.db.query("SELECT Count(*) AS nb FROM ExerciseTypes")
	if Database.db.query_result[0].nb != Minigame.Type.size():
		Database.db.query("DROP TABLE ExerciseTypes")
	
	var query: String = "SELECT name FROM sqlite_master WHERE type='table' AND name='ExerciseTypes'"
	Database.db.query(query)
	if Database.db.query_result.is_empty():
		Database.db.query("CREATE TABLE ExerciseTypes (ID INTEGER PRIMARY KEY ASC AUTOINCREMENT UNIQUE NOT NULL, Type TEXT NOT NULL)")
	for exercise_name: String in Minigame.TYPE_NAMES:
		Database.db.query("SELECT * FROM ExerciseTypes WHERE Type = '%s'" % exercise_name)
		if Database.db.query_result.is_empty():
			Database.db.insert_row("ExerciseTypes",
			{
				Type = exercise_name,
			})
	
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

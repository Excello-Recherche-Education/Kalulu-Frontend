extends Control

@onready var lessons_container: = $%LessonsContainer
@onready var unused_gp_container: = $%UnusedGPContainer

var lesson_container_scene: = preload("res://sources/language_tool/lesson_container.tscn")
var gp_label_scene: = preload("res://sources/language_tool/lesson_gp_label.tscn")

var lessons: = {}


func _ready() -> void:
	Database.db.query("Select Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		ORDER BY LessonNb")
	for e in Database.db.query_result:
		if lessons.has(e.LessonNb):
			lessons[e.LessonNb].add_gp({grapheme = e.Grapheme, phoneme = e.Phoneme, gp_id = e.GPID})
		else:
			var lesson_container: = lesson_container_scene.instantiate()
			lessons_container.add_child(lesson_container)
			lesson_container.add_gp({grapheme = e.Grapheme, phoneme = e.Phoneme, gp_id = e.GPID})
			lesson_container.number = e.LessonNb
			lesson_container.lesson_dropped.connect(_on_lesson_dropped)
			lessons[e.LessonNb] = lesson_container
	
	Database.db.query("SELECT Grapheme, Phoneme, GPs.ID as GPID FROM GPs
		WHERE NOT EXISTS(SELECT 1 FROM GPsInLessons WHERE GPs.ID=GPsInLessons.GPID)")
	for e in Database.db.query_result:
		var gp_label: = gp_label_scene.instantiate()
		unused_gp_container.add_child(gp_label)
		gp_label.grapheme = e.Grapheme
		gp_label.phoneme = e.Phoneme
		gp_label.gp_id = e.GPID
		gp_label.gp_dropped.connect(_on_gp_dropped)
	
	unused_gp_container.set_drag_forwarding(Callable(), _can_drop_in_gp_container, _drop_data_in_gp_container)


func _on_plus_button_pressed() -> void:
	var lesson_container: = lesson_container_scene.instantiate()
	lessons_container.add_child(lesson_container)
	lesson_container.lesson_dropped.connect(_on_lesson_dropped)
	var max_nb: = -1
	for e in lessons.values():
		max_nb = max(max_nb, e.number)
	lesson_container.number = max_nb + 1
	lessons[max_nb + 1] = lesson_container


func _can_drop_in_gp_container(_at_position: Vector2, data: Variant) -> bool:
	return data.has("gp_id")


func _drop_data_in_gp_container(_at_position: Vector2, data: Variant) -> void:
	if not data.has("gp_id"):
		return
	var new_gp_label: = gp_label_scene.instantiate()
	new_gp_label.grapheme = data.grapheme
	new_gp_label.phoneme = data.phoneme
	new_gp_label.gp_id = data.gp_id
	new_gp_label.gp_dropped.connect(_drop_data_in_gp_container)
	unused_gp_container.add_child(new_gp_label)


func _on_gp_dropped(_before: bool, data: Dictionary) -> void:
	_drop_data_in_gp_container(Vector2.ZERO, data)


func _on_lesson_dropped(before: bool, number: int, dropped_number: int) -> void:
	var dropped_lesson = lessons[dropped_number]
	var where_lesson = lessons[number]
	var index: int = where_lesson.get_index()
	if not before:
		index += 1
	lessons_container.move_child(dropped_lesson, index)
	var children: = lessons_container.get_children()
	for i in children.size():
		var child: = children[i]
		child.number = i + 1
		lessons[child.number] = child



func _on_save_button_pressed() -> void:
	Database.db.query("Select Lessons.ID as LessonId FROM Lessons")
	
	var result: = Database.db.query_result
	for row in result:
		Database.db.delete_rows("Lessons", "ID=%s" % row.LessonId)
	var children: = lessons_container.get_children()
	for i in children.size():
		var child: = children[i]
		Database.db.insert_row("Lessons",
		{
			LessonNb = i + 1
		})
		var lesson_id: = Database.db.last_insert_rowid
		for gp_id in child.get_gp_ids():
			Database.db.insert_row("Lessons",
			{
				GPID = gp_id,
				LessonID = lesson_id,
			})


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")

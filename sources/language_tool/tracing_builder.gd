extends Control

@export var gradient: Gradient

@onready var lower_container: = %LowerContainer
@onready var upper_container: = %UpperContainer
@onready var letter_picker: = %LetterPicker
@onready var save_ok: = %SaveOk

const extension: = ".csv"

var letters: Array[String] = []
var current_letter: = -1


func _ready() -> void:
	lower_container.gradient = gradient
	upper_container.gradient = gradient
	
	_find_all_letters()
	_next_letter()


func _find_all_letters() -> void:
	letters = []
	
	var query: = "Select * FROM GPs"
	Database.db.query(query)
	var result: = Database.db.query_result
	for element in result:
		for letter in element.Grapheme:
			if not letter in letters:
				letters.append(letter)
				letter_picker.add_item(letter)


func _next_letter() -> void:
	current_letter = (current_letter + 1) % letters.size()
	
	await lower_container.reset()
	await upper_container.reset()
	
	lower_container.grapheme_label.text = letters[current_letter].to_lower()
	upper_container.grapheme_label.text = letters[current_letter].to_upper()
	
	Database.db.query("Select LowerTracingPath, UpperTracingPath FROM LettersTracingData WHERE Letter = '" + letters[current_letter] + "'")
	
	if not Database.db.query_result.is_empty():
		var lower_path: String = Database.db.query_result[0]["LowerTracingPath"]
		var upper_path: String = Database.db.query_result[0]["UpperTracingPath"]
		
		_load_segments(lower_container, lower_path)
		_load_segments(upper_container, upper_path)
	
	letter_picker.selected = current_letter
	save_ok.visible = true


func _load_segments(segment_container: SegmentContainer, path: String) -> void:
	if not FileAccess.file_exists(real_path(path)):
		return
	
	var file: = FileAccess.open(real_path(path), FileAccess.READ)
	while not file.eof_reached():
		var line: = file.get_csv_line()
		var points: = []
		for element in line:
			if element == "":
				break
			
			var s: = element.split(" ")
			points.append(Vector2(float(s[0]), float(s[1])))
		if not points.is_empty():
			segment_container.load_segment(points)


func _save_segments(segments: Array, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(Database.base_path.path_join(Database.language).path_join(Database.tracing_data_folder))
	var file: = FileAccess.open(real_path(path), FileAccess.WRITE)
	for segment in segments:
		var values: PackedStringArray = []
		for point in segment.points:
			values.append(str(point.x) + " " + str(point.y))
		file.store_csv_line(values)
	file.close()


func real_path(path: String) -> String:
	return Database.base_path.path_join(Database.language).path_join(Database.tracing_data_folder).path_join(path) + extension


func _on_save_button_pressed() -> void:
	var lower_path: = letters[current_letter] + "_lower"
	var upper_path: = letters[current_letter] + "_upper"
	
	_save_segments(lower_container.segments_container.get_children(), lower_path)
	_save_segments(upper_container.segments_container.get_children(), upper_path)
	
	Database.db.query("Select LowerTracingPath, UpperTracingPath FROM LettersTracingData WHERE Letter = '" + letters[current_letter] + "'")
	
	if Database.db.query_result.is_empty():
		Database.db.query("INSERT INTO LettersTracingData (Letter, LowerTracingPath, UpperTracingPath) VALUES ('" + letters[current_letter] + "','" + lower_path + "','" + upper_path + "')")
	
	save_ok.visible = true


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")


func _on_letter_picker_item_selected(index: int) -> void:
	current_letter = index - 1
	_next_letter()


func _on_lower_container_changed() -> void:
	save_ok.visible = false


func _on_upper_container_changed() -> void:
	save_ok.visible = false

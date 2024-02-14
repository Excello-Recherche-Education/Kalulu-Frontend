extends Control

@export var grapheme: = "azertyuiopmlkjhgfdsqwxcvbnéàùèç"

@export var gradient: Gradient

@onready var lower_container: = %LowerContainer
@onready var upper_container: = %UpperContainer

const extension: = ".csv"

var current_letter: = -1


func _ready() -> void:
	lower_container.gradient = gradient
	upper_container.gradient = gradient
	
	_next_letter()


func _next_letter() -> void:
	current_letter += 1
	if current_letter >= grapheme.length():
		current_letter = 0
	
	lower_container.reset()
	upper_container.reset()
	
	lower_container.grapheme_label.text = grapheme[current_letter].to_lower()
	upper_container.grapheme_label.text = grapheme[current_letter].to_upper()
	
	Database.db.query("Select LowerTracingPath, UpperTracingPath FROM LettersTracingData WHERE Letter = '" + grapheme[current_letter] + "'")
	
	if not Database.db.query_result.is_empty():
		var lower_path: String = Database.db.query_result[0]["LowerTracingPath"]
		var upper_path: String = Database.db.query_result[0]["UpperTracingPath"]
		
		_load_segments(lower_container, lower_path)
		_load_segments(upper_container, upper_path)


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
	var lower_path: = grapheme[current_letter] + "_lower"
	var upper_path: = grapheme[current_letter] + "_upper"
	
	_save_segments(lower_container.segments_container.get_children(), lower_path)
	_save_segments(upper_container.segments_container.get_children(), upper_path)
	
	Database.db.query("Select LowerTracingPath, UpperTracingPath FROM LettersTracingData WHERE Letter = '" + grapheme[current_letter] + "'")
	
	if Database.db.query_result.is_empty():
		Database.db.query("INSERT INTO LettersTracingData (Letter, LowerTracingPath, UpperTracingPath) VALUES ('" + grapheme[current_letter] + "','" + lower_path + "','" + upper_path + "')")
	
	_next_letter()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")

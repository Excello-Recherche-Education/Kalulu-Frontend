extends Control

signal finished()

const letter_segment_class: = preload("res://sources/look_and_learn/letter_segment.tscn")

@onready var lower_labels: = %LowerLabels
@onready var upper_labels: = %UpperLabels

const resource_folder: = "res://language_resources/"
const language_folder: = "french/"
const tracing_data_folder: = "tracing_data/"
const extension: = ".csv"


func _process(_delta: float) -> void:
	place_segments(lower_labels.get_children())
	place_segments(upper_labels.get_children())


func place_segments(labels: Array) -> void:
	for label in labels:
		for segment in label.get_children():
			segment.global_position = label.global_position + label.size / 2.0  + Vector2(0.0, 72.0)


func reset() -> void:
	for child in lower_labels.get_children():
		child.queue_free()
	for child in upper_labels.get_children():
		child.queue_free()
	
	lower_labels.visible = true
	upper_labels.visible = false


# --- Setup ---

func setup(grapheme: String) -> void:
	reset()
	
	if not _is_grapheme_valid(grapheme):
		finished.emit()
		return
	
	for letter in grapheme:
		var tracings: = _get_letter_tracings(letter)
		
		setup_tracing(letter, tracings["lower"], lower_labels, true)
		setup_tracing(letter, tracings["upper"], upper_labels, false)


func setup_tracing(letter: String, letter_tracings: Array, parent: Control, lower: bool) -> void:
	var label: = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set("theme_override_font_sizes/font_size", 512)
	
	if lower:
		label.text = letter.to_lower()
	else:
		label.text = letter.to_upper()
	
	parent.add_child(label)
	
	for points: Array in letter_tracings:
		var segment: LetterSegment = letter_segment_class.instantiate()
		label.add_child(segment)
		segment.setup(points)


func _is_grapheme_valid(grapheme: String) -> bool:
	var is_ok: = true
	for letter in grapheme:
		Database.db.query("Select LowerTracingPath, UpperTracingPath FROM LettersTracingData WHERE Letter = '" + letter + "'")
		if Database.db.query_result.is_empty():
			is_ok = false
	
	return is_ok


func _get_letter_tracings(letter: String) -> Dictionary:
	Database.db.query("Select LowerTracingPath, UpperTracingPath FROM LettersTracingData WHERE Letter = '" + letter + "'")
	
	var lower_path: String = Database.db.query_result[0]["LowerTracingPath"]
	var upper_path: String = Database.db.query_result[0]["UpperTracingPath"]
	
	var lower_tracing: = _load_tracing(lower_path)
	var upper_tracing: = _load_tracing(upper_path)
	
	return {"lower": lower_tracing, "upper": upper_tracing}


func _load_tracing(path: String) -> Array:
	if not FileAccess.file_exists(_real_path(path)):
		return []
	
	var segments: = []
	var file: = FileAccess.open(_real_path(path), FileAccess.READ)
	while not file.eof_reached():
		var points: = []
		var line: = file.get_csv_line()
		for element in line:
			if element == "":
				break
			
			var s: = element.split(" ")
			points.append(Vector2(float(s[0]), float(s[1])))
		
		if not points.is_empty():
			segments.append(points)
	
	return segments


func _real_path(path: String) -> String:
	return resource_folder + language_folder + tracing_data_folder + path + extension


# --- Start ---


func start() -> void:
	await demo_labels(lower_labels)
	await start_labels(lower_labels)
	
	lower_labels.visible = false
	upper_labels.visible = true
	
	await demo_labels(upper_labels)
	await start_labels(upper_labels)
	
	emit_signal("finished")


func start_labels(labels_parent: Control) -> void:
	for letter in labels_parent.get_children():
		for segment in letter.get_children():
			segment.start()
			await segment.finished
			letter.move_child(segment, 0)


func demo_labels(labels_parent: Control) -> void:
	for letter in labels_parent.get_children():
		for segment in letter.get_children():
			segment.demo()
			await segment.finished

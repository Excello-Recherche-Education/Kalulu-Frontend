class_name LogViewer
extends AcceptDialog

@onready var log_text: TextEdit = $VBox/LogText
@onready var slider: HSlider = $VBox/Controls/LineCountSlider
@onready var slider_label: Label = $VBox/Controls/SliderLabel

var file_path: String
var all_lines: PackedStringArray = []
var line_steps: PackedInt32Array = [10, 50, 100, 200, 500, 1000, -1] # -1 = all


func show_log_file(path: String) -> void:
	file_path = path
	if not FileAccess.file_exists(file_path):
		log_text.text = "File not found: %s" % file_path
		popup_centered()
		return
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		log_text.text = "Cannot load file: %s" % file_path
		return
	
	all_lines.clear()
	while not file.eof_reached():
		all_lines.append(file.get_line())
	
	slider.min_value = 0
	slider.max_value = line_steps.size() - 1
	slider.step = 1
	slider.value = 0
	
	if not slider.value_changed.is_connected(_on_slider_changed):
		slider.value_changed.connect(_on_slider_changed)
	
	_update_log_text()
	popup_centered_ratio(0.9)


func _on_slider_changed(_value: float) -> void:
	_update_log_text()


func _update_log_text() -> void:
	var idx: int = int(slider.value)
	var lines_to_show: int = line_steps[idx]
	var total: int = all_lines.size()
	
	var subset: PackedStringArray
	if lines_to_show == -1:
		slider_label.text = "Show: all (%d lines)" % total
		subset = all_lines
	else:
		slider_label.text = "Show: %d last lines" % lines_to_show
		var start: int = maxi(total - lines_to_show, 0)
		subset = all_lines.slice(start, total)
	
	log_text.text = "\n".join(subset)
	log_text.scroll_vertical = log_text.get_line_count() # Scroll down

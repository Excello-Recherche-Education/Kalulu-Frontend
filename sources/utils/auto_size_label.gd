@tool
class_name AutoSizeLabel
extends Container

# Text used as the sizing reference: the label is scaled so this string fits
# the container. When the displayed text has a variable, unbounded length
# (e.g. a player name), set ref_size_text to that same text so it never
# overflows the container.
@export_multiline var ref_size_text: String = "":
	set(value):
		ref_size_text = value
		if is_node_ready():
			_compute_ref_size()
			queue_sort()

var ref_size: Vector2

@onready var label: Label = $Label


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_rescale()


func _ready() -> void:
	_compute_ref_size()


func _compute_ref_size() -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	ref_size = font.get_multiline_string_size(ref_size_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)


func _rescale() -> void:
	label.pivot_offset = label.size / 2
	if ref_size.x == 0 or ref_size.y == 0:
		return
	var scale_factor: float = minf(size.x / ref_size.x, size.y / ref_size.y)
	label.scale = Vector2.ONE * scale_factor
	# Center the scaled label about the container center. The pivot point maps to
	# (position + pivot_offset) regardless of scale, so centering must NOT scale
	# pivot_offset — doing so shifts the content by pivot_offset*(1-scale) whenever
	# scale != 1 (e.g. long player names that get shrunk to fit).
	label.position = size / 2 - label.pivot_offset

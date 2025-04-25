extends Label
class_name DynamicFontSizeLabel

@export var autosize_on: bool = true
@export var font_size_override: int = -1
@export var font_size_min: int = 8
@export var font_size_max: int = 100
@export var font_size_width_percent: float = 0.9

var _current_font_size: int
var _default_font_size: int

func _ready() -> void:
	resized.connect(_on_resized)
	_initialize_default_font_size()
	_update_font_size()

func _initialize_default_font_size() -> void:
	_default_font_size = get_theme_font_size("font_size")

func _on_resized() -> void:
	_update_font_size()

func _update_font_size() -> void:
	if not autosize_on:
		return

	if font_size_override >= 0:
		_current_font_size = font_size_override
	else:
		_current_font_size = _calculate_best_font_size()

	add_theme_font_size_override("font_size", _current_font_size)

# Recherche binaire de la taille de police optimale
func _calculate_best_font_size() -> int:
	var available_width: float = size.x * font_size_width_percent
	var available_height: float = size.y

	var font: Font = get_theme_font("font")
	var low: int = font_size_min
	var high: int = font_size_max
	var best_size: int = low

	while low <= high:
		@warning_ignore("integer_division")
		var mid: int = int((low + high) / 2)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, mid)
		
		# Si le texte rentre, on essaie de l'augmenter
		if text_size.x <= available_width and text_size.y <= available_height:
			best_size = mid
			low = mid + 1  # On essaie une taille plus grande
		else:
			high = mid - 1  # On essaie une taille plus petite

	return best_size

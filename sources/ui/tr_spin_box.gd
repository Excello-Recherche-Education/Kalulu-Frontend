extends SpinBox
## A SpinBox that names itself inside its own field.
##
## The redesign gives every field the whole centre column with no label beside
## it, which works for anything that can show a placeholder. A SpinBox always
## holds a number, so it says what the number is for with a prefix instead.
##
## The prefix is written into the field verbatim, so it has to be translated
## here rather than set as a key in the scene -- same reason tr_item_list exists.

@export var prefix_key: String


func _ready() -> void:
	if prefix_key:
		prefix = tr(prefix_key)

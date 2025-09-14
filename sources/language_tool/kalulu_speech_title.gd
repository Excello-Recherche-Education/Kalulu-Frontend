class_name KaluluTitle
extends PanelContainer

@export var title: String = "":
	set = _set_title

@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	_set_title(title)


func _set_title(value: String) -> void:
	title = value
	if title_label:
		title_label.text = title

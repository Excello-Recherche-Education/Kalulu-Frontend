extends MarginContainer

var gp_label_scene: = preload("res://sources/language_tool/lesson_gp_label.tscn")


var number: = 0:
	set = set_number


@onready var gp_container: = $%GPContainer
@onready var number_label: = $%NumberLabel


func set_number(p_number: int) -> void:
	number = p_number
	if number_label:
		number_label.text = str(number)


func add_gp(new_gp: Dictionary) -> void:
	var gp_label: = gp_label_scene.instantiate()
	gp_label.grapheme = new_gp.grapheme
	gp_label.phoneme = new_gp.phoneme
	gp_label.gp_id = new_gp.gp_id
	gp_container.add_child(gp_label)
	gp_label.gp_dropped.connect(_on_gp_dropped.bind(gp_label))
	gp_label.gp_removed.connect(_on_gp_removed.bind(gp_label))


func _on_gp_dropped(before: bool, data: Dictionary, gp_label: Control) -> void:
	var new_gp_label: = gp_label_scene.instantiate()
	new_gp_label.grapheme = data.grapheme
	new_gp_label.phoneme = data.phoneme
	new_gp_label.gp_id = data.gp_id
	new_gp_label.gp_dropped.connect(_on_gp_dropped.bind(new_gp_label))
	new_gp_label.gp_removed.connect(_on_gp_removed.bind(new_gp_label))
	gp_container.add_child(new_gp_label)
	var children: = gp_container.get_children()
	for i in children.size():
		var child = children[i]
		if child == gp_label:
			if before:
				gp_container.move_child(new_gp_label, i)
			else:
				gp_container.move_child(new_gp_label, i + 1)


func _on_gp_removed(gp_label: Control) -> void:
	gp_label.queue_free()

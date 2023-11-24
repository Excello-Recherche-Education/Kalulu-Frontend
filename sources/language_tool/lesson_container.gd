extends MarginContainer

var gp_label_scene: = preload("res://sources/language_tool/lesson_gp_label.tscn")


var gps: = []:
	set = set_gps
var number: = 0:
	set = set_number


@onready var gp_container: = $%GPContainer
@onready var number_label: = $%NumberLabel


func set_gps(p_gps: Array) -> void:
	gps = p_gps
	if not gp_container:
		return
	for child in gp_container.get_children():
		child.queue_free()
	for gp in gps:
		var gp_label: = gp_label_scene.instantiate()
		gp_label.grapheme = gp.grapheme
		gp_label.phoneme = gp.phoneme
		gp_container.add_child(gp_label)


func set_number(p_number: int) -> void:
	number = p_number
	if number_label:
		number_label.text = str(number)


func add_gp(new_gp: Dictionary) -> void:
	var gp_label: = gp_label_scene.instantiate()
	gp_label.grapheme = new_gp.grapheme
	gp_label.phoneme = new_gp.phoneme
	gp_container.add_child(gp_label)
	gps.append(new_gp)

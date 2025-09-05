class_name SegmentBuild
extends HBoxContainer

signal modified()
signal deleted()

var points: Array[Vector2] = []

@onready var number_of_points_labels: Label = %NumberOfPointsLabel
@onready var color_rect: ColorRect = %ColorRect


func add_point(point: Vector2) -> void:
	points.append(point)


func add_point_at(point: Vector2, ind: int) -> void:
	var pts: Array[Vector2] = []
	for index: int in range(ind):
		pts.append(points[index])
	pts.append(point)
	for index: int in range(ind, points.size()):
		pts.append(points[index])
	points = pts


func remove_point(point: Vector2) -> int:
	var ind: int = points.find(point)
	points.erase(point)
	return ind


func set_color(color: Color) -> void:
	color_rect.color = color


func _on_modify_button_pressed() -> void:
	modified.emit()


func _on_delete_button_pressed() -> void:
	deleted.emit()
	queue_free()

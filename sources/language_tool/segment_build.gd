extends HBoxContainer
class_name SegmentBuild

signal modify()
signal delete()

@onready var number_of_points_labels: Label = %NumberOfPointsLabel
@onready var color_rect: ColorRect = %ColorRect

var points: Array[Vector2]


func add_point(point: Vector2) -> void:
	points.append(point)


func add_point_at(point: Vector2, ind: int) -> void:
	var pts: = []
	for index: int in range(ind):
		pts.append(points[index])
	pts.append(point)
	for index: int in range(ind, points.size()):
		pts.append(points[index])
	points = pts


func remove_point(point: Vector2) -> int:
	var ind: = points.find(point)
	points.erase(point)
	return ind


func set_color(color: Color) -> void:
	color_rect.color = color


func _on_modify_button_pressed() -> void:
	modify.emit()


func _on_delete_button_pressed() -> void:
	delete.emit()
	queue_free()

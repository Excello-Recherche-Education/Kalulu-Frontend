@tool
class_name PercentMarginContainer
extends Container

@export var margin_left_ratio: float = 0.0:
	set = set_margin_left_ratio
@export var margin_top_ratio: float = 0.0:
	set = set_margin_top_ratio
@export var margin_right_ratio: float = 0.0:
	set = set_margin_right_ratio
@export var margin_bottom_ratio: float = 0.0:
	set = set_margin_bottom_ratio


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var children_rect: Rect2 = Rect2(
			size.x * margin_left_ratio,
			size.y * margin_top_ratio,
			size.x * (1. - margin_left_ratio - margin_right_ratio),
			size.y * (1. - margin_top_ratio - margin_bottom_ratio)
		)
		for child: Node in get_children():
			if child is Control:
				fit_child_in_rect(child as Control, children_rect)


func _get_minimum_size() -> Vector2:
	var min_size: Vector2 = Vector2(0, 0)
	var combined_min_size: Vector2
	for child: Node in get_children():
		if child is Control:
			combined_min_size = (child as Control).get_combined_minimum_size()
			min_size.x = maxf(combined_min_size.x, min_size.x)
			min_size.y = maxf(combined_min_size.y, min_size.y)
	return min_size


func set_margin_left_ratio(p_ratio: float) -> void:
	margin_left_ratio = p_ratio
	queue_sort()


func set_margin_top_ratio(p_ratio: float) -> void:
	margin_top_ratio = p_ratio
	queue_sort()


func set_margin_right_ratio(p_ratio: float) -> void:
	margin_right_ratio = p_ratio
	queue_sort()


func set_margin_bottom_ratio(p_ratio: float) -> void:
	margin_bottom_ratio = p_ratio
	queue_sort()

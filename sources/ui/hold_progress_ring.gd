class_name HoldProgressRing
extends Control

@export var ring_color: Color = Color(0.95, 0.99, 1.0, 1.0)
@export var background_ring_color: Color = Color(1.0, 1.0, 1.0, 0.2)
@export var ring_width: float = 14.0
@export var start_angle_degrees: float = -90.0

var progress_ratio: float = 0.0:
	set(value):
		progress_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - ring_width * 0.5
	if radius <= 0.0:
		return

	draw_arc(center, radius, 0.0, TAU, 64, background_ring_color, ring_width, true)
	var start_angle: float = deg_to_rad(start_angle_degrees)
	var end_angle: float = start_angle + TAU * progress_ratio
	draw_arc(center, radius, start_angle, end_angle, 64, ring_color, ring_width, true)

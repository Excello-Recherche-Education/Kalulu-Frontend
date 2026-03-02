class_name BackButton
extends TextureButton

@export var ring_padding: float = 16.0:
	set(value):
		ring_padding = value
		if is_node_ready():
			_update_ring_layout()

@onready var hold_ring: HoldProgressRing = %BackButtonHoldRing


func _ready() -> void:
	_update_ring_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_ring_layout()


func begin_hold() -> void:
	hold_ring.progress_ratio = 0.0
	hold_ring.show()


func cancel_hold() -> void:
	hold_ring.progress_ratio = 0.0
	hold_ring.hide()


func set_hold_progress_ratio(progress_ratio: float) -> void:
	hold_ring.progress_ratio = progress_ratio


func _update_ring_layout() -> void:
	hold_ring.position = Vector2.ONE * -ring_padding
	hold_ring.size = size + Vector2.ONE * ring_padding * 2.0

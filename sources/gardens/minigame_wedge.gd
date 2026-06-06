class_name MinigameWedge
extends Control

signal pressed()

const ICON_SIZE: Vector2 = Vector2(256, 256)
const GRAYSCALE_SHADER: Shader = preload("res://resources/shaders/grayscale.gdshader")

var is_disabled: bool = false

@onready var polygon: Polygon2D = $Polygon2D
@onready var area: Area2D = $Area2D
@onready var collision: CollisionPolygon2D = $Area2D/CollisionPolygon2D
@onready var icon_body_rect: TextureRect = $IconBodyRect
@onready var icon_face_rect: TextureRect = $IconFaceRect
@onready var right_fx: RightFX = $IconFaceRect/RightFX
@onready var wrong_fx: WrongFX = $IconFaceRect/WrongFX


func _ready() -> void:
	area.input_event.connect(_on_click)


func configure(
	wedge_polygon: PackedVector2Array,
	icon_center: Vector2,
	body_texture: Texture,
	face_texture: Texture,
	wedge_color: Color,
	body_color: Color,
	is_locked: bool,
) -> void:
	polygon.polygon = wedge_polygon
	polygon.color = wedge_color
	collision.polygon = wedge_polygon
	var icon_origin: Vector2 = icon_center - ICON_SIZE * 0.5
	icon_body_rect.position = icon_origin
	icon_body_rect.texture = body_texture
	icon_body_rect.modulate = body_color
	icon_face_rect.position = icon_origin
	icon_face_rect.texture = face_texture
	# Desaturate the face when locked.
	if is_locked:
		var grayscale: ShaderMaterial = ShaderMaterial.new()
		grayscale.shader = GRAYSCALE_SHADER
		icon_face_rect.material = grayscale
	else:
		icon_face_rect.material = null


func right() -> void:
	right_fx.play()


func wrong() -> void:
	wrong_fx.play()


func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("left_click") and not is_disabled:
		pressed.emit()

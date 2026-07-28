class_name TreasureChest
extends TextureRect

## The end-game treasure on the brain screen. Owns its closed / opened look and the
## "come and open me" idle animation played once the final boss is down but the reward
## animation has never been triggered: a cartoon left-right rock on the chest's base, a
## slow breathing scale on top of it, and a ring of sparkles around the chest. Together
## they are loud enough that a child cannot miss what to click next.
##
## The two textures have different sizes (the opened one is taller, the carrots stick
## out), so both are aligned on the chest's base instead of on the rect's top-left
## corner: opening the chest grows it upward and never moves or squashes it.

const CLOSED_TEXTURE: Texture2D = preload("res://assets/brain/treasure_closed.png")
const OPENED_TEXTURE: Texture2D = preload("res://assets/brain/treasure_opened.png")
# Rocking: four quick swings, then a pause before the next burst.
const ROCK_ANGLE: float = 0.1
const ROCK_STEP_DURATION: float = 0.12
const ROCK_PAUSE: float = 1.0
# Breathing: a gentle pulse around the authored scale.
const PULSE_RATIO: float = 1.06
const PULSE_DURATION: float = 0.6

# Authored scale, captured before any animation touches it.
var _base_scale: Vector2 = Vector2.ONE
# The chest's base (bottom centre) in parent space, captured from the authored layout.
# Every texture swap realigns the chest on this point.
var _base_anchor: Vector2
var _rock_tween: Tween
var _pulse_tween: Tween

@onready var sparkles: GPUParticles2D = $Sparkles


func _ready() -> void:
	_base_scale = scale
	# Authored with the default top-left pivot, so the base sits one scaled
	# half-width / full-height away from the rect's origin.
	_base_anchor = position + Vector2(size.x * 0.5, size.y) * _base_scale
	_align_on_base()
	sparkles.emitting = false


func is_attracting() -> bool:
	return _rock_tween != null


# Swaps the closed / opened look without moving the chest's base.
func set_opened(opened: bool) -> void:
	texture = OPENED_TEXTURE if opened else CLOSED_TEXTURE
	_align_on_base()


# Centre of the chest as it actually appears on screen, for FX placement. Goes through
# the global transform so the pivot, the authored scale and the animation are all
# accounted for.
func get_visible_center() -> Vector2:
	return get_global_transform() * (size * 0.5)


func start_attract() -> void:
	if is_attracting():
		return
	sparkles.global_position = get_visible_center()
	sparkles.emitting = true

	_rock_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_rock_tween.tween_property(self, "rotation", ROCK_ANGLE, ROCK_STEP_DURATION)
	_rock_tween.tween_property(self, "rotation", -ROCK_ANGLE, ROCK_STEP_DURATION * 2.0)
	_rock_tween.tween_property(self, "rotation", ROCK_ANGLE, ROCK_STEP_DURATION * 2.0)
	_rock_tween.tween_property(self, "rotation", -ROCK_ANGLE, ROCK_STEP_DURATION * 2.0)
	_rock_tween.tween_property(self, "rotation", 0.0, ROCK_STEP_DURATION)
	_rock_tween.tween_interval(ROCK_PAUSE)

	_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", _base_scale * PULSE_RATIO, PULSE_DURATION)
	_pulse_tween.tween_property(self, "scale", _base_scale, PULSE_DURATION)


func stop_attract() -> void:
	sparkles.emitting = false
	if _rock_tween:
		_rock_tween.kill()
		_rock_tween = null
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	rotation = 0.0
	scale = _base_scale


# Fits the rect to the current texture and moves the pivot to the chest's base, then
# shifts the rect so that base lands back on `_base_anchor`. Rotating and scaling from
# there rocks the chest on the ground instead of swinging it around a corner.
func _align_on_base() -> void:
	var texture_size: Vector2 = texture.get_size() if texture else size
	size = texture_size
	pivot_offset = Vector2(texture_size.x * 0.5, texture_size.y)
	# The pivot is the fixed point of the rotation and the scale, so it always ends up
	# at `position + pivot_offset` whatever the animation is currently doing.
	position = _base_anchor - pivot_offset

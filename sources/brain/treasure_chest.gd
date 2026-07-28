class_name TreasureChest
extends TextureRect

## The end-game treasure on the brain screen. Owns its closed / opened look and the
## "come and open me" idle animation played once the final boss is down but the reward
## animation has never been triggered: a cartoon left-right rock on the chest's base, a
## slow breathing scale on top of it, and a ring of sparkles around the chest. Together
## they are loud enough that a child cannot miss what to click next. A child who still
## has not clicked after HAND_DELAY gets the pointing hand faded in on top of all that.
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
# Breathing: a pronounced pulse around the authored scale. It has to carry the "click
# me" on its own, because the chest is small on the brain map and a subtle one reads as
# nothing at all.
const PULSE_RATIO: float = 1.2
const PULSE_DURATION: float = 0.6
# Last resort: after this long without a click, spell it out with the pointing hand,
# faded in slowly so it arrives as a nudge rather than a pop-up.
const HAND_DELAY: float = 5.0
const HAND_FADE_DURATION: float = 3.0

# Authored scale, captured before any animation touches it.
var _base_scale: Vector2 = Vector2.ONE
# The chest's base (bottom centre) in parent space, captured from the authored layout.
# Every texture swap realigns the chest on this point.
var _base_anchor: Vector2
var _rock_tween: Tween
var _pulse_tween: Tween
var _hand_tween: Tween

@onready var button: Button = $TreasureButton
@onready var sparkles: GPUParticles2D = $Sparkles
@onready var pointing_hand: Sprite2D = $PointingHand


func _ready() -> void:
	_base_scale = scale
	# Authored with the default top-left pivot, so the base sits one scaled
	# half-width / full-height away from the rect's origin.
	_base_anchor = position + Vector2(size.x * 0.5, size.y) * _base_scale
	_align_on_base()
	sparkles.emitting = false


func is_attracting() -> bool:
	return _rock_tween != null


# Opens the chest to clicks — and only then advertises them. Setting `disabled` is not
# enough on its own: Godot keeps handing a Control's cursor shape to the viewport while
# it is disabled, so a chest that cannot be opened yet would still turn the pointer into
# a hand and promise a click that does nothing.
func set_clickable(clickable: bool) -> void:
	button.disabled = not clickable
	var cursor: Control.CursorShape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	button.mouse_default_cursor_shape = cursor


# Swaps the closed / opened look without moving the chest's base.
func set_opened(opened: bool) -> void:
	texture = OPENED_TEXTURE if opened else CLOSED_TEXTURE
	_align_on_base()


# Centre of the chest as it actually appears on screen, for FX placement. Goes through
# the global transform so the pivot, the authored scale and the animation are all
# accounted for.
func get_visible_center() -> Vector2:
	return get_global_transform() * (size * 0.5)


# Maps a point given in the chest's own texture coordinates ((0,0) top-left, `size`
# bottom-right) to where it sits on screen when the chest is at rest. The rock and the
# breathing are deliberately left out, so whatever is anchored to the chest stays put
# while the chest moves under it.
func get_resting_point(local_point: Vector2) -> Vector2:
	# The pivot is the fixed point of the resting transform, so everything else is just
	# its offset from the pivot, scaled.
	var resting: Vector2 = _base_anchor + _base_scale * (local_point - pivot_offset)
	var parent_item: CanvasItem = get_parent() as CanvasItem
	return parent_item.get_global_transform() * resting if parent_item else resting


func start_attract() -> void:
	if is_attracting():
		return
	sparkles.global_position = get_visible_center()
	sparkles.emitting = true
	_start_pointing_hand()

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
	_stop_pointing_hand()


# Waits out HAND_DELAY, then fades the hand in over HAND_FADE_DURATION. The hand is
# anchored the way look_and_learn does it — the texture's top-left corner marks the spot
# being pointed at, just behind the fingertip — against the middle of the chest's right
# side, so the finger aims up-left into the chest while the hand itself stays clear of
# both the chest and the name board underneath.
func _start_pointing_hand() -> void:
	pointing_hand.position = get_resting_point(Vector2(size.x, size.y * 0.5))
	pointing_hand.modulate.a = 0.0
	pointing_hand.hide()
	_hand_tween = create_tween()
	_hand_tween.tween_interval(HAND_DELAY)
	_hand_tween.tween_callback(pointing_hand.show)
	_hand_tween.tween_property(pointing_hand, "modulate:a", 1.0, HAND_FADE_DURATION)


func _stop_pointing_hand() -> void:
	if _hand_tween:
		_hand_tween.kill()
		_hand_tween = null
	pointing_hand.hide()
	pointing_hand.modulate.a = 0.0


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

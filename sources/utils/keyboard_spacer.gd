class_name KeyboardSpacer
extends MarginContainer
## Lifts its contents clear of the on-screen keyboard.
##
## Mobile only, and only on a real mobile build: on desktop, on the web and in
## the editor there is no on-screen keyboard, the node never processes, and its
## contents sit exactly where the scene puts them.
##
## It used to add the keyboard's height to its own bottom margin, which shrinks
## the box the contents live in. That moves a form centred in the box -- by half
## the keyboard's height, so not far enough -- and does nothing whatsoever to one
## pinned to the top of it, which is how every sign-up step is laid out. Either
## way the field being typed into stayed under the keyboard, which is what the
## "I can't see what I write any more" report was about.
##
## It now moves its contents up instead: by however much it takes to bring the
## focused control clear of the keyboard, and no further than keeping that same
## control on screen allows.

## The lift in force, in viewport pixels, whenever it changes.
##
## For whatever a screen draws above these contents and would otherwise be run
## into -- the sign-up steps move their question by the same amount.
signal lift_changed(lift: float)

## Left between the focused control and the top of the keyboard.
const CLEARANCE: int = 32

## The margins the scene asked for, which the lift is applied on top of.
var authored_margin_top: int = 0
var authored_margin_bottom: int = 0
var lift: float = 0.0


func _ready() -> void:
	authored_margin_top = get_theme_constant(&"margin_top")
	authored_margin_bottom = get_theme_constant(&"margin_bottom")
	set_process(OS.has_feature("mobile"))


func _process(_delta: float) -> void:
	apply_lift(lift_for(keyboard_height(), get_viewport().gui_get_focus_owner()))


## The keyboard's height in the viewport's own pixels, 0 while it is closed.
##
## DisplayServer reports it in real screen pixels, and the game draws into a
## 2560x1800 reference viewport scaled to fit the screen, so a reported 700 is
## not 700 here. The viewport's final transform is exactly that scaling,
## whatever the device and however the window ends up stretched.
func keyboard_height() -> float:
	var pixels: float = float(DisplayServer.virtual_keyboard_get_height())
	if pixels <= 0.0:
		return 0.0
	var scale: float = get_viewport().get_final_transform().get_scale().y
	if scale <= 0.0:
		return pixels
	return pixels / scale


## How far the contents have to move up for `focused` to be readable over a
## keyboard `keyboard` pixels tall.
##
## Takes its measurements rather than reading them, so it can be checked without
## a device to open a keyboard on. Answers in absolute terms -- it adds the lift
## already in force back before measuring -- so it settles in one step instead of
## creeping up by a little more every frame.
func lift_for(keyboard: float, focused: Control) -> float:
	if keyboard <= 0.0 or not focused or not is_ancestor_of(focused):
		return 0.0

	var field: Rect2 = focused.get_global_rect()
	var keyboard_top: float = get_viewport_rect().size.y - keyboard
	var wanted: float = field.end.y + lift + CLEARANCE - keyboard_top
	# A field pushed off the top of the screen is no more use than one under the
	# keyboard, so that is the ceiling. It only binds on a screen too short to
	# hold both, where the field ends up against the top edge.
	var headroom: float = maxf(0.0, field.position.y + lift - CLEARANCE)
	return clampf(wanted, 0.0, headroom)


## Moves the contents up by `new_lift`, keeping the height the scene gave them.
func apply_lift(new_lift: float) -> void:
	if is_equal_approx(new_lift, lift):
		return
	lift = new_lift
	var shift: int = roundi(lift)
	add_theme_constant_override(&"margin_top", authored_margin_top - shift)
	add_theme_constant_override(&"margin_bottom", authored_margin_bottom + shift)
	lift_changed.emit(lift)

extends GutTest
## The version label, and the ten taps behind it.
##
## Both parts of it have already broken once. The redesign retired the main menu and
## with it the version number, which was the only thing on the first screen a support
## call could ask about. And when the label moved to the login screen it was left as
## a plain Label, which ignores the mouse -- the handler was connected, the taps went
## through to the screen behind, and nothing said so.

const COMPONENT: String = "res://sources/ui/version_label.tscn"
## Every screen that has to show it: the first screen an adult sees, and the one a
## child sees on a device that is already signed in.
const SCREENS: Array[String] = [
	"res://sources/menus/welcome/welcome.tscn",
	"res://sources/menus/login/login.tscn",
]


func _mounted_label() -> VersionLabel:
	var label: VersionLabel = (load(COMPONENT) as PackedScene).instantiate() as VersionLabel
	add_child_autofree(label)
	await get_tree().process_frame
	return label


func test_it_shows_the_build_version() -> void:
	var label: VersionLabel = await _mounted_label()

	assert_eq(label.text, Utils.get_application_version_with_code(),
		"the number a support call asks for")
	assert_ne(label.text, "?", "and it should have been filled in")


func test_it_takes_the_mouse() -> void:
	# The whole bug, in one property: a Label ignores the mouse unless told not to,
	# so the taps never reached the handler.
	var label: VersionLabel = await _mounted_label()

	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_STOP,
		"a Label that ignores the mouse cannot be tapped ten times")


func test_it_takes_ten_taps() -> void:
	var label: VersionLabel = await _mounted_label()
	var now: float = 100.0

	for tap: int in VersionLabel.CLICK_THRESHOLD - 1:
		assert_false(label.register_tap(now), "tap %d should not be enough" % (tap + 1))
		now += 0.1
	assert_true(label.register_tap(now), "the tenth should open the developer settings")


func test_the_count_starts_over_after_it_has_been_used() -> void:
	# Otherwise every tap after the tenth would open it again.
	var label: VersionLabel = await _mounted_label()
	var now: float = 100.0
	for _tap: int in VersionLabel.CLICK_THRESHOLD:
		label.register_tap(now)
		now += 0.1

	assert_false(label.register_tap(now), "the eleventh tap is the first of a new ten")


func test_a_pause_puts_it_back_to_the_start() -> void:
	# What keeps it out of reach of idle prodding: the taps have to be deliberate.
	var label: VersionLabel = await _mounted_label()
	var now: float = 100.0
	for _tap: int in VersionLabel.CLICK_THRESHOLD - 1:
		label.register_tap(now)
		now += 0.1

	now += VersionLabel.CLICK_MAX_DELAY_SECONDS + 0.1
	assert_false(label.register_tap(now), "the pause dropped the nine that came before")
	for tap: int in VersionLabel.CLICK_THRESHOLD - 2:
		now += 0.1
		assert_false(label.register_tap(now), "tap %d of the new run" % (tap + 2))
	now += 0.1
	assert_true(label.register_tap(now), "ten quick ones still get there")


func test_every_screen_that_should_show_it_does() -> void:
	for path: String in SCREENS:
		var screen: Node = (load(path) as PackedScene).instantiate()
		var label: VersionLabel = _find_version_label(screen)
		assert_not_null(label, "%s should show the build version" % path.get_file())
		if label:
			# Bottom right on every screen, so it is always in the same place when
			# somebody is told where to look.
			assert_eq(label.anchor_left, 1.0, "%s should anchor it to the right" % path.get_file())
			assert_eq(label.anchor_top, 1.0, "%s should anchor it to the bottom" % path.get_file())
		screen.free()


func test_nothing_sits_on_top_of_it_on_the_welcome_screen() -> void:
	# It was added over a scroll container that fills the screen, and a control in
	# front takes the taps whatever this one's filter says.
	var screen: Control = (load(SCREENS[0]) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var label: VersionLabel = _find_version_label(screen)
	assert_not_null(label)
	if not label:
		return
	assert_eq(_topmost_at(screen, label.get_global_rect().get_center()), label as Control,
		"a tap in the corner should reach the version label")


func _find_version_label(node: Node) -> VersionLabel:
	var found: VersionLabel = node as VersionLabel
	if found:
		return found
	for child: Node in node.get_children():
		found = _find_version_label(child)
		if found:
			return found
	return null


## The control a tap at this point would land on: the last one drawn wins.
func _topmost_at(node: Node, point: Vector2) -> Control:
	var children: Array[Node] = node.get_children()
	children.reverse()
	for child: Node in children:
		var deeper: Control = _topmost_at(child, point)
		if deeper:
			return deeper
	var control: Control = node as Control
	if control and control.is_visible_in_tree() \
			and control.mouse_filter == Control.MOUSE_FILTER_STOP \
			and control.get_global_rect().has_point(point):
		return control
	return null

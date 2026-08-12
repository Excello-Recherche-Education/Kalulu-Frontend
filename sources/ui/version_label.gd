class_name VersionLabel
extends Label
## The build version, and the only way in to the developer settings.
##
## Ten quick taps on it opens them. That is deliberately undiscoverable: there is no
## button for it anywhere, because a child on a shared device must not find it, and
## the people who need it are told about it.
##
## The taps have to be quick -- a pause resets the count -- so idle prodding at the
## corner of the screen does not eventually get there.

## Where the taps lead, and how the way back is remembered.
const DEVELOPER_SCENE_PATH: String = "res://sources/menus/settings/developer_settings.tscn"
const CLICK_THRESHOLD: int = 10
const CLICK_MAX_DELAY_SECONDS: float = 0.6

var click_count: int = 0
var last_click_seconds: float = 0.0


func _ready() -> void:
	text = Utils.get_application_version_with_code()
	# A Label ignores the mouse, and that is exactly how this went quiet once: the
	# handler was connected, the taps landed on whatever was behind it, and nothing
	# said so. Set here rather than in the scene so every instance has it.
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if not button or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if register_tap(Time.get_ticks_msec() / 1000.0):
		_open_developer_settings()


## Counts one tap, and says whether it completed the sequence.
##
## Takes the time rather than reading the clock so the counting can be tested
## without waiting on one.
func register_tap(now_seconds: float) -> bool:
	if now_seconds - last_click_seconds <= CLICK_MAX_DELAY_SECONDS:
		click_count += 1
	else:
		click_count = 1
	last_click_seconds = now_seconds
	if click_count < CLICK_THRESHOLD:
		return false
	click_count = 0
	return true


func _open_developer_settings() -> void:
	Log.info("VersionLabel: Developer click threshold reached, opening the developer settings")
	await OpeningCurtain.close()
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		Log.error("VersionLabel: No current scene, the developer settings will have nowhere to return to")
	DeveloperSettings.return_path = current_scene.scene_file_path if current_scene else ""
	get_tree().change_scene_to_file(DEVELOPER_SCENE_PATH)

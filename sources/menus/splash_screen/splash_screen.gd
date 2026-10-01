extends Control
## The Kalulu splash, shown on every launch.
##
## Where it goes next is EntryFlow's decision: Kalulu's spoken greeting when the
## language pack can play it, otherwise straight on to the welcome or
## access-code screen.
##
## The next screen is loaded on a background thread while the splash is showing,
## so leaving it does not freeze on a synchronous load. The splash is light enough
## that holding it and the next scene at once is no memory concern, unlike the
## transitions SceneLoader handles.

var is_leaving: bool = false
## The scene being loaded in the background, or "" when that could not start.
var _preloaded_scene_path: String = ""


func _ready() -> void:
	var next: String = EntryFlow.scene_after_splash()
	var error: Error = ResourceLoader.load_threaded_request(next)
	if error != OK:
		Log.warn("SplashScreen: Could not start loading %s in the background (error %s)" % [next, error_string(error)])
		return
	_preloaded_scene_path = next


func _go_to_next_scene() -> void:
	# The timer and a tap race each other, and both lead here.
	if is_leaving:
		return
	is_leaving = true
	# Asked again rather than trusted from _ready: should the answer have changed
	# while the splash was up, the screen it now names is the right one.
	var next: String = EntryFlow.scene_after_splash()
	Log.info("SplashScreen: Changing scene to %s" % next)
	var packed_scene: PackedScene = await _take_preloaded_scene(next)
	var error: Error
	if packed_scene:
		error = get_tree().change_scene_to_packed(packed_scene)
	else:
		error = get_tree().change_scene_to_file(next)
	if error != OK:
		Log.error("SplashScreen: Error while leaving the splash: " + str(error))
		is_leaving = false


## The background-loaded scene for `scene_path`, waiting for it if a tap came
## before the load finished, or null when it was not preloaded or failed to load.
func _take_preloaded_scene(scene_path: String) -> PackedScene:
	if _preloaded_scene_path != scene_path:
		return null
	_preloaded_scene_path = ""
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		Log.warn("SplashScreen: Background load of %s failed (status %d); loading it directly" % [scene_path, status])
		return null
	return ResourceLoader.load_threaded_get(scene_path) as PackedScene


func _on_timer_timeout() -> void:
	_go_to_next_scene()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		_go_to_next_scene()


func _on_timer_ready() -> void:
	Log.info("SplashScreen: Starting timer")

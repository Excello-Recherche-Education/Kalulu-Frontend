extends Control
## The Kalulu splash, shown on every launch.
##
## Where it goes next is EntryFlow's decision: Kalulu's spoken greeting when the
## language pack can play it, otherwise straight on to the welcome or
## access-code screen.

var is_leaving: bool = false


func _go_to_next_scene() -> void:
	# The timer and a tap race each other, and both lead here.
	if is_leaving:
		return
	is_leaving = true
	var next: String = EntryFlow.scene_after_splash()
	Log.info("SplashScreen: Changing scene to %s" % next)
	var error: Error = get_tree().change_scene_to_file(next)
	if error != OK:
		Log.error("SplashScreen: Error while leaving the splash: " + str(error))
		is_leaving = false


func _on_timer_timeout() -> void:
	_go_to_next_scene()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		_go_to_next_scene()


func _on_timer_ready() -> void:
	Log.info("SplashScreen: Starting timer")

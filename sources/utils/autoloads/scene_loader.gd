extends Node
## Scene changer that keeps peak memory low on low-end devices.
##
## [method SceneTree.change_scene_to_file] loads the new scene while the old
## one is still fully resident, so transitions between heavy scenes (gardens,
## minigames) momentarily need the memory of both — enough to OOM-crash old
## tablets. This helper frees the current scene first, then streams the new
## scene from disk on a background thread so the main thread keeps rendering
## frames instead of freezing.
##
## Callers are expected to have covered the screen (OpeningCurtain closed)
## before calling [method change_scene]; the curtain stays visible while the
## tree has no current scene.

## Scene shown if the requested scene fails to load, so the player is never
## stuck on a black screen.
const FALLBACK_SCENE_PATH: String = "res://sources/menus/main/main_menu.tscn"

var _is_changing: bool = false


func change_scene(scene_path: String) -> void:
	if _is_changing:
		Log.warn("SceneLoader: Change to %s requested while another change is in progress; ignoring" % scene_path)
		return
	if not ResourceLoader.exists(scene_path):
		Log.error("SceneLoader: Scene does not exist: %s" % scene_path)
		return
	_is_changing = true
	# Defer so the calling scene is never freed while one of its methods is
	# still on the stack.
	_change_scene_deferred.call_deferred(scene_path)


func _change_scene_deferred(scene_path: String) -> void:
	var tree: SceneTree = get_tree()
	# Free the old scene before loading the new one: this roughly halves the
	# memory peak of the transition.
	if tree.current_scene:
		tree.unload_current_scene()
	var error: Error = ResourceLoader.load_threaded_request(scene_path)
	if error != OK:
		Log.error("SceneLoader: Could not start loading %s (error %s)" % [scene_path, error_string(error)])
		_finish_with_fallback(tree, scene_path)
		return
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		Log.error("SceneLoader: Failed to load %s (status %d)" % [scene_path, status])
		_finish_with_fallback(tree, scene_path)
		return
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if not packed_scene:
		Log.error("SceneLoader: %s is not a PackedScene" % scene_path)
		_finish_with_fallback(tree, scene_path)
		return
	error = tree.change_scene_to_packed(packed_scene)
	if error != OK:
		Log.error("SceneLoader: Could not change to %s (error %s)" % [scene_path, error_string(error)])
		_finish_with_fallback(tree, scene_path)
		return
	_is_changing = false


func _finish_with_fallback(tree: SceneTree, failed_scene_path: String) -> void:
	_is_changing = false
	if failed_scene_path != FALLBACK_SCENE_PATH:
		tree.change_scene_to_file(FALLBACK_SCENE_PATH)

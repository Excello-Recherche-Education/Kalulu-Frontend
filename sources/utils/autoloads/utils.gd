extends Node

const SUPPORTED_LOCALES: Dictionary[String, String] = {
	"fr_FR": "Français (France)",
	"es_AR": "Español (Argentina)",
	"es_UY": "Español (Uruguay)",
	"es_CO": "Español (Colombia)",
	"pt_BR": "Português (Brasil)",
	"es_DO": "Español (República Dominicana)",
	"it_IT": "Italiano (Italia) (BETA)",
}
const RESERVED_FILE_NAMES: Array[String] = [
	"CON", "PRN", "AUX", "NUL",
	"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
	"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
]
const INVALID_FILE_CHARS: Array[String] = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]


func reorder_children_by_property(container: Node, property_name: String) -> void:
	var children: Array[Node] = container.get_children()
	children.sort_custom(Utils.sort_by_property.bind(property_name))
	for element: Node in children:
		container.remove_child(element)
	for element: Node in children:
		container.add_child(element)


func sort_by_property(node_a: Node, node_b: Node, property_name: String) -> bool:
	return node_a.get(property_name) < node_b.get(property_name)


func disconnect_all(disconnecting_signal: Signal) -> void:
	for connection: Dictionary in disconnecting_signal.get_connections():
		disconnecting_signal.disconnect(connection["callable"] as Callable)


func round_vec2(vec: Vector2) -> Vector2i:
	return Vector2i(roundi(vec.x), roundi(vec.y))


func safe_dimensions(dimensions: Vector2) -> Vector2:
	return Vector2(maxf(1.0, dimensions.x), maxf(1.0, dimensions.y))


func clamp_position_to_area(tested_position: Vector2, area_size: Vector2, padding: Vector2 = Vector2.ZERO) -> Vector2:
	var safe_size: Vector2 = safe_dimensions(area_size)
	return Vector2(
		clampf(tested_position.x, padding.x, maxf(padding.x, safe_size.x - padding.x)),
		clampf(tested_position.y, padding.y, maxf(padding.y, safe_size.y - padding.y))
	)


func build_probe_offsets(probe_half_size: Vector2) -> Array[Vector2]:
	var offsets: Array[Vector2] = [Vector2.ZERO]
	if probe_half_size == Vector2.ZERO:
		return offsets
	offsets.append_array([
		Vector2(probe_half_size.x, 0.0),
		Vector2(-probe_half_size.x, 0.0),
		Vector2(0.0, probe_half_size.y),
		Vector2(0.0, -probe_half_size.y),
		Vector2(probe_half_size.x, probe_half_size.y),
		Vector2(probe_half_size.x, -probe_half_size.y),
		Vector2(-probe_half_size.x, probe_half_size.y),
		Vector2(-probe_half_size.x, -probe_half_size.y),
	])
	var sample_step: float = maxf(1.0, minf(probe_half_size.x, probe_half_size.y) * 0.5)
	var x_offset: float = -probe_half_size.x
	while x_offset <= probe_half_size.x:
		var y_offset: float = -probe_half_size.y
		while y_offset <= probe_half_size.y:
			offsets.append(Vector2(x_offset, y_offset))
			y_offset += sample_step
		x_offset += sample_step
	return offsets


func position_to_pixel(sample: Vector2, area_size: Vector2, image: Image) -> Vector2i:
	var safe_size: Vector2 = safe_dimensions(area_size)
	var width: float = maxf(1.0, image.get_width())
	var height: float = maxf(1.0, image.get_height())
	var normalized: Vector2 = Vector2(
		clampf(sample.x / safe_size.x, 0.0, 1.0),
		clampf(sample.y / safe_size.y, 0.0, 1.0)
	)
	return Vector2i(int(normalized.x * (width - 1.0)), int(normalized.y * (height - 1.0)))


func clean_dir(path: String) -> Error:
	var dir: DirAccess = DirAccess.open(path)
	var error: Error = DirAccess.get_open_error()
	if error != OK:
		return error
	if dir == null:
		return ERR_FILE_BAD_PATH
	# Hidden files (e.g. .DS_Store created by the macOS Finder) must be removed
	# too, otherwise the directory is never empty and cannot be deleted
	dir.include_hidden = true
	# Best effort: try to remove everything, report the first error encountered
	var first_error: Error = OK
	for file: String in dir.get_files():
		error = dir.remove(file)
		if error != OK and first_error == OK:
			first_error = error
	for subfolder: String in dir.get_directories():
		error = clean_dir(path.path_join(subfolder))
		if error == OK:
			error = dir.remove(subfolder)
		if error != OK and first_error == OK:
			first_error = error
	return first_error


## Recursively deletes the folder at [param path].
## Returns OK on success, or the first error encountered. Callers that replace
## critical data (e.g. the language pack) should check the returned value: a
## non-OK result means the folder may still exist, possibly partially emptied.
func delete_directory_recursive(path: String) -> Error:
	var err: Error = clean_dir(path)
	if err != OK:
		Log.error("Utils: DeleteDirectoryRecursive: Error " + error_string(err) + " while cleaning folder: %s" % path)
		return err
	err = DirAccess.remove_absolute(path)
	if err != OK:
		Log.error("Utils: DeleteDirectoryRecursive: Error " + error_string(err) + " while deleting folder: %s" % path)
	else:
		Log.info("Utils: DeleteDirectoryRecursive: Folder deleted: %s" % path)
	return err


## Returns -1 if version_a is lower than version_b, 0 if they are equals, and 1 if version_a is greater than version_b
func compare_versions(version_a: String, version_b: String) -> int:
	var va: PackedStringArray = version_a.split(".")
	var vb: PackedStringArray = version_b.split(".")
	
	for index: int in range(3):
		var ai: int = int(va[index]) if index < va.size() else 0
		var bi: int = int(vb[index]) if index < vb.size() else 0
		if ai < bi:
			return -1
		elif ai > bi:
			return 1
	return 0


func get_application_config_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func get_application_version_code() -> String:
	var preset: ConfigFile = ConfigFile.new()
	var err: Error = preset.load("res://export_presets.cfg")
	if err == OK:
		return str(preset.get_value("preset.0.options", "version/code", "0"))
	Log.trace("Utils: Failed to load export_presets.cfg")
	return "0"


func get_application_version_with_code() -> String:
	return "%s  (%s)" % [get_application_config_version(), get_application_version_code()]


## A failure, written out so it can be pasted into a mail to somebody who can act.
##
## The message the reader saw, then the two things its recipient asks first: which
## build it came from, and what actually failed. RESULT_TLS_HANDSHAKE_ERROR in
## particular is what tells a network administrator the connection was intercepted
## rather than merely dropped.
##
## The result name is left out when nothing failed at that level -- a report signed
## off with RESULT_SUCCESS underneath a message about a refused connection reads as a
## contradiction, and would be the first thing queried.
func support_report(message: String, result_code: int) -> String:
	var report: String = "%s\n\nKalulu %s" % [message, get_application_version_with_code()]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		report += "\n" + ServerManagerClass.http_result_name(result_code)
	return report


## Labels on an offer to copy, before and just after it is taken.
const COPY_TEXT: String = "COPY_ERROR_MESSAGE"
const COPIED_TEXT: String = "ERROR_MESSAGE_COPIED"
## How long "copied" stays up before the offer comes back.
const COPIED_FEEDBACK_SECONDS: float = 2.5


## Puts a report on the clipboard and confirms it on the button that asked.
##
## Three screens offer this now -- the login, the language pack notice and
## registration -- and the confirmation is the fiddly half: the button has to say
## something happened, and then go back to offering, without assuming it is still
## there when the delay is up.
func copy_report(report: String, button: Button) -> void:
	DisplayServer.clipboard_set(report)
	Log.info("Utils: Copied a support report to the clipboard")
	button.text = COPIED_TEXT
	await get_tree().create_timer(COPIED_FEEDBACK_SECONDS).timeout
	# The screen may have moved on, or gone, while the confirmation was up.
	if is_instance_valid(button):
		button.text = COPY_TEXT


func get_safe_file_path(file_path: String) -> String:
	var dir: String = file_path.get_base_dir()
	var file: String = file_path.get_file()
	var base: String = file.get_basename()
	var ext: String = file.get_extension()
	
	for chara: String in INVALID_FILE_CHARS:
		base = base.replace(chara, "_")
	
	var modified: bool = false
	if base.to_upper() in RESERVED_FILE_NAMES:
		base = "_" + base
		modified = true
	
	var new_name: String = "%s.%s" % [base, ext] if ext != "" else base
	var new_path: String = dir.path_join(new_name) if dir != "" else new_name
	
	if modified or new_path != file_path:
		Log.trace("Utils: GetSafeFilePath: Renamed invalid file path: '%s' → '%s'" % [file_path, new_path])
	
	return new_path


func get_animation_duration(sprite: AnimatedSprite2D, anim_name: String) -> float:
	if sprite == null:
		Log.warn("Utils: get_animation_duration(): Sprite AnimatedSprite2D is null.")
		return 0.0
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		Log.warn("Utils: get_animation_duration(): sprite_frames is null for %s." % sprite.name)
		return 0.0
	if not frames.has_animation(anim_name):
		Log.warn("Utils: get_animation_duration(): Animation '%s' does not exists in %s." % [anim_name, sprite.name])
		return 0.0
	var frame_count: int = frames.get_frame_count(anim_name)
	var speed: float = frames.get_animation_speed(anim_name)
	if speed <= 0:
		Log.warn("Utils: get_animation_duration(): Animation '%s' has an invalid speed (%s)." % [anim_name, speed])
		return 0.0
	var base_duration: float = frame_count / speed
	if sprite.speed_scale == 0:
		Log.warn("Utils: get_animation_duration(): Sprite '%s' has a speed_scale of zero." % [sprite.name, sprite.speed_scale])
		return 0.0
	return base_duration / sprite.speed_scale

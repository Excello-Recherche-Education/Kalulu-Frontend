extends SceneTree
## Writes MenuTheme.build() out to MenuTheme.THEME_PATH.
##
## The redesigned menus' theme is generated rather than hand edited so it can
## never drift from the Design tokens. Run this after changing a token:
##
##     godot --headless --path . --script sources/ui/menu_theme_generator.gd
##
## then commit the regenerated resource alongside the token change.


func _init() -> void:
	var theme: Theme = MenuTheme.build()
	var uid: String = _existing_uid()
	var directory: String = MenuTheme.THEME_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var make_error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK:
			printerr("Could not create %s: %s" % [directory, error_string(make_error)])
			quit(1)
			return

	# Saved without FLAG_BUNDLE_RESOURCES: the style boxes are unsaved resources
	# so they inline as sub-resources anyway, while the fonts and the chevron
	# icon stay ext_resource references instead of being embedded as base64.
	var error: Error = ResourceSaver.save(theme, MenuTheme.THEME_PATH)
	if error != OK:
		printerr("Could not save %s: %s" % [MenuTheme.THEME_PATH, error_string(error)])
		quit(1)
		return

	_restore_uid(uid)
	print("Wrote %s" % MenuTheme.THEME_PATH)
	quit()


## The uid to stamp on the resource: the one it already carries, or a new one.
##
## ResourceSaver does not write a uid of its own, yet the editor assigns one the
## first time it opens the resource -- which would show up as an unexplained
## diff on a generated file. Minting the uid here and carrying it across
## regenerations makes this script idempotent instead.
func _existing_uid() -> String:
	if FileAccess.file_exists(MenuTheme.THEME_PATH):
		var file: FileAccess = FileAccess.open(MenuTheme.THEME_PATH, FileAccess.READ)
		if file:
			var header: String = file.get_line()
			file.close()
			var found: RegExMatch = _uid_regex().search(header)
			if found:
				return found.get_string(1)
	return ResourceUID.id_to_text(ResourceUID.create_id())


func _restore_uid(uid: String) -> void:
	if uid.is_empty():
		return
	var file: FileAccess = FileAccess.open(MenuTheme.THEME_PATH, FileAccess.READ)
	if not file:
		return
	var content: String = file.get_as_text()
	file.close()
	if _uid_regex().search(content.get_slice("\n", 0)):
		return
	content = content.replace("[gd_resource ", "[gd_resource uid=\"%s\" " % uid)
	file = FileAccess.open(MenuTheme.THEME_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(content)
	file.close()


func _uid_regex() -> RegEx:
	var regex: RegEx = RegEx.new()
	regex.compile("uid=\"(uid://[^\"]+)\"")
	return regex

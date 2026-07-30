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

	print("Wrote %s" % MenuTheme.THEME_PATH)
	quit()

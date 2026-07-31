extends GutTest
## Every icon-only button centres its icon.
##
## Button.icon_alignment defaults to LEFT, so a button with an icon and no text
## pins the glyph to its left edge. On a round icon button that reads as the icon
## having slid out of its circle, which is how it was reported. Nothing errors, so
## only a check like this catches it.
##
## Done by reading the scene files rather than instantiating them: this has to
## cover every scene in the project, and instantiating arbitrary screens would run
## their _ready and hit the network and the database.

const SOURCES_DIR: String = "res://sources"
const ICON_BUTTON_VARIATIONS: Array[String] = ["IconButtonLight", "IconButtonDark"]
## HORIZONTAL_ALIGNMENT_CENTER / VERTICAL_ALIGNMENT_CENTER.
const CENTRED: String = "1"


func test_every_round_icon_button_centres_its_icon() -> void:
	var offenders: Array[String] = []
	var checked: int = 0
	for path: String in _scene_paths(SOURCES_DIR):
		for block: String in _node_blocks(path):
			if not _uses_icon_button_variation(block):
				continue
			checked += 1
			var name: String = _node_name(block)
			if _property(block, "icon_alignment") != CENTRED:
				offenders.append("%s / %s (icon_alignment)" % [path.get_file(), name])
			elif _property(block, "vertical_icon_alignment") != CENTRED:
				offenders.append("%s / %s (vertical_icon_alignment)" % [path.get_file(), name])

	assert_gt(checked, 0, "the check should have found some icon buttons to inspect")
	assert_eq(offenders, [] as Array[String],
		"these icon buttons would draw their icon off to one side: %s" % ", ".join(offenders))


func _scene_paths(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	if not dir:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = directory.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_scene_paths(full))
		elif entry.ends_with(".tscn"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


## The scene's `[node ...]` sections, header and properties together.
func _node_blocks(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	var text: String = file.get_as_text()
	file.close()
	var blocks: Array[String] = []
	for chunk: String in text.split("\n[node "):
		if not chunk.begins_with("name="):
			continue
		blocks.append("[node " + chunk.split("\n[")[0])
	return blocks


func _uses_icon_button_variation(block: String) -> bool:
	for variation: String in ICON_BUTTON_VARIATIONS:
		if block.contains('theme_type_variation = &"%s"' % variation):
			return true
	return false


func _node_name(block: String) -> String:
	var found: RegExMatch = _regex('name="([^"]+)"').search(block)
	return found.get_string(1) if found else "?"


func _property(block: String, key: String) -> String:
	# Anchored to a line start so vertical_icon_alignment is not mistaken for
	# icon_alignment, which it ends with.
	var found: RegExMatch = _regex("(?m)^%s = (\\S+)" % key).search(block)
	return found.get_string(1) if found else ""


func _regex(pattern: String) -> RegEx:
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	return regex

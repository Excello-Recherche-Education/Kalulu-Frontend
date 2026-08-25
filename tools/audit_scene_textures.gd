extends Node

## Reports every texture a scene pulls in, transitively, with its imported size.
## Used to check what the boss minigame actually costs to load.
##
##   godot --headless --path <project> res://tools/audit_scene_textures.tscn

const SCENES: Array[String] = [
	"res://sources/minigames/boss/boss_minigame.tscn",
]


func _ready() -> void:
	for scene: String in SCENES:
		var seen: Dictionary = {}
		_walk(scene, seen)
		var rows: Array = []
		var total: int = 0
		for path: String in seen:
			if not path.ends_with(".png") and not path.ends_with(".jpg"):
				continue
			var size: int = _imported_size(path)
			total += size
			rows.append([size, path])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		print("\n=== ", scene, " ===")
		for row: Array in rows:
			print("%8.2f MB  %s" % [float(row[0]) / 1048576.0, row[1]])
		print("--------")
		print("%8.2f MB  TOTAL across %d textures" % [float(total) / 1048576.0, rows.size()])
	get_tree().quit()


func _walk(path: String, seen: Dictionary) -> void:
	if seen.has(path):
		return
	seen[path] = true
	for dependency: String in ResourceLoader.get_dependencies(path):
		# Entries look like "uid://abc::Texture2D::res://path.png"; the real path
		# is the last segment.
		var parts: PackedStringArray = dependency.split("::")
		var resolved: String = parts[parts.size() - 1]
		if resolved.is_empty():
			continue
		if not ResourceLoader.exists(resolved):
			continue
		_walk(resolved, seen)


func _imported_size(path: String) -> int:
	# Read the .import remap to find the .ctex Godot actually loads.
	var import_path: String = path + ".import"
	if not FileAccess.file_exists(import_path):
		return 0
	var config: ConfigFile = ConfigFile.new()
	if config.load(import_path) != OK:
		return 0
	# VRAM-compressed textures have no single "path": they remap to one file per
	# platform (path.s3tc, path.etc2, ...). Take the largest, which is what a
	# device actually loads, rather than summing every platform variant.
	var candidates: Array = []
	var single: String = String(config.get_value("remap", "path", ""))
	if not single.is_empty():
		candidates.append(single)
	else:
		var dest_files: Variant = config.get_value("deps", "dest_files", [])
		for entry: String in dest_files:
			candidates.append(entry)

	var size: int = 0
	for candidate: String in candidates:
		var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
		if not file:
			continue
		size = maxi(size, file.get_length())
		file.close()
	return size

extends Control

const downloader_scene_path: = "res://sources/menus/language_selection/package_downloader.tscn"
const main_scene_path: = "res://sources/menus/minigame_selection.tscn"
const packages: = [{package = "french.zip", locale = "fr", language = "french"},
	{package = "brazilian.zip", locale = "pt", language = "brazilian"}]

@onready var button_container: = $VBoxContainer


func _ready() -> void:
	for package in packages:
		var package_name: String = package.package
		var package_path: = "user://" + package_name
		if FileAccess.file_exists(package_path):
			_use_package(package)
			break
	
	var children: = button_container.get_children()
	for i in children.size():
		var child: Button = children[i]
		child.pressed.connect(_on_button_pressed.bind(i))


func _on_button_pressed(button_id: int) -> void:
	var package: Dictionary = packages[button_id]
	var package_name: String = package.package
	var package_path: = "user://" + package_name
	if not FileAccess.file_exists(package_path):
		print("Package not found, download it from the server")
		var downloader: Control = load(downloader_scene_path).instantiate()
		add_child(downloader)
		downloader.download_package(package_name)
		await downloader.completed
		downloader.queue_free()
	if not FileAccess.file_exists(package_path):
		push_error("Package not found after trying to download")
	_use_package(package)


func _use_package(package: Dictionary) -> void:
	var package_name: String = package.package
	var package_path: = "user://" + package_name
	if not OS.has_feature("editor"):
		ProjectSettings.load_resource_pack(package_path, false)
	TranslationServer.set_locale(package.locale)
	Database.language = package.language
	_add_translation_remaps(package)
	get_tree().change_scene_to_file(main_scene_path)


func _add_translation_remaps(package: Dictionary) -> void:
	var translation_remaps: Dictionary = ProjectSettings.get_setting("internationalization/locale/translation_remaps")
	
	var directory_list: Array[String] = [Database.base_path + package.language + "/minigames"]
	while not directory_list.is_empty():
		var dir_path: String = directory_list.pop_back()
		var directory: = DirAccess.open(dir_path)
		if directory:
			directory.list_dir_begin()
			var file_name = directory.get_next()
			while file_name != "":
				var path_to_file: String = directory.get_current_dir(false) + "/" + file_name
				if directory.current_is_dir():
					directory_list.append(path_to_file)
				elif path_to_file.ends_with(".import"):
					path_to_file = path_to_file.trim_suffix(".import")
					var path_to_file_original: = path_to_file.replace(Database.base_path + package.language, Database.base_path + "french")
					if not translation_remaps.has(path_to_file_original):
						translation_remaps[path_to_file_original] = PackedStringArray()
					var translation_remap: String = path_to_file + ":" + package.locale
					if not translation_remaps[path_to_file_original].has(translation_remap):
						translation_remaps[path_to_file_original].append(translation_remap)
				file_name = directory.get_next()
	
	ProjectSettings.set_setting("internationalization/locale/translation_remaps", translation_remaps)

		

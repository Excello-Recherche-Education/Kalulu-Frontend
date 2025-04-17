@tool
extends EditorExportPlugin

var tool_configs: Dictionary = {
	"game": {
		"main_scene": "res://sources/menus/splash_screen/splash_screen.tscn",
		"output_name": "kalulu_app"
	},
	"prof_tool": {
		"main_scene": "res://sources/language_tool/prof_tool_menu.tscn",
		"output_name": "prof_tool"
	}
}

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	# Récupère la sélection depuis EditorSettings dynamiquement
	var editor_settings: EditorSettings = EditorPlugin.new().get_editor_interface().get_editor_settings()
	var selected_tool: String = "game"

	if editor_settings.has_setting("export_tool_manager/current_tool"):
		selected_tool = str(editor_settings.get_setting("export_tool_manager/current_tool")).strip_edges()

	if selected_tool == "" or not tool_configs.has(selected_tool):
		push_error("Outil '%s' non défini dans la configuration." % selected_tool)
		return

	var config = tool_configs[selected_tool]

	# 1. Met à jour la scène principale
	ProjectSettings.set_setting("application/run/main_scene", config["main_scene"])
	ProjectSettings.save()

	if selected_tool == "game":
		print("[Export Tool Plugin] Export mode = game: nothing will be changed")
		return
	elif selected_tool == "prof_tool":
		print("[Export Tool Plugin] Export mode = prof_tool: plugin will rename the exported file")
		call_deferred("_postprocess_dmg", path, config["output_name"])
	else:
		push_error("[Export Tool Plugin] Export mode = %s: This is not a known mode, nothing will be changed" % selected_tool)
		return


func _wait_for_file(path: String, timeout_sec: float) -> void:
	var time: float = 0.0
	while not FileAccess.file_exists(path) and time < timeout_sec:
		await Engine.get_main_loop().process_frame
		time += 1.0 / ProjectSettings.get_setting("physics/common/physics_fps", 60)


func _postprocess_dmg(dmg_path: String, new_app_name: String) -> void:
	await _wait_for_file(dmg_path, 25.0)
	
	var dmg_dir: String = dmg_path.get_base_dir()
	var temp_dir: String = dmg_dir.path_join("temp_export_dmg")
	var temp_app_name: String = "%s.app" % new_app_name
	var temp_dmg_path: String = dmg_dir.path_join("%s.dmg" % new_app_name)

	# 1. Créer dossier temporaire
	DirAccess.make_dir_recursive_absolute(temp_dir)

	# 2. Monter l'ancien .dmg
	var mount_point: String = "/Volumes/KALULU_TEMP"
	var output: Array = []
	var mount_result = OS.execute("hdiutil", ["attach", dmg_path, "-mountpoint", mount_point, "-nobrowse", "-readonly"], output)
	if mount_result != 0:
		push_error("Échec du montage du .dmg : " + str(output))
		return

	# 3. Copier l'app depuis le dmg dans temp_dir
	var original_app_path: String = mount_point.path_join("kalulu.app")
	output.clear()
	var copy_result: int = OS.execute("cp", ["-R", original_app_path, temp_dir.path_join(temp_app_name)], output)
	if copy_result != 0:
		push_error("Échec de la copie de l'app : " + str(output))
		return

	# 4. Démonter le .dmg original
	OS.execute("hdiutil", ["detach", mount_point], output)

	# 5. Recréer un .dmg avec le bon nom
	output.clear()
	var create_result = OS.execute("hdiutil", [
		"create",
		"-volname", new_app_name,
		"-srcfolder", temp_dir,
		"-ov",
		"-format", "UDZO",
		temp_dmg_path
	], output)

	if create_result != 0:
		push_error("Échec de la création du nouveau .dmg : " + str(output))
		return

	# 6. Nettoyage et renommage final
	DirAccess.remove_absolute(dmg_path)

	var final_dmg_path := dmg_dir.path_join("%s.dmg" % new_app_name)
	var rename_result := DirAccess.rename_absolute(temp_dmg_path, final_dmg_path)
	if rename_result != OK:
		push_error("Échec du renommage final du .dmg")

	_cleanup_mounted_volumes(new_app_name)
	OS.move_to_trash(temp_dir)


func _cleanup_mounted_volumes(volume_name: String) -> void:
	var output := []
	var result := OS.execute("hdiutil", ["info"], output)
	if result != 0:
		push_warning("Impossible de récupérer la liste des volumes montés")
		return

	if output.size() == 0:
		return

	var lines: PackedStringArray = output[0].split("\n")
	for line in lines:
		if line.find(volume_name) != -1:
			var match := line.strip_edges()
			var path := match.split("\t")[-1]
			if path.begins_with("/Volumes/"):
				var detach_result := OS.execute("hdiutil", ["detach", path])
				if detach_result != 0:
					push_warning("Échec du démontage de : " + path)

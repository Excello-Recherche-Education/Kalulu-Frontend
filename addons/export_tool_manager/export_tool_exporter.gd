@tool
extends EditorExportPlugin

var tool_configs := {
	"game": {
		"main_scene": "res://sources/menus/splash_screen/splash_screen.tscn",
		"output_name": "kalulu"
	},
	"prof_tool": {
		"main_scene": "res://sources/language_tool/prof_tool_menu.tscn",
		"output_name": "prof_tool"
	}
}

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	# Récupère la sélection depuis EditorSettings dynamiquement
	var editor_settings := EditorPlugin.new().get_editor_interface().get_editor_settings()
	var selected_tool := "game"

	if editor_settings.has_setting("export_tool_manager/current_tool"):
		selected_tool = str(editor_settings.get_setting("export_tool_manager/current_tool")).strip_edges()

	if selected_tool == "" or not tool_configs.has(selected_tool):
		push_error("Outil '%s' non défini dans la configuration." % selected_tool)
		return

	var config = tool_configs[selected_tool]

	# 1. Met à jour la scène principale
	ProjectSettings.set_setting("application/run/main_scene", config["main_scene"])
	ProjectSettings.save()

	# 2. Gère le renommage du fichier exporté
	var new_path := _get_output_path(path, config["output_name"])
	call_deferred("_rename_exported_file", path, new_path)

func _get_output_path(original_path: String, new_name: String) -> String:
	var dir := original_path.get_base_dir()
	var ext := original_path.get_extension()
	var suffix: String = "." + ext
	return dir + "/" + new_name + suffix

func _rename_exported_file(old_path: String, new_path: String) -> void:
	await _wait_for_file(old_path, 25.0)

	if FileAccess.file_exists(old_path):
		var result := DirAccess.rename_absolute(old_path, new_path)
		if result == OK:
			print("✅ Export renommé : ", new_path)
		else:
			push_error("❌ Échec du renommage de : " + old_path)
	else:
		push_error("❌ Fichier exporté introuvable après 25s : " + old_path)

func _wait_for_file(path: String, timeout_sec: float) -> void:
	var t := 0.0
	while not FileAccess.file_exists(path) and t < timeout_sec:
		await Engine.get_main_loop().process_frame
		t += 1.0 / ProjectSettings.get_setting("physics/common/physics_fps", 60)

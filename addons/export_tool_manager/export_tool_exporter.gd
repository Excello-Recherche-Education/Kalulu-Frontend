@tool
extends EditorExportPlugin

# Config par outil
var tool_configs := {
	"game": {
		"main_scene": "res://main_game.tscn",
		"output_name": "kalulu"
	},
	"prof_tool": {
		"main_scene": "res://tools/prof_tool/main.tscn",
		"output_name": "prof_tool"
	}
}

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	var selected_tool = EditorInterface.get_editor_settings().get_setting("export_tool_manager/current_tool") as String
	if selected_tool == "" or not tool_configs.has(selected_tool):
		push_error("Outil '%s' introuvable dans la configuration." % selected_tool)
		return

	var config = tool_configs[selected_tool]

	# 1. Mettre à jour la scène principale
	ProjectSettings.set_setting("application/run/main_scene", config["main_scene"])
	ProjectSettings.save()

	# 2. Déterminer le nouveau nom de fichier
	var new_path = _get_output_path(path, config["output_name"])
	call_deferred("_rename_exported_file", path, new_path)

func _get_output_path(original_path: String, new_name: String) -> String:
	var dir = original_path.get_base_dir()
	var ext = original_path.get_extension()
	var suffix: String = "." + ext
	return dir.plus_file(new_name + suffix)

func _rename_exported_file(old_path: String, new_path: String) -> void:
	if FileAccess.file_exists(old_path):
		var success = DirAccess.rename_absolute(old_path, new_path)
		if success == OK:
			print("✅ Export renommé : ", new_path)
		else:
			push_error("❌ Échec du renommage : ", old_path)
	else:
		push_error("❌ Fichier exporté introuvable : " + old_path)

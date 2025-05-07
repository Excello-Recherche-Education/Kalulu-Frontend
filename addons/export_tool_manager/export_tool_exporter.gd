@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "KaluluExportToolExporter"

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
	var editor_settings: EditorSettings = EditorPlugin.new().get_editor_interface().get_editor_settings()
	var selected_tool: String = "game"

	if editor_settings.has_setting("export_tool_manager/current_tool"):
		selected_tool = str(editor_settings.get_setting("export_tool_manager/current_tool")).strip_edges()

	if selected_tool == "" or not tool_configs.has(selected_tool):
		push_error("Outil '%s' non défini dans la configuration." % selected_tool)
		return

	var config = tool_configs[selected_tool]
	ProjectSettings.set_setting("application/run/main_scene", config["main_scene"])
	ProjectSettings.save()

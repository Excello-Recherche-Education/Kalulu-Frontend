@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "KaluluExportToolExporter"

var tool_configs: Dictionary[String, Dictionary] = {
	"game": {
		"name": "Kalulu",
		"main_scene": "res://sources/menus/splash_screen/splash_screen.tscn",
		"icon": "res://assets/kalulu_icon.png",
		"output_name": "Kalulu"
	},
	"prof_tool": {
		"name": "Prof_Tool",
		"main_scene": "res://sources/language_tool/prof_tool_menu.tscn",
		"icon": "res://assets/prof_tool_icon.png",
		"output_name": "Prof_Tool"
	}
}

func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	var editor_settings: EditorSettings = EditorPlugin.new().get_editor_interface().get_editor_settings()
	var selected_tool: String = "game"

	if editor_settings.has_setting("export_tool_manager/current_tool"):
		selected_tool = str(editor_settings.get_setting("export_tool_manager/current_tool")).strip_edges()

	if selected_tool == "" or not tool_configs.has(selected_tool):
		push_error("Tool '%s' is not defined in the configuration." % selected_tool)
		return

	var config: Dictionary = tool_configs[selected_tool]
	ProjectSettings.set_setting("application/config/name", config["name"])
	ProjectSettings.set_setting("application/run/main_scene", config["main_scene"])
	ProjectSettings.set_setting("application/config/icon", config["icon"])
	ProjectSettings.save()

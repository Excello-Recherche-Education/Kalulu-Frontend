@tool
extends EditorPlugin

const EXPORTER_PATH: String = "res://addons/export_tool_manager/export_tool_exporter.gd"

var tool_selector: OptionButton
var exporter_plugin: EditorExportPlugin
var export_button: Button

func _enter_tree() -> void:
	# Tool Selector UI
	tool_selector = OptionButton.new()
	tool_selector.name = "Tool Exporter"
	tool_selector.add_item("Game")
	tool_selector.add_item("Prof Tool")
	tool_selector.connect("item_selected", _on_tool_selected)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)

	var settings: EditorSettings = get_editor_interface().get_editor_settings()
	var current: Variant = settings.get_setting("export_tool_manager/current_tool")
	var current_tool: String = "game"

	if typeof(current) == TYPE_STRING and current.strip_edges() != "":
		current_tool = current.strip_edges()

	match current_tool:
		"prof_tool":
			tool_selector.select(1)
		"game", _:
			tool_selector.select(0)

	# Exporter plugin
	exporter_plugin = load(EXPORTER_PATH).new()
	add_export_plugin(exporter_plugin)

	# Export All Button
	export_button = Button.new()
	export_button.text = "Export All (Game)"
	export_button.pressed.connect(_on_export_all_game_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, export_button)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)
	tool_selector.queue_free()

	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, export_button)
	export_button.queue_free()

	remove_export_plugin(exporter_plugin)

func _on_tool_selected(index: int) -> void:
	var tool: String = "game"
	match index:
		1:
			tool = "prof_tool"
		0, _:
			tool = "game"

	var settings: EditorSettings = get_editor_interface().get_editor_settings()
	settings.set_setting("export_tool_manager/current_tool", tool)

func _on_export_all_game_pressed() -> void:
	export_all_game_presets()

func export_all_game_presets() -> void:
	var godot_path: String = OS.get_executable_path()
	var exportFolder: String = "../Export/autobuilds/"
	var presets: Dictionary[String, String]= {
		"Android Kalulu AAB": "/Android/kalulu_app.aab",
		"Android Kalulu APK": "/Android/kalulu_app.apk",
		"Android Kalulu APK 32 bits": "/Android/kalulu_app_32.apk",
		"Windows Kalulu": "/Windows/Kalulu-Windows.zip",
		"Linux Kalulu": "/Linux/Kalulu-Linux.zip",
		
		# Apple in last because it's always the most complicated
		#"iOS Kalulu": "/iOS/KaluluApp.ipa",
		#"macOS Kalulu": "/macOS/Kalulu-macOS.dmg"
	}

	for preset_name in presets.keys():
		await get_tree().create_timer(1).timeout
		var output_path: String = exportFolder + get_application_version_with_code() + presets[preset_name]
		print("Start exporting " + preset_name)
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())

		var args: PackedStringArray = ["--headless", "--export-release", preset_name, output_path]
		var output: Array[String] = []
		var result: int = OS.execute(godot_path, args, output, true)

		if result != OK:
			push_error("Export failed for %s (%s)\nOutput:\n%s" % [
				preset_name, output_path, "\n".join(PackedStringArray(output))
			])
			return
		else:
			print("✔ Export success: %s → %s" % [preset_name, output_path])


func get_application_config_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func get_application_version_code() -> String:
	var preset: ConfigFile = ConfigFile.new()
	var err: Error = preset.load("res://export_presets.cfg")
	if err == OK:
		return str(preset.get_value("preset.0.options", "version/code", "0"))
	Log.trace("Utils: Failed to load export_presets.cfg")
	return "0"


func get_application_version_with_code() -> String:
	return "%s  (%s)" % [get_application_config_version(), get_application_version_code()]

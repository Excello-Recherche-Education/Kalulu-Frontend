@tool
extends EditorPlugin

const EXPORTER_PATH: String = "res://addons/export_tool_manager/export_tool_exporter.gd"

const TOOL_CONFIGS: Dictionary = {
	"game": {
		"name": "Kalulu",
		"main_scene": "res://sources/menus/splash_screen/splash_screen.tscn",
		"icon": "res://assets/kalulu_icon.png",
		"export_folder": "Kalulu_Game",
		"button_label": "Export All (Kalulu Game)",
		"presets": {
			"Android Kalulu AAB": "/Android/Kalulu.aab",
			"Android Kalulu APK": "/Android/Kalulu.apk",
			"Android Kalulu APK 32 bits": "/Android/Kalulu_32.apk",
			"Windows Kalulu": "/Windows/Kalulu-Windows.zip",
			"Linux Kalulu": "/Linux/Kalulu-Linux.zip",
			# Apple in last because it's always the most complicated
			#"iOS Kalulu": "/iOS/Kalulu.ipa",
			#"macOS Kalulu": "/macOS/Kalulu-macOS.dmg",
		},
	},
	"prof_tool": {
		"name": "Prof_Tool",
		"main_scene": "res://sources/language_tool/prof_tool_menu.tscn",
		"icon": "res://assets/prof_tool_icon.png",
		"export_folder": "Prof_Tool",
		"button_label": "Export All (Prof Tool)",
		"presets": {
			"Windows ProfTool": "/Windows/Prof_Tool-Windows.zip",
			"Linux ProfTool": "/Linux/Prof_Tool-Linux.zip",
			# Apple in last because it's always the most complicated
			#"macOS ProfTool": "/macOS/Prof_Tool-macOS.dmg",
		},
	}
}

var tool_selector: OptionButton
var exporter_plugin: EditorExportPlugin
var export_button: Button
var current_tool: String = "game"

func _enter_tree() -> void:
	# Tool Selector UI
	tool_selector = OptionButton.new()
	tool_selector.name = "Tool Exporter"
	tool_selector.add_item("Kalulu Game")
	tool_selector.add_item("Prof Tool")
	tool_selector.connect("item_selected", _on_tool_selected)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)

	var settings: EditorSettings = get_editor_interface().get_editor_settings()
	var saved: Variant = settings.get_setting("export_tool_manager/current_tool")

	if typeof(saved) == TYPE_STRING and saved.strip_edges() != "":
		current_tool = saved.strip_edges()

	match current_tool:
		"prof_tool":
			tool_selector.select(1)
		"game", _:
			current_tool = "game"
			tool_selector.select(0)

	_apply_tool_config(current_tool)

	# Exporter plugin
	exporter_plugin = load(EXPORTER_PATH).new()
	add_export_plugin(exporter_plugin)

	# Export All Button
	export_button = Button.new()
	export_button.text = TOOL_CONFIGS[current_tool]["button_label"]
	export_button.pressed.connect(_on_export_all_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, export_button)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)
	tool_selector.queue_free()

	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, export_button)
	export_button.queue_free()

	remove_export_plugin(exporter_plugin)

func _on_tool_selected(index: int) -> void:
	match index:
		1:
			current_tool = "prof_tool"
		0, _:
			current_tool = "game"

	var settings: EditorSettings = get_editor_interface().get_editor_settings()
	settings.set_setting("export_tool_manager/current_tool", current_tool)
	_apply_tool_config(current_tool)


func _apply_tool_config(tool: String) -> void:
	if not TOOL_CONFIGS.has(tool):
		push_error("ExportToolManager: Unknown tool '%s'" % tool)
		return

	var config: Dictionary = TOOL_CONFIGS[tool]
	ProjectSettings.set_setting("application/config/name", config["name"])
	ProjectSettings.set_setting("application/run/main_scene", config["main_scene"])
	ProjectSettings.set_setting("application/config/icon", config["icon"])
	ProjectSettings.save()

	if export_button:
		export_button.text = config["button_label"]

	print("ExportToolManager: Switched to '%s' (scene: %s)" % [config["name"], config["main_scene"]])

func _on_export_all_pressed() -> void:
	export_all_presets()


func export_all_presets() -> void:
	var config: Dictionary = TOOL_CONFIGS[current_tool]
	var base_folder: String = "../Export/Autobuild/%s/" % config["export_folder"]
	var version_folder: String = base_folder + get_application_version_with_code()

	# Check if the version folder already exists
	if DirAccess.dir_exists_absolute(version_folder):
		var dialog: AcceptDialog = AcceptDialog.new()
		dialog.title = "Export aborted"
		dialog.dialog_text = "The export folder already exists:\n%s\n\nDelete it manually before re-exporting." % version_folder
		get_editor_interface().get_base_control().add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		return

	var godot_path: String = OS.get_executable_path()
	var presets: Dictionary = config["presets"]

	for preset_name in presets.keys():
		await get_tree().create_timer(1).timeout
		var output_path: String = version_folder + presets[preset_name]
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

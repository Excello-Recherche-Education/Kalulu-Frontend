@tool
extends EditorPlugin

const EXPORTER_PATH := "res://addons/export_tool_manager/export_tool_exporter.gd"

var tool_selector: OptionButton
var exporter_plugin: EditorExportPlugin

func _enter_tree():
	tool_selector = OptionButton.new()
	tool_selector.name = "Tool Exporter"
	tool_selector.add_item("Game")
	tool_selector.add_item("Prof Tool")
	tool_selector.connect("item_selected", _on_tool_selected)

	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)

	var settings := get_editor_interface().get_editor_settings()
	var current := settings.get_setting("export_tool_manager/current_tool")
	var current_tool := "game"

	if typeof(current) == TYPE_STRING and current.strip_edges() != "":
		current_tool = current.strip_edges()

	match current_tool:
		"prof_tool":
			tool_selector.select(1)
		"game", _:
			tool_selector.select(0)

	# On instancie le plugin d'export
	exporter_plugin = load(EXPORTER_PATH).new()
	add_export_plugin(exporter_plugin)

func _exit_tree():
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)
	if exporter_plugin:
		remove_export_plugin(exporter_plugin)

func _on_tool_selected(index: int) -> void:
	var selected_tool := tool_selector.get_item_text(index).to_lower().replace(" ", "_")
	if selected_tool == "":
		selected_tool = "game"

	var settings := get_editor_interface().get_editor_settings()
	settings.set_setting("export_tool_manager/current_tool", selected_tool)

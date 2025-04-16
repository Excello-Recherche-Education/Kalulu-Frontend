@tool
extends EditorPlugin

const EXPORTER_PATH := "res://addons/export_tool_manager/export_tool_exporter.gd"

var tool_selector: OptionButton

func _enter_tree():
	tool_selector = OptionButton.new()
	tool_selector.name = "Tool Exporter"
	tool_selector.add_item("Game")
	tool_selector.add_item("Prof Tool")
	tool_selector.connect("item_selected", _on_tool_selected)

	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)

	# Accès sécurisé à l'EditorSettings
	var settings := get_editor_interface().get_editor_settings()
	var current := settings.get_setting("export_tool_manager/current_tool")

	var current_tool := "game"  # Valeur par défaut
	if typeof(current) == TYPE_STRING:
		current_tool = current

	# Appliquer la sélection au menu
	match current_tool:
		"prof_tool":
			tool_selector.select(1)
		"game", _:
			tool_selector.select(0)

	# Ajout de l’export plugin
	add_export_plugin(load(EXPORTER_PATH).new())

func _exit_tree():
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, tool_selector)
	remove_export_plugin(load(EXPORTER_PATH).new())

func _on_tool_selected(index: int) -> void:
	var selected_tool := tool_selector.get_item_text(index).to_lower().replace(" ", "_")

	var settings := get_editor_interface().get_editor_settings()
	settings.set_setting("export_tool_manager/current_tool", selected_tool)

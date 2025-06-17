@tool
extends EditorPlugin

enum EnvType { DEV, PROD }

const CONFIG_PATH: String = "user://environment.cfg"

var env_selector: OptionButton
var current_environment: EnvType = EnvType.DEV

func _enter_tree() -> void:
	# Create OptionButton
	env_selector = OptionButton.new()
	env_selector.name = "Env Selector"
	env_selector.add_item("DEV", EnvType.DEV)
	env_selector.add_item("PROD", EnvType.PROD)
	env_selector.connect("item_selected", _on_env_selected)

	# Add to the toolbar
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, env_selector)

	# Load environment setting
	load_environment()

	# Reflect the current environment in UI
	env_selector.select(current_environment)

func _exit_tree() -> void:
	# Clean up the UI and save state
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, env_selector)
	env_selector.queue_free()

func _on_env_selected(index: int) -> void:
	current_environment = index
	save_environment()
	print("Environment switched to:", _environment_to_string(current_environment))

func _environment_to_string(env: EnvType) -> String:
	match env:
		EnvType.DEV: return "DEV"
		EnvType.PROD: return "PROD"
		_: return "Unknown"

func save_environment() -> void:
	var config = ConfigFile.new()
	config.set_value("environment", "current", str(current_environment))
	config.save(CONFIG_PATH)

func load_environment() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		var env = config.get_value("environment", "current", str(EnvType.DEV))
		current_environment = int(env)

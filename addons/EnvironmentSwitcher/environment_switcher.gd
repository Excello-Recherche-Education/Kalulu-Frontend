@tool
extends EditorPlugin

enum EnvType { DEV, PROD }

var current_environment : EnvType = EnvType.DEV

const MENU_NAME: String = "Environment Switcher"
const SWITCH_PROD: String = "Switch to PROD"
const SWITCH_DEV: String = "Switch to DEV"

func _enter_tree():
	load_environment()
	_update_menu()

func _update_menu():
	# Supprimer les anciens items si existants
	remove_tool_menu_item(SWITCH_DEV)
	remove_tool_menu_item(SWITCH_PROD)
	remove_tool_menu_item("Current environment: " + _environment_to_string(current_environment))

	# Ajout d'un affichage de l'environnement actuel (désactivé)
	add_tool_menu_item("Current environment: " + _environment_to_string(current_environment), Callable(self, "_noop"))
	if current_environment == EnvType.DEV:
		add_tool_menu_item(SWITCH_PROD, Callable(self, "_on_menu_item_pressed").bind(EnvType.PROD))
	elif current_environment == EnvType.PROD:
		add_tool_menu_item(SWITCH_DEV, Callable(self, "_on_menu_item_pressed").bind(EnvType.DEV))
	else:
		push_warning("Environment not recognized in EnvironmentSwitcher: " + str(current_environment))

func _noop():
	# Fonction vide pour les éléments non cliquables
	print("It is useless to click on this button")

func _on_menu_item_pressed(env: EnvType):
	remove_tool_menu_item("Current environment: " + _environment_to_string(current_environment))
	current_environment = env
	save_environment()
	_update_menu()


func _exit_tree():
	# Retirer l'élément du menu quand le plugin est déchargé
	remove_tool_menu_item(MENU_NAME)


func _build_submenu() -> PopupMenu:
	var popup = PopupMenu.new()

	# Afficher l'environnement actuel
	popup.add_disabled_item("Current environment: " + _environment_to_string(current_environment))
	popup.add_separator()

	# Ajouter des items pour changer l'environnement
	popup.add_item(SWITCH_DEV, EnvType.DEV)
	popup.add_item(SWITCH_PROD, EnvType.PROD)

	# Connecter l'action sur l'élément de menu à la fonction de traitement
	popup.id_pressed.connect(self, "_on_menu_item_pressed")

	return popup

# Conversion de l'énumération en texte pour l'affichage dans le menu
func _environment_to_string(env: EnvType) -> String:
	match env:
		EnvType.DEV:
			return "DEV"
		EnvType.PROD:
			return "PROD"
		_:
			return "Unknown"

# Sauvegarder l'environnement dans un fichier de configuration
func save_environment():
	var config = ConfigFile.new()
	config.set_value("environment", "current", str(current_environment))
	config.save("user://environment.cfg")

# Charger l'environnement depuis le fichier de configuration
func load_environment():
	var config = ConfigFile.new()
	if config.load("user://environment.cfg") == OK:
		var env = config.get_value("environment", "current", str(EnvType.DEV))
		current_environment = int(env)

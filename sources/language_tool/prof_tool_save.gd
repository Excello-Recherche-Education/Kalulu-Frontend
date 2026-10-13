class_name ProfToolSave
extends Resource

@export var selected_language: String = ""
## The main menu tab to reopen on, so returning from an editor lands where the
## user left. It used to live in a `Globals` autoload, which made the game
## register a Prof Tool singleton.
@export var main_menu_selected_tab: int = 0

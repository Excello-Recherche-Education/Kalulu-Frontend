extends Control

const GARDENS_SCENE_PATH: String = "res://sources/gardens/gardens.tscn"

@onready var progress_label: Label = $Brain/Finish_Line/AutoSizeLabel/Label


func _ready() -> void:
	_update_progress_label()
	await (OpeningCurtain as OpeningCurtainClass).open()


func _update_progress_label() -> void:
	var player_name: String = UserDataManager.get_current_student_name()
	if player_name.is_empty():
		progress_label.text = tr("BRAIN_PLAYER_PROGRESS_NO_NAME")
	else:
		progress_label.text = tr("BRAIN_PLAYER_PROGRESS").format({"name": player_name})


func _on_back_button_pressed() -> void:
	await (OpeningCurtain as OpeningCurtainClass).close()
	SceneLoader.change_scene(GARDENS_SCENE_PATH)

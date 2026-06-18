extends Control

const GARDENS_SCENE_PATH: String = "res://sources/gardens/gardens.tscn"

@onready var progress_label: AutoSizeLabel = $Brain/Finish_Line/AutoSizeLabel


func _ready() -> void:
	_update_progress_label()
	await (OpeningCurtain as OpeningCurtainClass).open()


func _update_progress_label() -> void:
	var player_name: String = UserDataManager.get_current_student_name()
	var progress_text: String
	if player_name.is_empty():
		progress_text = tr("BRAIN_PLAYER_PROGRESS_NO_NAME")
	else:
		progress_text = tr("BRAIN_PLAYER_PROGRESS").format({"name": player_name})
	# Scale the label against the actual text so long names never overflow the
	# name board (names have no length bound).
	progress_label.ref_size_text = progress_text
	progress_label.label.text = progress_text


func _on_back_button_pressed() -> void:
	await (OpeningCurtain as OpeningCurtainClass).close()
	SceneLoader.change_scene(GARDENS_SCENE_PATH)

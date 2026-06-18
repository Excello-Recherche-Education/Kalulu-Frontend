extends Control

const GARDENS_SCENE_PATH: String = "res://sources/gardens/gardens.tscn"


func _ready() -> void:
	await (OpeningCurtain as OpeningCurtainClass).open()


func _on_back_button_pressed() -> void:
	await (OpeningCurtain as OpeningCurtainClass).close()
	SceneLoader.change_scene(GARDENS_SCENE_PATH)

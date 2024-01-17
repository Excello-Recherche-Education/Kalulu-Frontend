extends HBoxContainer

signal delete

@onready var gp_menu_button: = %GPMenuButton
@onready var video_player: = %VideoStreamPlayer
@onready var video_upload_button: = %VideoUploadButton
@onready var file_dialog: = $FileDialog

const resource_folder: = "user://language_resources/"
const language_folder: = "french/"
const video_folder: = "look_and_learn/video/"
const video_extension: = ".ogv"

var gp: = ""


func _video_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_video_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		var current_file: = _video_file_path()
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		set_video_preview(current_file)


func _video_file_path() -> String:
	return resource_folder + language_folder + video_folder + gp + video_extension


func set_video_preview(video_path: String) -> void:
	video_player.stream = load(video_path)


func set_gp(p_gp: String) -> void:
	gp = p_gp
	gp_menu_button.text = gp
	
	if FileAccess.file_exists(_video_file_path()):
		set_video_preview(_video_file_path())


func _on_video_upload_button_pressed() -> void:
	if gp != "":
		file_dialog.filters = []
		file_dialog.add_filter("*" + video_extension, "Videos")
		
		for connection in file_dialog.file_selected.get_connections():
			connection["signal"].disconnect(connection["callable"])
		
		file_dialog.file_selected.connect(_video_file_selected)
		
		file_dialog.show()


func _on_button_pressed() -> void:
	delete.emit()


func _on_video_stream_player_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click") and video_player.stream:
		video_player.play()

extends HBoxContainer

signal delete

@onready var gp_menu_button: = %GPMenuButton
@onready var video_player: = %VideoStreamPlayer
@onready var video_upload_button: = %VideoUploadButton
@onready var file_dialog: = $FileDialog

var gp: Dictionary


func _video_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_video_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		var current_file: = Database.get_gp_look_and_learn_video_path(gp)
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		set_video_preview(current_file)


func set_video_preview(video_path: String) -> void:
	video_player.stream = load(video_path)
	video_player.visible = true


func set_gp(p_gp: Dictionary) -> void:
	gp = p_gp
	gp_menu_button.text = gp["Grapheme"] + "-" + gp["Phoneme"]
	
	if FileAccess.file_exists(Database.get_gp_look_and_learn_video_path(gp)):
		set_video_preview(Database.get_gp_look_and_learn_video_path(gp))


func _on_video_upload_button_pressed() -> void:
	if not gp.is_empty():
		file_dialog.filters = []
		file_dialog.add_filter("*" + Database.video_extension, "Videos")
		
		for connection in file_dialog.file_selected.get_connections():
			connection["signal"].disconnect(connection["callable"])
		
		file_dialog.file_selected.connect(_video_file_selected)
		
		file_dialog.show()


func _on_button_pressed() -> void:
	video_player.stream = null
	video_player.visible = false
	var current_file: = Database.get_gp_look_and_learn_video_path(gp)
	if FileAccess.file_exists(current_file):
		DirAccess.remove_absolute(current_file)


func _on_video_stream_player_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click") and video_player.stream:
		video_player.play()

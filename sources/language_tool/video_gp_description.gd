class_name VideoGPDescription
extends HBoxContainer

@warning_ignore("unused_signal")
signal deleted()

var gp: Dictionary = {}

@onready var gp_menu_button: MenuButton = %GPMenuButton
@onready var video_player: VideoStreamPlayer = %VideoStreamPlayer
@onready var video_upload_button: PlusButton = %VideoUploadButton
@onready var file_dialog: FileDialog = $FileDialog


func _video_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_video_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		_remove_video_files()
		var current_file: String = Database.get_gp_look_and_learn_video_path(gp)
		DirAccess.copy_absolute(file_path, current_file)
		set_video_preview(current_file)


func set_video_preview(video_path: String) -> void:
	video_player.stream = load(video_path)
	video_player.show()


func set_gp(p_gp: Dictionary) -> void:
	gp = p_gp
	gp_menu_button.text = Database.get_gp_name(gp)
	# Through find_gp_asset_files, so a pack that predates the file name encoding
	# still shows its videos. Uploads are written under the canonical name.
	var files: PackedStringArray = Database.find_gp_asset_files(
			gp, Database.LOOK_AND_LEARN_VIDEOS, Database.VIDEO_EXTENSION)
	if not files.is_empty():
		set_video_preview(files[0])


func _on_video_upload_button_pressed() -> void:
	if not gp.is_empty():
		file_dialog.filters = []
		file_dialog.add_filter("*" + Database.VIDEO_EXTENSION, "Videos")
		Utils.disconnect_all(file_dialog.file_selected)
		file_dialog.file_selected.connect(_video_file_selected)
		file_dialog.show()


func _on_button_pressed() -> void:
	video_player.stream = null
	video_player.hide()
	_remove_video_files()


# Both names, not only the canonical one: a legacy file left behind would come
# straight back the next time the line is shown.
func _remove_video_files() -> void:
	for file: String in Database.find_gp_asset_files(
			gp, Database.LOOK_AND_LEARN_VIDEOS, Database.VIDEO_EXTENSION):
		DirAccess.remove_absolute(file)


func _on_video_stream_player_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click") and video_player.stream:
		video_player.play()

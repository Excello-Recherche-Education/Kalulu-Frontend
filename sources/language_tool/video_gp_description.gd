extends HBoxContainer

signal delete

@onready var gp_menu_button: = %GPMenuButton
@onready var video_check_box: = %VideoCheckBox
@onready var video_upload_button: = %VideoUploadButton
@onready var file_dialog: = $FileDialog

const resource_folder: = "res://language_resources/"
const language_folder: = "french/"
const video_folder: = "look_and_learn/video/"
const video_extension: = ".ogv"

var gp: = ""
var gp_list: = {}


func _ready() -> void:
	var popup: PopupMenu = gp_menu_button.get_popup()
	
	Database.db.query("Select * FROM GPs")
	for res in Database.db.query_result:
		popup.add_check_item(res["Grapheme"] + "-" + res["Phoneme"], res["ID"])
		gp_list[res["ID"]] = res["Grapheme"] + "-" + res["Phoneme"]
	
	gp_menu_button.get_popup().id_pressed.connect(_on_gp_menu_button_popup_id_pressed)


func _video_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_video_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		var current_file: = _video_file_path()
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		video_check_box.button_pressed = true


func _video_file_path() -> String:
	return resource_folder + language_folder + video_folder + gp + video_extension


func _on_gp_menu_button_popup_id_pressed(id: int) -> void:
	gp = gp_list[id]
	gp_menu_button.text = gp
	
	video_check_box.button_pressed = FileAccess.file_exists(_video_file_path())


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

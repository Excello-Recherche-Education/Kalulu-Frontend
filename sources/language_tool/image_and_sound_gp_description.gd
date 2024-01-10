extends HBoxContainer

signal delete

@onready var gp_menu_button: = %GPMenuButton
@onready var image_check_box: = %ImageCheckBox
@onready var image_upload_button: = %ImageUploadButton
@onready var sound_check_box: = %SoundCheckBox
@onready var sound_upload_button: = %SoundUploadButton
@onready var file_dialog: = $FileDialog

const resource_folder: = "res://language_resources/"
const language_folder: = "french/"
const image_folder: = "look_and_learn/images/"
const sound_folder: = "look_and_learn/sounds/"
const image_extension: = ".png"
const sound_extension: = ".mp4"

var gp: = ""
var gp_list: = {}


func _ready() -> void:
	var popup: PopupMenu = gp_menu_button.get_popup()
	
	Database.db.query("Select * FROM GPs")
	for res in Database.db.query_result:
		popup.add_check_item(res["Grapheme"] + "-" + res["Phoneme"], res["ID"])
		gp_list[res["ID"]] = res["Grapheme"] + "-" + res["Phoneme"]
	
	gp_menu_button.get_popup().id_pressed.connect(_on_gp_menu_button_popup_id_pressed)


func _image_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_image_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		var current_file: = _image_file_path()
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		image_check_box.button_pressed = true


func _image_file_path() -> String:
	return resource_folder + language_folder + image_folder + gp + image_extension


func _sound_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var current_file: = resource_folder + language_folder + sound_folder + gp + sound_extension
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		sound_check_box.button_pressed = true


func _sound_file_path() -> String:
	return resource_folder + language_folder + sound_folder + gp + sound_extension


func _on_gp_menu_button_popup_id_pressed(id: int) -> void:
	gp = gp_list[id]
	gp_menu_button.text = gp
	
	image_check_box.button_pressed = FileAccess.file_exists(_image_file_path())
	sound_check_box.button_pressed = FileAccess.file_exists(_sound_file_path())


func _on_image_upload_button_pressed() -> void:
	if gp != "":
		file_dialog.filters = []
		file_dialog.add_filter("*" + image_extension, "Images")
		
		for connection in file_dialog.file_selected.get_connections():
			connection["signal"].disconnect(connection["callable"])
		
		file_dialog.file_selected.connect(_image_file_selected)
		
		file_dialog.show()


func _on_sound_upload_button_pressed() -> void:
	if gp != "":
		file_dialog.filters = []
		file_dialog.add_filter("*" + sound_extension, "Sounds")
		
		for connection in file_dialog.file_selected.get_connections():
			connection["signal"].disconnect(connection["callable"])
		
		file_dialog.file_selected.connect(_sound_file_selected)
		
		file_dialog.show()


func _on_button_pressed() -> void:
	delete.emit()

extends HBoxContainer

signal delete

@onready var gp_menu_button: = %GPMenuButton
@onready var image_preview: = %ImagePreview
@onready var sound_preview: = %SoundPreview
@onready var image_upload_button: = %ImageUploadButton
@onready var sound_upload_button: = %SoundUploadButton
@onready var file_dialog: = $FileDialog
@onready var sound_player: = $AudioStreamPlayer

const resource_folder: = "user://language_resources/"
const language_folder: = "french/"
const image_folder: = "look_and_learn/images/"
const sound_folder: = "look_and_learn/sounds/"
const image_extension: = ".png"
const sound_extension: = ".mp3"

var gp: = ""




func _image_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_image_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		var current_file: = _image_file_path()
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		set_image_preview(current_file)


func set_image_preview(img_path: String) -> void:
	var image: = Image.load_from_file(img_path)
	image_preview.texture = ImageTexture.create_from_image(image)


func set_sound_preview(sound_path: String) -> void:
	var file = FileAccess.open(sound_path, FileAccess.READ)
	var sound = AudioStreamMP3.new()
	sound.data = file.get_buffer(file.get_length())
	sound_player.stream = sound


func _image_file_path() -> String:
	return resource_folder + language_folder + image_folder + gp + image_extension


func _sound_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var current_file: = resource_folder + language_folder + sound_folder + gp + sound_extension
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		set_sound_preview(current_file)
		sound_preview.show()


func _sound_file_path() -> String:
	return resource_folder + language_folder + sound_folder + gp + sound_extension


func set_gp(p_gp: String) -> void:
	gp = p_gp
	gp_menu_button.text = gp
	
	if FileAccess.file_exists(_image_file_path()):
		set_image_preview(_image_file_path())
	if FileAccess.file_exists(_sound_file_path()):
		set_sound_preview(_sound_file_path())
		sound_preview.show()
	else:
		sound_preview.hide()


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


func _on_sound_preview_pressed() -> void:
	if sound_player.stream:
		sound_player.play()

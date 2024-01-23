extends HBoxContainer

signal delete

@onready var gp_menu_button: = %GPMenuButton
@onready var image_preview: = %ImagePreview
@onready var sound_preview: = %SoundPreview
@onready var image_upload_button: = %ImageUploadButton
@onready var sound_upload_button: = %SoundUploadButton
@onready var file_dialog: = $FileDialog
@onready var sound_player: = $AudioStreamPlayer

var gp: Dictionary


func _image_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_image_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		var current_file: = Database.get_gp_look_and_learn_image_path(gp)
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


func _sound_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var current_file: = Database.get_gp_look_and_learn_sound_path(gp)
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		set_sound_preview(current_file)
		sound_preview.show()


func set_gp(value: Dictionary) -> void:
	gp = value
	gp_menu_button.text = gp["Grapheme"] + "-" + gp["Phoneme"]
	
	var image_path: = Database.get_gp_look_and_learn_image_path(gp)
	if FileAccess.file_exists(image_path):
		set_image_preview(image_path)
	
	var sound_path: = Database.get_gp_look_and_learn_sound_path(gp)
	if FileAccess.file_exists(sound_path):
		set_sound_preview(sound_path)
		sound_preview.show()
	else:
		sound_preview.hide()


func _on_image_upload_button_pressed() -> void:
	if not gp.is_empty():
		file_dialog.filters = []
		file_dialog.add_filter("*" + Database.image_extension, "Images")
		
		for connection in file_dialog.file_selected.get_connections():
			connection["signal"].disconnect(connection["callable"])
		
		file_dialog.file_selected.connect(_image_file_selected)
		
		file_dialog.show()


func _on_sound_upload_button_pressed() -> void:
	if not gp.is_empty():
		file_dialog.filters = []
		file_dialog.add_filter("*" + Database.sound_extension, "Sounds")
		
		for connection in file_dialog.file_selected.get_connections():
			connection["signal"].disconnect(connection["callable"])
		
		file_dialog.file_selected.connect(_sound_file_selected)
		
		file_dialog.show()


func _on_button_pressed() -> void:
	delete.emit()


func _on_sound_preview_pressed() -> void:
	if sound_player.stream:
		sound_player.play()

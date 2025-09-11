extends HBoxContainer
class_name ImageAndSoundGPDescription

signal delete

@onready var gp_menu_button: MenuButton = %GPMenuButton
@onready var image_preview: TextureRect = %ImagePreview
@onready var sound_preview: Button = %SoundPreview
@onready var image_upload_button: MarginContainer = %ImageUploadButton
@onready var sound_upload_button: MarginContainer = %SoundUploadButton
@onready var file_dialog: FileDialog = $FileDialog
@onready var sound_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var image_clear_button: MarginContainer = %ImageClearButton
@onready var sound_clear_button: MarginContainer = %SoundClearButton

var gp: Dictionary = {}
var get_image_path: Callable = Database.get_gp_look_and_learn_image_path
var get_sound_path: Callable = Database.get_gp_look_and_learn_sound_path


func _image_file_selected(file_path: String) -> void:
	file_dialog.files_selected.connect(_image_file_selected.bind(file_dialog))
	if FileAccess.file_exists(file_path):
		var current_file: String = get_image_path.call(gp)
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		set_image_preview(current_file)


func set_image_preview(img_path: String) -> void:
	if img_path.is_empty():
		image_clear_button.hide()
		image_upload_button.show()
		image_preview.texture = null
	else:
		var image: Image = Image.load_from_file(img_path)
		image_preview.texture = ImageTexture.create_from_image(image)
		image_clear_button.show()
		image_upload_button.hide()


func set_sound_preview(sound_path: String) -> void:
	if sound_path.is_empty():
		sound_clear_button.hide()
		sound_upload_button.show()
		sound_player.stream = null
		sound_preview.hide()
	else:
		var file: FileAccess = FileAccess.open(sound_path, FileAccess.READ)
		var error: Error = FileAccess.get_open_error()
		if error != OK:
			Logger.error("ImageAndSoundGPDescription: Cannot open file %s. Error: %s" % [sound_path, error_string(error)])
			return
		if file == null:
			Logger.error("ImageAndSoundGPDescription: Cannot open file %s. File is null" % sound_path)
			return
		var sound: AudioStreamMP3 = AudioStreamMP3.new()
		sound.data = file.get_buffer(file.get_length())
		sound_player.stream = sound
		sound_clear_button.show()
		sound_upload_button.hide()
		sound_preview.show()


func _sound_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var current_file: String = get_sound_path.call(gp)
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		set_sound_preview(current_file)
		sound_preview.show()


func set_gp(value: Dictionary) -> void:
	gp = value
	gp_menu_button.text = Database.get_gp_name(gp)
	
	var image_path: String = get_image_path.call(gp)
	if FileAccess.file_exists(image_path):
		set_image_preview(image_path)
	else:
		image_clear_button.hide()
	
	var sound_path: String = get_sound_path.call(gp)
	if FileAccess.file_exists(sound_path):
		set_sound_preview(sound_path)
		sound_preview.show()
	else:
		sound_preview.hide()
		sound_clear_button.hide()


func _on_image_upload_button_pressed() -> void:
	if not gp.is_empty():
		file_dialog.filters = []
		file_dialog.add_filter("*" + Database.IMAGE_EXTENSION, "Images")
		Utils.disconnect_all(file_dialog.file_selected)
		file_dialog.file_selected.connect(_image_file_selected)
		file_dialog.show()


func _on_sound_upload_button_pressed() -> void:
	if not gp.is_empty():
		file_dialog.filters = []
		file_dialog.add_filter("*" + Database.SOUND_EXTENSION, "Sounds")
		Utils.disconnect_all(file_dialog.file_selected)
		file_dialog.file_selected.connect(_sound_file_selected)
		file_dialog.show()


func _on_button_pressed() -> void:
	delete.emit()


func _on_sound_preview_pressed() -> void:
	if sound_player.stream:
		sound_player.play()


func _on_image_clear_button_pressed() -> void:
	var current_file: String = get_image_path.call(gp)
	if FileAccess.file_exists(current_file):
		DirAccess.remove_absolute(current_file)
	
	set_image_preview("")


func _on_sound_clear_button_pressed() -> void:
	var current_file: String = get_sound_path.call(gp)
	if FileAccess.file_exists(current_file):
		DirAccess.remove_absolute(current_file)
	
	set_sound_preview("")


func hide_image_part() -> void:
	(%ImageContainer as MarginContainer).hide()

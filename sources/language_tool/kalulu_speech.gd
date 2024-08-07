extends PanelContainer

@export var speech_category: String
@export var speech_name: String:
	set = _set_speech_name
@export var speech_description: String:
	set = _set_speech_description

@onready var file_dialog: FileDialog = $FileDialog
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var play_button: MarginContainer = %PlayButton
@onready var upload_button: MarginContainer = %UploadButton
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel


func _ready() -> void:
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = []
	file_dialog.add_filter("*" + Database.sound_extension, "Sounds")
	
	_set_speech_name(speech_name)
	_set_speech_description(speech_description)


func _load_speech() -> void:
	var current_file: String = Database.get_kalulu_speech_path(speech_category, speech_name)
	if FileAccess.file_exists(current_file):
		audio_stream_player.stream = Database.load_external_sound(current_file)
		play_button.show()
	else:
		play_button.hide()


func _set_speech_name(value: String) -> void:
	speech_name = value
	if name_label:
		name_label.text = speech_name
		_load_speech()


func _set_speech_description(value: String) -> void:
	speech_description = value
	if description_label:
		description_label.text = speech_description


func _on_play_button_pressed() -> void:
	audio_stream_player.play()


func _on_upload_button_pressed() -> void:
	file_dialog.show()


func _on_file_dialog_file_selected(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var current_file: String = Database.get_kalulu_speech_path(speech_category, speech_name)
		if FileAccess.file_exists(current_file):
			DirAccess.remove_absolute(current_file)
		
		var current_dir: = current_file.get_base_dir()
		if not DirAccess.dir_exists_absolute(current_dir):
			DirAccess.make_dir_recursive_absolute(current_dir)
		
		DirAccess.copy_absolute(file_path, current_file)
		
		audio_stream_player.stream = Database.load_external_sound(current_file)
		play_button.show()

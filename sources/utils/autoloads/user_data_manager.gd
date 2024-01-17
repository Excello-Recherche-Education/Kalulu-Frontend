@tool
extends Node


var teacher: String = "" :
	set(teacher_name):
		student = ""


var student: String = "" :
	set(student_name):
		student = student_name
		if student_settings:
			_save_student_settings()
		
		if student :
			load_student_settings()
		else :
			student_settings = null

var language_settings: LanguageSettings
var student_settings: UserSettings
var student_progression: UserProgression


func _ready():
	teacher = "toto"
	student = "titi"
	
	load_student_settings()
	load_student_progression()
	
	student_progression.unlocks_changed.connect(_on_user_progression_unlocks_changed)
	load_language_settings()


func load_language_settings() -> void:
	if FileAccess.file_exists(get_language_settings_path()):
		language_settings = load(get_language_settings_path())
	if not language_settings:
		language_settings = LanguageSettings.new()
		_save_language_settings()


func _save_language_settings() -> void:
	ResourceSaver.save(language_settings, get_language_settings_path())


func get_language_settings_path() -> String:
	return "user://language.tres"


func set_language(language : String) -> void:
	if language_settings:
		language_settings.language = language
		_save_language_settings()


func login(language : String, teacher : String, device_id : String) -> void:
	if language_settings:
		language_settings.language = language
		language_settings.teacher = teacher
		language_settings.device_id = device_id
		_save_language_settings()


func load_student_settings() -> void:
	# Load User settings
	if FileAccess.file_exists(get_student_settings_path()):
		student_settings = load(get_student_settings_path())
	
	if not student_settings:
		student_settings = UserSettings.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_settings()


func load_student_progression() -> void:
	if FileAccess.file_exists(get_student_progression_path()):
		student_progression = load(get_student_progression_path())
	
	if not student_progression:
		student_progression = UserProgression.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_progression()


func _save_student_settings() -> void:
	ResourceSaver.save(student_settings, get_student_settings_path())


func _save_student_progression() -> void:
	ResourceSaver.save(student_progression, get_student_progression_path())


func get_teacher_folder() -> String:
	var file_path: = "user://" + teacher + "/"
	return file_path


func get_student_folder() -> String:
	var file_path: = get_teacher_folder() + student + "/"
	return file_path


func get_student_settings_path() -> String:
	var file_path: = get_student_folder() + "settings.tres"
	return file_path


func get_student_progression_path() -> String:
	var file_path: = get_student_folder() + "progression.tres"
	return file_path


func set_master_volume(value: float) -> void:
	if student_settings:
		var volume: = denormalize_volume(value)
		student_settings.master_volume = volume
		_save_student_settings()


func set_music_volume(value: float) -> void:
	if student_settings:
		var volume: = denormalize_volume(value)
		student_settings.music_volume = volume
		_save_student_settings()


func set_voice_volume(value: float) -> void:
	if student_settings:
		var volume: = denormalize_volume(value)
		student_settings.voice_volume = volume
		_save_student_settings()


func set_effects_volume(value: float) -> void:
	if student_settings:
		var volume: = denormalize_volume(value)
		student_settings.effects_volume = volume
		_save_student_settings()


func get_master_volume() -> float:
	var value: = 0.0
	if student_settings:
		var volume: = student_settings.master_volume
		value = normalize_slider(volume)
	
	return value


func get_music_volume() -> float:
	var value: = 0.0
	if student_settings:
		var volume: = student_settings.music_volume
		value = normalize_slider(volume)
	
	return value


func get_voice_volume() -> float:
	var value: = 0.0
	if student_settings:
		var volume: = student_settings.voice_volume
		value = normalize_slider(volume)
	
	return value


func get_effects_volume() -> float:
	var value: = 0.0
	if student_settings:
		var volume: = student_settings.effects_volume
		value = normalize_slider(volume)
	
	return value


func _on_user_progression_unlocks_changed() -> void:
	_save_student_progression()


# Convert the volume from [-80, 6]db to [0, 100] and back
func normalize_slider(volume) -> float:
	var value: = pow((volume + 80.0) / 86, 5.0) * 100.0
	return value


func denormalize_volume(value: float) -> float:
	var volume: = pow(float(value) / 100.0, 0.2) * 86 - 80
	return volume

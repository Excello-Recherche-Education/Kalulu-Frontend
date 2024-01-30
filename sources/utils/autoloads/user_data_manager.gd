@tool
extends Node


var student: String = "" :
	set(student_name):
		if student_settings:
			_save_student_settings()
			
		student = student_name
		if student :
			load_student_settings()
		else :
			student_settings = null

var device_settings: DeviceSettings
var teacher_settings: TeacherSettings
var student_settings: UserSettings
var student_progression: UserProgression


func _ready():
	load_device_settings()
	if device_settings.teacher:
		load_teacher_settings()
	load_student_settings()
	load_student_progression()
	
	student_progression.unlocks_changed.connect(_on_user_progression_unlocks_changed)


func login(language : String, teacher : String, password : String, device_id : int) -> bool:
	
	if teacher not in DeviceSettings.possible_logins or password != DeviceSettings.possible_logins[teacher]:
		return false
	
	if not device_settings:
		return false
	
	# Handles device settings
	device_settings.language = language
	device_settings.teacher = teacher
	device_settings.device_id = device_id
	_save_device_settings()
	
	# Handles teacher settings
	load_teacher_settings()
	
	return true


func login_student(code : String) -> bool:
	
	if not device_settings or not teacher_settings:
		return false
	
	for s in teacher_settings.students:
		if s.code == code and s.device == device_settings.device_id:
			student = code
			return true
	
	return false

func load_device_settings() -> void:
	if FileAccess.file_exists(get_device_settings_path()):
		device_settings = load(get_device_settings_path())
	if not device_settings:
		device_settings = DeviceSettings.new()
		_save_device_settings()


func _save_device_settings() -> void:
	ResourceSaver.save(device_settings, get_device_settings_path())


func get_device_settings_path() -> String:
	return "user://device_settings.tres"


func load_teacher_settings() -> void:
	if FileAccess.file_exists(get_teacher_settings_path()):
		teacher_settings = load(get_teacher_settings_path())
	if not teacher_settings:
		teacher_settings = TeacherSettings.new()
		# Default values for now
		teacher_settings.setup_students(15, 90)
		_save_teacher_settings()


func _save_teacher_settings():
	ResourceSaver.save(teacher_settings, get_teacher_settings_path())


func get_teacher_settings_path() -> String:
	return "user://".path_join(device_settings.teacher).path_join("teacher_settings.tres")

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
	var file_path: = "user://" + device_settings.teacher + "/"
	return file_path


func get_student_folder() -> String:
	var file_path: = device_settings.get_folder_path().path_join(student)
	return file_path


func get_student_settings_path() -> String:
	var file_path: =  get_student_folder().path_join("settings.tres")
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

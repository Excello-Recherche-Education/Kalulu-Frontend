@tool
extends Node


var student: String = "" :
	set(student_name):
		if student_settings:
			_save_student_settings()
			
		student = student_name
		if student :
			_load_student_settings()
			_load_student_progression()
		else :
			student_settings = null

var _device_settings: DeviceSettings
var teacher_settings: TeacherSettings
var student_settings: UserSettings
var student_progression: UserProgression


func _ready():
	if get_device_settings().teacher:
		_load_teacher_settings()


# Registering and logging in #

func register(register_settings : TeacherSettings) -> bool:
	if not register_settings:
		return false
	
	# TODO Register on the distant server (Nakama ?)
	# The server will check if an account with the provided mail already exists
	
	# Handles device settings
	var device_settings := get_device_settings()
	device_settings.teacher = register_settings.email
	device_settings.device_id = 1
	_save_device_settings()
	
	# Save the teacher settings on disk
	DirAccess.make_dir_recursive_absolute(get_teacher_folder())
	teacher_settings = register_settings
	_save_teacher_settings()
	
	return true

func login(type : TeacherSettings.AccountType, language : String, teacher : String, password : String, device_id : int) -> bool:
	if not _device_settings or not teacher or not password or device_id == 0:
		return false
	
	var path := _get_teacher_settings_path(teacher)
	
	if not FileAccess.file_exists(path):
		return false
	
	var temp_teacher_settings = load(path) as TeacherSettings
	
	if not temp_teacher_settings or temp_teacher_settings.password != password or temp_teacher_settings.account_type != type or device_id not in temp_teacher_settings.students.keys():
		return false
	
	# Handles teacher settings
	teacher_settings = temp_teacher_settings
	
	# Handles device settings
	if _device_settings.language != language:
		_device_settings.language = language
	_device_settings.teacher = teacher
	_device_settings.device_id = device_id
	_save_device_settings()
	
	return true

func logout() -> void:
	
	# Handles device settings
	_device_settings.teacher = ""
	_device_settings.device_id = 0
	_save_device_settings()
	
	# Handles teacher settings
	teacher_settings = null
	
	# Handles student settings
	if student:
		student = ""

func login_student(code : String) -> bool:
	if not _device_settings or not teacher_settings:
		return false
	
	var students = teacher_settings.students[_device_settings.device_id] as Array[StudentData]
	if students:
		for s in students:
			if s.code == code:
				student = code
				return true
	
	return false


# Device settings #

func get_device_settings_path() -> String:
	return "user://device_settings.tres"

func get_device_settings() -> DeviceSettings:
	if not _device_settings:
		_load_device_settings()
	return _device_settings

func _load_device_settings() -> void:
	if FileAccess.file_exists(get_device_settings_path()):
		_device_settings = load(get_device_settings_path())
	if not _device_settings:
		_device_settings = DeviceSettings.new()
		_device_settings.init_OS_language()
		_save_device_settings()

func _save_device_settings() -> void:
	ResourceSaver.save(_device_settings, get_device_settings_path())


# Teacher settings #

func get_teacher_folder() -> String:
	return "user://".path_join(_device_settings.teacher)

func _get_teacher_settings_path(teacher : String) -> String:
	return "user://".path_join(teacher).path_join("teacher_settings.tres")

func get_teacher_settings_path() -> String:
	return _get_teacher_settings_path(_device_settings.teacher)

func _load_teacher_settings() -> void:
	if FileAccess.file_exists(get_teacher_settings_path()):
		teacher_settings = load(get_teacher_settings_path())
	if not teacher_settings:
		_device_settings.teacher = ""
		_device_settings.device_id = 0
		_save_device_settings()

func _save_teacher_settings():
	ResourceSaver.save(teacher_settings, get_teacher_settings_path())

func add_device() -> bool:
	if not teacher_settings:
		return false
	
	# Checks if the logged user is a teacher (only teachers have several devices)
	if teacher_settings.account_type != TeacherSettings.AccountType.Teacher:
		return false
	
	# Gets the last device number
	if not teacher_settings.students:
		return false
	
	var device_id = teacher_settings.students.keys().back() + 1
	
	# Adds the new device
	var students_array : Array[StudentData] = []
	teacher_settings.students[device_id] = students_array
	
	# Saves the settings
	_save_teacher_settings()
	
	return true

func add_student(device_id : int, student_data : StudentData) -> bool:
	if not teacher_settings:
		return false
	
	# Finds the device
	if not teacher_settings.students or not teacher_settings.students.has(device_id):
		return false
	
	# Checks the student
	if not student_data:
		return false
	
	# Generates a password
	student_data.code = teacher_settings.get_new_code()
	if not student_data.code:
		return false
	
	# Adds the student on the device
	teacher_settings.students[device_id].append(student_data)
	
	# Saves the settings
	_save_teacher_settings()
	
	return true

func add_default_student(device_id : int) -> bool:
	return add_student(device_id, StudentData.new())

func delete_student(device_id : int, code : String) -> bool:
	if not teacher_settings:
		return false
	
	# Finds the device
	if not teacher_settings.students or not teacher_settings.students.has(device_id):
		return false
	
	# Finds the student
	var student_data : StudentData
	for s in teacher_settings.students[device_id]:
		if s.code == code:
			student_data = s
			break
	
	# Deletes the saves TODO
	
	# Removes the student
	teacher_settings.students[device_id].erase(student_data)
	
	# Saves the settings
	_save_teacher_settings()
	
	return true


# Student settings #

func get_student_folder() -> String:
	return _device_settings.get_folder_path().path_join(student)

func get_student_settings_path() -> String:
	return get_student_folder().path_join("settings.tres")

func _load_student_settings() -> void:
	# Load User settings
	if FileAccess.file_exists(get_student_settings_path()):
		student_settings = load(get_student_settings_path())
	
	if not student_settings:
		student_settings = UserSettings.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_settings()

func _save_student_settings() -> void:
	ResourceSaver.save(student_settings, get_student_settings_path())


# Student progression #

func get_student_progression_path() -> String:
	var file_path: = get_student_folder().path_join("progression.tres")
	return file_path

func _load_student_progression() -> void:
	if FileAccess.file_exists(get_student_progression_path()):
		student_progression = load(get_student_progression_path())
	
	if not student_progression:
		student_progression = UserProgression.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_progression()
	
		student_progression.unlocks_changed.connect(_on_user_progression_unlocks_changed)

func _save_student_progression() -> void:
	ResourceSaver.save(student_progression, get_student_progression_path())

func _on_user_progression_unlocks_changed() -> void:
	_save_student_progression()


# Sound settings #

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

# Convert the volume from [-80, 6]db to [0, 100] and back
func normalize_slider(volume) -> float:
	var value: = pow((volume + 80.0) / 86, 5.0) * 100.0
	return value

func denormalize_volume(value: float) -> float:
	var volume: = pow(float(value) / 100.0, 0.2) * 86 - 80
	return volume

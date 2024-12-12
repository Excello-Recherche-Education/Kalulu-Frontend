@tool
extends Node


var student: String = "" :
	set(student_name):
		student = student_name
		student_progression = null
		if student :
			_load_student_progression()
			_load_student_remediation()
			_load_student_difficulty()

var _device_settings: DeviceSettings
var teacher_settings: TeacherSettings
var student_progression: UserProgression
var _student_remediation: UserRemediation
var _student_difficulty: UserDifficulty


func _ready() -> void:
	if get_device_settings().teacher:
		_load_teacher_settings()


#region Registering and logging in

func register(register_settings : TeacherSettings) -> bool:
	if not register_settings:
		return false
	
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

# Allow the user to log-in from the server
func login(infos: Dictionary) -> bool:
	if not _device_settings or not infos:
		return false
	
	if not infos.has("email") or not infos.email:
		return false
	
	if not infos.has("account_type") or infos.account_type < 0 or infos.account_type > 1:
		return false
	
	if not infos.has("token") or not infos.token:
		return false
	
	# Handles device settings
	_device_settings.teacher = infos.email
	_save_device_settings()
	
	var path := get_teacher_settings_path()
	
	# Create the folder locally if it doesn't exists
	if not FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute(get_teacher_folder())
		teacher_settings = TeacherSettings.new()
	else:
		teacher_settings = load(path) as TeacherSettings
	
	teacher_settings.update_from_dict(infos)
	_save_teacher_settings()
	
	if teacher_settings.students.keys().size() == 1:
		set_device_id(teacher_settings.students.keys()[0])
	
	return true

func set_device_id(device: int) -> bool:
	if not _device_settings:
		return false
	
	if not device:
		return false
	
	_device_settings.device_id = device
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

func delete_teacher_data() -> void:
	if DirAccess.dir_exists_absolute(get_teacher_folder()):
		_delete_dir(get_teacher_folder())

func login_student(code : String) -> bool:
	if not _device_settings or not teacher_settings:
		return false
	
	var students: Array[StudentData] = teacher_settings.students[_device_settings.device_id] as Array[StudentData]
	if students:
		for s in students:
			if s.code == code:
				student = code
				return true
	
	return false

#endregion

#region Device settings

func get_device_settings_path() -> String:
	return "user://device_settings.tres"

func get_device_settings() -> DeviceSettings:
	if not _device_settings:
		_load_device_settings()
	return _device_settings

func _load_device_settings() -> void:
	if FileAccess.file_exists(get_device_settings_path()):
		_device_settings = load(get_device_settings_path())
		if not _device_settings.validate():
			_save_device_settings()
	if not _device_settings:
		_device_settings = DeviceSettings.new()
		_device_settings.init_OS_language()
		_save_device_settings()

func _save_device_settings() -> void:
	ResourceSaver.save(_device_settings, get_device_settings_path())

func set_language(language : String) -> void:
	if _device_settings:
		_device_settings.language = language
		_save_device_settings()

func set_language_version(language: String, version: Dictionary) -> void:
	if _device_settings:
		_device_settings.language_versions[language] = version
		_save_device_settings()

func set_master_volume(value: float) -> void:
	if _device_settings:
		var volume: = denormalize_volume(value)
		_device_settings.master_volume = volume
		_save_device_settings()

func set_music_volume(value: float) -> void:
	if _device_settings:
		var volume: = denormalize_volume(value)
		_device_settings.music_volume = volume
		_save_device_settings()

func set_voice_volume(value: float) -> void:
	if _device_settings:
		var volume: = denormalize_volume(value)
		_device_settings.voice_volume = volume
		_save_device_settings()

func set_effects_volume(value: float) -> void:
	if _device_settings:
		var volume: = denormalize_volume(value)
		_device_settings.effects_volume = volume
		_save_device_settings()

func get_master_volume() -> float:
	var value: = 0.0
	if _device_settings:
		var volume: = _device_settings.master_volume
		value = normalize_slider(volume)

	return value

func get_music_volume() -> float:
	var value: = 0.0
	if _device_settings:
		var volume: = _device_settings.music_volume
		value = normalize_slider(volume)

	return value

func get_voice_volume() -> float:
	var value: = 0.0
	if _device_settings:
		var volume: = _device_settings.voice_volume
		value = normalize_slider(volume)

	return value

func get_effects_volume() -> float:
	var value: = 0.0
	if _device_settings:
		var volume: = _device_settings.effects_volume
		value = normalize_slider(volume)

	return value

# Convert the volume from [-80, 6]db to [0, 100] and back
func normalize_slider(volume: float) -> float:
	var value: = pow((volume + 80.0) / 86, 5.0) * 100.0
	return value

func denormalize_volume(value: float) -> float:
	var volume: = pow(float(value) / 100.0, 0.2) * 86 - 80
	return volume

#endregion

#region Teacher settings

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

func _save_teacher_settings() -> void:
	ResourceSaver.save(teacher_settings, get_teacher_settings_path())

func _delete_inexistants_students_saves() -> void:
	if not teacher_settings:
		return
	
	var path: = get_teacher_folder()
	var dirc = DirAccess.open(path)
	if dirc:
		var directories: = dirc.get_directories()
		# Go through each device folder of the teacher
		for device in directories:
			print(device)
			
			# If the device does not exists, delete it
			if int(device) not in teacher_settings.students.keys():
				_delete_dir(path.path_join(device))
				dirc.remove(device)
				continue
			
			# Go through each language folder
			var device_dir: = DirAccess.open(path.path_join(device))
			for language in device_dir.get_directories():
				# Go through each student folder
				var language_dir: = DirAccess.open(path.path_join(device).path_join(language))
				for student in language_dir.get_directories():
					# Check if the folder is associated with an existing student
					var exists: = false
					for s: StudentData in teacher_settings.students[int(device)]:
						if s.code == student:
							exists = true
							break
					# If the code doesn't exists in the configuration, delete the folder
					if not exists:
						_delete_dir(path.path_join(device).path_join(language).path_join(student))
						language_dir.remove(student)

func update_configuration(configuration: Dictionary) -> bool:
	if not teacher_settings:
		return false
	
	if not configuration or not configuration.students or not configuration.last_modified:
		return false
	
	if teacher_settings.last_modified != configuration.last_modified:
		# Update the teacher resource
		teacher_settings.update_from_dict(configuration)
		_save_teacher_settings()
		
		# Check if the device still exists
		if not _device_settings.device_id in teacher_settings.students.keys():
			_device_settings.device_id = 0
			_save_device_settings()
		
		# Cleanup the saves
		_delete_inexistants_students_saves()
	
	return true

#endregion

#region Student settings

func get_student_folder() -> String:
	return _device_settings.get_folder_path().path_join(student)

#endregion

#region Student progression

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
	
	if student_progression.init_unlocks():
		_save_student_progression()
	student_progression.unlocks_changed.connect(_on_user_progression_unlocks_changed)

func _save_student_progression() -> void:
	ResourceSaver.save(student_progression, get_student_progression_path())

func _on_user_progression_unlocks_changed() -> void:
	_save_student_progression()


func get_student_progression_for_code(device: int, code: String) -> UserProgression:
	if not teacher_settings or not teacher_settings.students.has(device):
		return
	
	var student_path: String ="user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(code)
	var progression_path: String = student_path.path_join("progression.tres")
	
	var progression: UserProgression
	
	if FileAccess.file_exists(progression_path):
		progression = load(progression_path)
	else:
		progression = UserProgression.new()
		DirAccess.make_dir_recursive_absolute(student_path)
		#ResourceSaver.save(student_progression, progression_path)
	
	return progression

func save_student_progression_for_code(device: int, code: String, progression: UserProgression) -> void:
	var progression_path: String = "user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(code).path_join("progression.tres")
	ResourceSaver.save(progression, progression_path)

#endregion

#region Student remediation

func _get_student_remediation_path() -> String:
	return get_student_folder().path_join("remediation.tres")

func _load_student_remediation() -> void:
	if FileAccess.file_exists(_get_student_remediation_path()):
		_student_remediation = load(_get_student_remediation_path())
	
	if not _student_remediation:
		_student_remediation = UserRemediation.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_remediation()
	
	_student_remediation.score_changed.connect(_save_student_remediation)

func _save_student_remediation() -> void:
	ResourceSaver.save(_student_remediation, _get_student_remediation_path())

func get_GP_remediation_score(GPID: int) -> int:
	if not _student_remediation:
		#push_warning("No student remediation data for " + str(student))
		return 0
	return _student_remediation.get_score(GPID)

func update_remediation_scores(scores: Dictionary) -> void:
	if not _student_remediation:
		push_warning("No student remediation data for " + str(student))
		return
	if scores:
		_student_remediation.update_scores(scores)

#endregion

#region Student Difficulty

func _get_student_difficulty_path() -> String:
	return get_student_folder().path_join("difficulty.tres")

func _load_student_difficulty() -> void:
	if FileAccess.file_exists(_get_student_difficulty_path()):
		_student_difficulty = load(_get_student_difficulty_path())
	
	if not _student_difficulty:
		_student_difficulty = UserDifficulty.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_difficulty()
	
	_student_difficulty.difficulty_changed.connect(_save_student_difficulty)

func _save_student_difficulty() -> void:
	ResourceSaver.save(_student_difficulty, _get_student_difficulty_path())

func get_difficulty_for_minigame(minigame_name: String) -> int:
	if not _student_difficulty:
		push_warning("No student difficulty data for " + str(student))
		return 0
	return _student_difficulty.get_difficulty(minigame_name)

func update_difficulty_for_minigame(minigame_name: String, minigame_won: bool) -> void:
	if not _student_difficulty:
		push_warning("No student difficulty data for " + str(student))
		return
	_student_difficulty.add_game(minigame_name, minigame_won)

#endregion

func _delete_dir(path: String) -> void:
	var dir: = DirAccess.open(path)
	for file in dir.get_files():
		dir.remove(file)
	for subfolder in dir.get_directories():
		_delete_dir(path.path_join(subfolder))
		dir.remove(subfolder)

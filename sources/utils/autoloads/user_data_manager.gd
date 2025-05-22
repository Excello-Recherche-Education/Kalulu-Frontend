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
			_load_student_speeches()
		else:
			student_progression = null
			_student_difficulty = null
			_student_remediation = null
			_student_speeches = null

var _device_settings: DeviceSettings
var teacher_settings: TeacherSettings
var student_progression: UserProgression
var _student_remediation: UserRemediation
var _student_difficulty: UserDifficulty
var _student_speeches: UserSpeeches


func _ready() -> void:
	if get_device_settings().teacher:
		_load_teacher_settings()


#region Registering and logging in

func register(register_settings: TeacherSettings) -> bool:
	if not register_settings:
		return false
	
	# Handles device settings
	var device_settings: DeviceSettings = get_device_settings()
	device_settings.teacher = register_settings.email
	device_settings.device_id = 1
	_save_device_settings()
	
	# Save the teacher settings on disk
	DirAccess.make_dir_recursive_absolute(get_teacher_folder())
	teacher_settings = register_settings
	save_teacher_settings()
	
	return true

# Allow the user to log-in from the server
func login(infos: Dictionary) -> bool:
	if not _device_settings:
		Logger.error("UserDataManager: User cannot login because they have no _device_settings.")
		return false
		
	if not infos:
		Logger.error("UserDataManager: User cannot login because they have no _device_settings.")
		return false
	
	if not infos.has("email") or not infos.email:
		Logger.error("UserDataManager: User cannot login because they have no infos.")
		return false
	
	if not infos.has("account_type"):
		Logger.error("UserDataManager: User cannot login because they have no account_type.")
		return false
	
	if infos.account_type < 0 or infos.account_type > 1:
		Logger.error("UserDataManager: User cannot login because they have invalid account_type: " + str(infos.account_type))
		return false
	
	if not infos.has("token") or not infos.token:
		Logger.error("UserDataManager: User cannot login because they have no token.")
		return false
	
	# Handles device settings
	_device_settings.teacher = infos.email
	_save_device_settings()
	
	var path: String = get_teacher_settings_path()
	
	# Create the folder locally if it doesn't exists
	if not FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute(get_teacher_folder())
		teacher_settings = TeacherSettings.new()
	else:
		teacher_settings = load(path) as TeacherSettings
	
	teacher_settings.update_from_dict(infos)
	save_teacher_settings()
	
	if teacher_settings.students.keys().size() == 1:
		set_device_id(teacher_settings.students.keys()[0] as int)
	
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
		for stud: StudentData in students:
			if int(stud.code) == int(code):
				student = code
				(ServerManager as ServerManagerClass).first_login_student()
				return true
	
	return false

func logout_student() -> bool:
	if not _device_settings or not teacher_settings:
		return false
	
	student = ""
	return true

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
	Logger.trace("UserDataManager: Saving device settings in " + get_device_settings_path())
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
		var volume: float = denormalize_volume(value)
		_device_settings.master_volume = volume
		_save_device_settings()

func set_music_volume(value: float) -> void:
	if _device_settings:
		var volume: float = denormalize_volume(value)
		_device_settings.music_volume = volume
		_save_device_settings()

func set_voice_volume(value: float) -> void:
	if _device_settings:
		var volume: float = denormalize_volume(value)
		_device_settings.voice_volume = volume
		_save_device_settings()

func set_effects_volume(value: float) -> void:
	if _device_settings:
		var volume: float = denormalize_volume(value)
		_device_settings.effects_volume = volume
		_save_device_settings()

func get_master_volume() -> float:
	var value: float = 0.0
	if _device_settings:
		var volume: float = _device_settings.master_volume
		value = normalize_slider(volume)

	return value

func get_music_volume() -> float:
	var value: float = 0.0
	if _device_settings:
		var volume: float = _device_settings.music_volume
		value = normalize_slider(volume)

	return value

func get_voice_volume() -> float:
	var value: float = 0.0
	if _device_settings:
		var volume: float = _device_settings.voice_volume
		value = normalize_slider(volume)

	return value

func get_effects_volume() -> float:
	var value: float = 0.0
	if _device_settings:
		var volume: float = _device_settings.effects_volume
		value = normalize_slider(volume)

	return value

# Convert the volume from [-80, 6]db to [0, 100] and back
func normalize_slider(volume: float) -> float:
	var value: float = pow((volume + 80.0) / 86, 5.0) * 100.0
	return value

func denormalize_volume(value: float) -> float:
	var volume: float = pow(float(value) / 100.0, 0.2) * 86 - 80
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

func save_teacher_settings() -> void:
	ResourceSaver.save(teacher_settings, get_teacher_settings_path())

func _delete_inexistants_students_saves() -> void:
	if not teacher_settings:
		return
	
	var path: String = get_teacher_folder()
	var dirc: DirAccess = DirAccess.open(path)
	if dirc:
		var directories: PackedStringArray = dirc.get_directories()
		# Go through each device folder of the teacher
		for device: String in directories:
			# If the device does not exists, delete it
			if int(device) not in teacher_settings.students.keys():
				_delete_dir(path.path_join(device))
				dirc.remove(device)
				continue
			
			# Go through each language folder
			var device_dir: DirAccess = DirAccess.open(path.path_join(device))
			for language: String in device_dir.get_directories():
				# Go through each student folder
				var language_dir: DirAccess = DirAccess.open(path.path_join(device).path_join(language))
				for p_student: String in language_dir.get_directories():
					# Check if the folder is associated with an existing student
					var exists: bool = false
					for s: StudentData in teacher_settings.students[int(device)]:
						if str(s.code) == p_student:
							exists = true
							break
					# If the code doesn't exists in the configuration, delete the folder
					if not exists:
						_delete_dir(path.path_join(device).path_join(language).path_join(p_student))
						language_dir.remove(p_student)

func update_configuration(configuration: Dictionary) -> bool:
	if not teacher_settings:
		return false
	
	if not configuration or not configuration.students or not configuration.last_modified:
		return false
	
	if teacher_settings.last_modified != configuration.last_modified:
		# Update the teacher resource
		teacher_settings.update_from_dict(configuration)
		save_teacher_settings()
		
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
	var file_path: String = get_student_folder().path_join("progression.tres")
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


func get_student_progression_for_code(device: int, code: int) -> UserProgression:
	if not teacher_settings or not teacher_settings.students.has(device):
		return
	
	var student_path: String ="user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(code))
	var progression_path: String = student_path.path_join("progression.tres")
	
	var progression: UserProgression
	
	if FileAccess.file_exists(progression_path):
		progression = load(progression_path)
	else:
		progression = UserProgression.new()
		DirAccess.make_dir_recursive_absolute(student_path)
		#ResourceSaver.save(student_progression, progression_path)
	
	return progression

func save_student_progression_for_code(device: int, code: int, progression: UserProgression) -> void:
	var progression_path: String = "user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(code)).path_join("progression.tres")
	var error: Error = ResourceSaver.save(progression, progression_path)
	if error != OK:
		Logger.error("UserDataManager: save_student_progression_for_code(device = %s, code = %s): error %s" % [str(device), str(code), error_string(error)])

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
	return _student_remediation.get_gp_score(GPID)

func update_remediation_scores(scores: Dictionary) -> void:
	if not _student_remediation:
		Logger.warn("UserDataManager: No student remediation data for " + str(student))
		return
	if scores:
		_student_remediation.update_gp_scores(scores)

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
		Logger.warn("UserDataManager: No student difficulty data for " + str(student))
		return 0
	return _student_difficulty.get_difficulty(minigame_name)

func update_difficulty_for_minigame(minigame_name: String, minigame_won: bool) -> void:
	if not _student_difficulty:
		Logger.warn("UserDataManager: No student difficulty data for " + str(student))
		return
	_student_difficulty.add_game(minigame_name, minigame_won)

#endregion

#region Speeches

func _get_student_speeches_path() -> String:
	return get_student_folder().path_join("speeches.tres")

func _load_student_speeches() -> void:
	if FileAccess.file_exists(_get_student_speeches_path()):
		_student_speeches = load(_get_student_speeches_path())
	
	if not _student_speeches:
		_student_speeches = UserSpeeches.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_speeches()
	_student_speeches.speeches_changed.connect(_save_student_speeches)

func _save_student_speeches() -> void:
	ResourceSaver.save(_student_speeches, _get_student_speeches_path())

func mark_speech_as_played(speech: String) -> void:
	if not _student_speeches:
		Logger.warn("UserDataManager: No student speeches data for " + str(student))
		return
	_student_speeches.add_speech(speech)

func is_speech_played(speech: String) -> bool:
	if not _student_speeches:
		Logger.warn("UserDataManager: No student speeches data for " + str(student))
		return false
	return _student_speeches.is_speech_played(speech)
	
#endregion

#region utils

func _delete_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	for file: String in dir.get_files():
		dir.remove(file)
	for subfolder: String in dir.get_directories():
		_delete_dir(path.path_join(subfolder))
		dir.remove(subfolder)

func move_user_device_folder(old_device: String, new_device: String, student_code: int) -> void:
	var parentDirPath: String = "user://".path_join(_device_settings.teacher)
	var parentDir: DirAccess = DirAccess.open(parentDirPath)
	var oldChildDir: String = old_device.path_join(_device_settings.language).path_join(str(student_code))
	var newChildDir: String = new_device.path_join(_device_settings.language).path_join(str(student_code))
	var newParentDir: String = newChildDir.get_base_dir()  # = "2/fr_FR"
	if not parentDir.dir_exists(newParentDir):
		var err: Error = parentDir.make_dir_recursive(newParentDir)
		if err != OK:
			push_error("UserDataManager: Cannot create parent folder: %s" % error_string(err))
			return
	if parentDir.dir_exists(str(oldChildDir)):
		var err: Error = parentDir.rename(oldChildDir, newChildDir)
		if err != OK:
			Logger.error("UserDataManager: Error while renaming folder: %s" % error_string(err))
	else:
		Logger.error("UserDataManager: The folder '%s' cannot be moved because it does no exists in %s." % [old_device, parentDirPath])
		return
	save_teacher_settings()


func get_latest_modification(path: String) -> Dictionary:
	var result: Dictionary = {
		"error": OK,
		"modification_date": null
	}

	if FileAccess.file_exists(path):
		var time: int = FileAccess.get_modified_time(path)
		if time > 0:
			result.modification_date = Time.get_datetime_dict_from_unix_time(time)
		else:
			result.error = ERR_CANT_OPEN
		return result

	if not DirAccess.dir_exists_absolute(path):
		result.error = ERR_DOES_NOT_EXIST
		return result

	var latest_time: int = 0
	latest_time = _scan_dir_recursive(path, latest_time)

	if latest_time > 0:
		result.modification_date = Time.get_datetime_dict_from_unix_time(latest_time)
	else:
		result.error = ERR_FILE_NOT_FOUND  # Aucun fichier trouvé

	return result


func _scan_dir_recursive(dir_path: String, latest_time: int) -> int:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return latest_time

	dir.list_dir_begin()
	while true:
		var dirName: String = dir.get_next()
		if dirName == "":
			break
		if dirName.begins_with("."):
			continue

		var full_path: String = dir_path.path_join(dirName)
		if dir.current_is_dir():
			latest_time = _scan_dir_recursive(full_path, latest_time)
		else:
			var time: int = FileAccess.get_modified_time(full_path)
			if time > latest_time:
				latest_time = time
	dir.list_dir_end()

	return latest_time

#endregion

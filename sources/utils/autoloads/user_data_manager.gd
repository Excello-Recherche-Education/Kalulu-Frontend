class_name UserDataManagerClass
extends Node

const MASTER_VOLUME_PROPERTY_NAME: String = "master_volume"
const MUSIC_VOLUME_PROPERTY_NAME: String = "music_volume"
const VOICE_VOLUME_PROPERTY_NAME: String = "voice_volume"
const EFFECTS_VOLUME_PROPERTY_NAME: String = "effects_volume"

var student: String = "":
	set(student_name):
		student = student_name
		student_progression = null
		if student:
			_load_student_progression()
			_load_student_remediation()
			_load_student_confusion_matrix()
			_load_student_boss_data()
			_load_student_difficulty()
			_load_student_speeches()
		else:
			student_progression = null
			_student_difficulty = null
			_student_remediation = null
			_student_confusion_matrix = null
			_student_boss_data = null
			_student_speeches = null
var student_session_id: int = 0
var _device_settings: DeviceSettings
var teacher_settings: TeacherSettings
var student_progression: StudentProgression
var _student_remediation: UserRemediation
var _student_confusion_matrix: UserConfusionMatrix
var _student_boss_data: UserBossData
var _student_difficulty: UserDifficulty
var _student_speeches: UserSpeeches
var synchronization_timer: int = 0
var synchronization_timer_running: bool = false
var synchronization_time_limit: int = 300000 # 5 minutes in milliseconds
var now: int
var last_time: int = 0
var real_delta: int
var user_database_synchronizer: UserDatabaseSynchronizer = UserDatabaseSynchronizer.new()


func _ready() -> void:
	Log.info("UserDataManager initialization")
	if get_device_settings().teacher:
		_load_teacher_settings()
	
	purge_user_folders_if_needed()


func purge_user_folders_if_needed() -> void:
	# Never delete anything for prof_tool, let user do it, this is a technical app. Warning: since number version of prof_tool is a lot lower than kalulu, without this protection it would delete every time.
	var app_name: String = ProjectSettings.get_setting("application/config/name")
	if app_name.to_lower() != "kalulu":
		Log.warn("UserDataManager: Application name is not Kalulu, so user folder purge has been blocked.")
		return
	
	var current_version: String = Utils.get_application_config_version()
	var previous_version: String = _device_settings.game_version
	
	if previous_version == "" or Utils.compare_versions(previous_version, "2.1.3") < 0:
		Log.trace("UserDataManager: Version difference detected, need to purge user folder to avoid data incompatibility")
		var dir: DirAccess = DirAccess.open("user://")
		var error: Error = DirAccess.get_open_error()
		if error != OK:
			Log.error("UserDataManager: Could not open user:// directory for cleanup. Error: %s" % error_string(error))
			return
		if not dir:
			Log.warn("UserDataManager: Could not open user:// directory for cleanup.")
			return
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != ".." and file_name.to_lower() != "logs":
				Utils.delete_directory_recursive("user://".path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
		
		Log.trace("UserDataManager: Purge completed")
		_device_settings.game_version = current_version
		ResourceSaver.save(_device_settings, "user://device_settings.tres")


func clear_all_local_data() -> void:
	var error: Error = Utils.clean_dir("user://")
	if error != OK:
		Log.error("UserDataManager: Could not clean user:// directory. Error: %s" % error_string(error))
		return
	Log.warn("UserDataManager: All local user data cleared from user://")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return # Do nothing in editor mode
	if synchronization_timer_running:
		now = Time.get_ticks_msec()
		real_delta = now - last_time
		last_time = now
		synchronization_timer += real_delta
		if synchronization_timer >= synchronization_time_limit:
			synchronization_timer = 0
			Log.info("UserDataManager: Synchronization timer reached, launching synchronization")
			user_database_synchronizer.synchronize()

#region synchronization

func start_synchronization_timer() -> void:
	if not synchronization_timer_running:
		synchronization_timer = 0
		synchronization_timer_running = true
		Log.trace("UserDataManager: Synchronization timer started")


func stop_synchronization_timer() -> void:
	synchronization_timer_running = false
	Log.trace("UserDataManager: Synchronization timer stopped")

#endregion

#region Registering and logging in

func register(register_settings: TeacherSettings) -> bool:
	if not register_settings:
		Log.warn("UserDataManager: Register: Function called with invalid register_settings")
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
	Log.info("UserDataManager: Register successful for user %s" % register_settings.email)
	return true


# Allow the user to log-in from the server
func login(infos: Dictionary) -> bool:
	if not _device_settings:
		Log.error("UserDataManager: User cannot login because they have no _device_settings.")
		return false
		
	if not infos:
		Log.error("UserDataManager: User cannot login because they have no _device_settings.")
		return false
	
	if not infos.has("email") or not infos.email:
		Log.error("UserDataManager: User cannot login because they have no infos.")
		return false
	
	if not infos.has("account_type"):
		Log.error("UserDataManager: User cannot login because they have no account_type.")
		return false
	
	if infos.account_type < 0 or infos.account_type > 1:
		Log.error("UserDataManager: User cannot login because they have invalid account_type: " + str(infos.account_type))
		return false
	
	if not infos.has("token") or not infos.token:
		Log.error("UserDataManager: User cannot login because they have no token.")
		return false
	
	# Handles device settings
	_device_settings.teacher = infos.email
	_save_device_settings()
	
	var path: String = get_teacher_settings_path()
	
	# Create the folder locally if it does not exist.
	if not FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute(get_teacher_folder())
		teacher_settings = TeacherSettings.new()
	else:
		teacher_settings = safe_load_and_fix_resource(path, 
				["res://resources/user/children_data.gd"],
				["res://resources/user/student_data.gd"]) as TeacherSettings
	
	teacher_settings.update_from_dict(infos)
	save_teacher_settings()
	
	if teacher_settings.students.keys().size() == 1:
		set_device_id(teacher_settings.students.keys()[0] as int)
	
	Log.info("UserDataManager: Login successful for teacher %s" % infos.email)
	return true


## Safely loads a resource from the given path.  
## If the file contains outdated text patterns (old_texts), they are replaced with new ones before loading.  
func safe_load_and_fix_resource(path: String, old_texts: Array[String], new_texts: Array[String]) -> Resource:
	if not FileAccess.file_exists(path):
		Log.error("UserDataManager: File not found: " + path)
		return null
	if old_texts.size() != new_texts.size():
		Log.error(
				"UserDataManager: Safe load and fix resource: Mismatching text arrays for %s (old: %d, new: %d)" % [
						path, old_texts.size(), new_texts.size(),
				]
		)
		return ResourceLoader.load(path)
	var content: String = FileAccess.get_file_as_string(path)
	var replacement_made: bool = false
	for index: int in range(old_texts.size()):
		if content.find(old_texts[index]) != -1:
			Log.trace("UserDataManager: Fix resource:" + path)
			content = content.replace(old_texts[index], new_texts[index])
			replacement_made = true
	if replacement_made:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		var error: Error = FileAccess.get_open_error()
		if error != OK:
			Log.error("UserDataManager: Safe load and fix resource: Cannot open file %s. Error: %s" % [path, error_string(error)])
		elif file == null:
			Log.error("UserDataManager: Safe load and fix resource: Cannot open file %s. File is null" % path)
		else:
			file.store_string(content)
			file.close()
	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		Log.error("UserDataManager: Loading failed after correction: " + path)
	else:
		Log.trace("UserDataManager: Loading success: " + path)
	return resource


func set_device_id(device: int) -> bool:
	if not _device_settings:
		Log.warn("UserDataManager: SetDeviceID: Function called with no device settings loaded")
		return false
	
	if not device:
		Log.warn("UserDataManager: SetDeviceID: Function called with invalid device ID")
		return false
	
	_device_settings.device_id = device
	_save_device_settings()
	Log.trace("UserDataManager: Device ID set to %d" % device)
	return true


func logout() -> void:
	_device_settings.teacher = ""
	_device_settings.device_id = 0
	_save_device_settings()
	teacher_settings = null
	if student:
		student = ""
	Log.info("UserDataManager: Logout complete - device, teacher, and student data cleared")


func delete_teacher_data() -> void:
	if DirAccess.dir_exists_absolute(get_teacher_folder()):
		Utils.delete_directory_recursive(get_teacher_folder())
		Log.info("UserDataManager: Teacher data deleted from %s" % get_teacher_folder())
	else:
		Log.warn("UserDataManager: No teacher data folder found at %s" % get_teacher_folder())


func student_exists(code: String) -> bool:
	if not _device_settings:
		Log.trace("UserDataManager: StudentExists: Function failed because of invalid _device_settings")
		return false
	if not teacher_settings:
		Log.trace("UserDataManager: StudentExists: Function failed because of invalid teacher_settings")
		return false
	if not teacher_settings.students.has(_device_settings.device_id):
		Log.warn("UserDataManager: StudentExists: Function failed because of device ID %d not in students dictionary" % _device_settings.device_id)
		return false
	var students: Array[StudentData] = teacher_settings.students[_device_settings.device_id] as Array[StudentData]
	if students:
		for stud: StudentData in students:
			if int(stud.code) == int(code):
				return true
	return false


func login_student(code: String) -> bool:
	if not _device_settings:
		Log.warn("UserDataManager: LoginStudent: Function failed because of invalid _device_settings")
		return false
	if not teacher_settings:
		Log.warn("UserDataManager: LoginStudent: Function failed because of invalid teacher_settings")
		return false
	if not teacher_settings.students.has(_device_settings.device_id):
		Log.warn("UserDataManager: LoginStudent: Function failed because of device ID %d not in students dictionary" % _device_settings.device_id)
		return false
	
	var students: Array[StudentData] = teacher_settings.students[_device_settings.device_id] as Array[StudentData]
	if students:
		for stud: StudentData in students:
			if int(stud.code) == int(code):
				student = code
				_start_student_session()
				(ServerManager as ServerManagerClass).first_login_student()
				Log.info("UserDataManager: Student %s logged in" % code)
				return true
	
	Log.warn("UserDataManager: LoginStudent: Code not found: " + code)
	return false


func logout_student() -> bool:
	if not _device_settings:
		Log.warn("UserDataManager: LogoutStudent: Function failed because of invalid _device_settings")
		return false
	if not teacher_settings:
		Log.warn("UserDataManager: LogoutStudent: Function failed because of invalid teacher_settings")
		return false
	
	_start_student_session(true)
	student = ""
	Log.info("UserDataManager: Student logged out")
	return true


func get_student_session_id() -> int:
	return student_session_id


func _start_student_session(reset_only: bool = false) -> void:
	if reset_only:
		student_session_id = 0
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	student_session_id = rng.randi()
	while student_session_id == 0:
		student_session_id = rng.randi()
	Log.trace("UserDataManager: New student session id %s" % str(student_session_id))

#endregion

#region Device settings

func get_device_settings_path() -> String:
	return "user://device_settings.tres"


func get_device_settings() -> DeviceSettings:
	if not _device_settings:
		_load_device_settings()
	return _device_settings


func _load_device_settings() -> void:
	Log.info("UserDataManager: Load device settings")
	var settings_path: String = get_device_settings_path()
	if FileAccess.file_exists(settings_path):
		_device_settings = load(settings_path)
		if _device_settings:
			Log.current_level = _device_settings.log_level
			if not _device_settings.validate():
				Log.error("UserDataManager: Device settings at %s failed validation. Regenerating saved data." % ProjectSettings.globalize_path(settings_path))
				_save_device_settings()
		else:
			Log.error("UserDataManager: Failed to load device settings from %s. Recreating defaults." % ProjectSettings.globalize_path(settings_path))
	else:
		Log.warn("UserDataManager: Device settings file not found at %s. Creating defaults." % ProjectSettings.globalize_path(settings_path))
	if not _device_settings:
		_device_settings = DeviceSettings.new()
		_device_settings.init_os_language()
		_save_device_settings()


func _save_device_settings() -> void:
	var path: String = get_device_settings_path()
	Log.trace("UserDataManager: Save device settings in " + ProjectSettings.globalize_path(path))
	var error: Error = ResourceSaver.save(_device_settings, path)
	if error != OK:
		Log.error("UserDataManager: Failed to save device settings to %s. Error: %s" % [path, error_string(error)])
	else:
		Log.trace("UserDataManager: Device settings saved successfully at " + ProjectSettings.globalize_path(path))


func set_language(language: String, server_validated: bool = false) -> void:
	Log.trace("UserDataManager: Set language %s, %s" % [language, str(server_validated)] )
	if _device_settings:
		_device_settings.language = language
		_save_device_settings()
	if teacher_settings and not teacher_settings.server_language_validated:
		teacher_settings.language = language
		if server_validated:
			teacher_settings.server_language_validated = true


func get_language() -> String:
	if teacher_settings and teacher_settings.language:
		return teacher_settings.language
	elif _device_settings and _device_settings.language:
		return _device_settings.language
	return OS.get_locale()


func set_language_version(language: String, version: Dictionary) -> void:
	if _device_settings:
		_device_settings.language_versions[language] = version
		_save_device_settings()
	else:
		Log.warn("UserDataManager: Cannot set language version because device settings not found")


func _set_volume(property_name: String, value: float) -> void:
	if not _device_settings:
		return
	var volume: float = denormalize_volume(value)
	_device_settings.set(property_name, volume)
	_save_device_settings()


func _get_volume(property_name: String) -> float:
	if not _device_settings:
		return 0.0
	var volume: float = _device_settings.get(property_name)
	if volume == null:
		return 0.0
	return normalize_slider(volume)


func set_master_volume(value: float) -> void:
	_set_volume(MASTER_VOLUME_PROPERTY_NAME, value)


func set_music_volume(value: float) -> void:
	_set_volume(MUSIC_VOLUME_PROPERTY_NAME, value)


func set_voice_volume(value: float) -> void:
	_set_volume(VOICE_VOLUME_PROPERTY_NAME, value)


func set_effects_volume(value: float) -> void:
	_set_volume(EFFECTS_VOLUME_PROPERTY_NAME, value)


func get_master_volume() -> float:
	return _get_volume(MASTER_VOLUME_PROPERTY_NAME)


func get_music_volume() -> float:
	return _get_volume(MUSIC_VOLUME_PROPERTY_NAME)


func get_voice_volume() -> float:
	return _get_volume(VOICE_VOLUME_PROPERTY_NAME)


func get_effects_volume() -> float:
	return _get_volume(EFFECTS_VOLUME_PROPERTY_NAME)


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


func _get_teacher_settings_path(teacher: String) -> String:
	return "user://".path_join(teacher).path_join("teacher_settings.tres")


func get_teacher_settings_path() -> String:
	return _get_teacher_settings_path(_device_settings.teacher)


func _load_teacher_settings() -> void:
	if FileAccess.file_exists(get_teacher_settings_path()):
		Log.info("UserDataManager: Loading teacher settings from %s" % ProjectSettings.globalize_path(get_teacher_settings_path()))
		teacher_settings = safe_load_and_fix_resource(get_teacher_settings_path(),
				["res://resources/user/children_data.gd"],
				["res://resources/user/student_data.gd"]) as TeacherSettings
	else:
		Log.warn("UserDataManager: Teacher settings file not found at %s" % ProjectSettings.globalize_path(get_teacher_settings_path()))
	if not teacher_settings:
		_device_settings.teacher = ""
		_device_settings.device_id = 0
		_save_device_settings()


func save_teacher_settings() -> void:
	if not teacher_settings:
		Log.warn("UserDataManager: Cannot save teacher settings because teacher_settings is null")
		return
	var path: String = get_teacher_settings_path()
	Log.trace("UserDataManager: Saving teacher settings in " + ProjectSettings.globalize_path(path))
	var error: Error = ResourceSaver.save(teacher_settings, path)
	if error != OK:
		Log.error("UserDataManager: Failed to save teacher settings to %s. Error: %s" % [ProjectSettings.globalize_path(path), error_string(error)])
	else:
		Log.trace("UserDataManager: Teacher settings saved successfully at " + ProjectSettings.globalize_path(path))


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
				Utils.delete_directory_recursive(path.path_join(device))
				continue
			
			# Go through each language folder
			var device_dir: DirAccess = DirAccess.open(path.path_join(device))
			for language: String in device_dir.get_directories():
				# Go through each student folder
				var language_dir: DirAccess = DirAccess.open(path.path_join(device).path_join(language))
				for p_student: String in language_dir.get_directories():
					# Check if the folder is associated with an existing student
					var exists: bool = false
					for s_data: StudentData in teacher_settings.students[int(device)]:
						if str(s_data.code) == p_student:
							exists = true
							break
					# If the code does not exist in the configuration, delete the folder.
					if not exists:
						Utils.delete_directory_recursive(path.path_join(device).path_join(language).path_join(p_student))


func update_configuration(configuration: Dictionary) -> bool:
	if not teacher_settings:
		Log.warn("UserDataManager: Cannot update configuration because teacher_settings is null")
		return false
	
	if not configuration or not configuration.students or not configuration.last_modified:
		Log.warn("UserDataManager: Configuration update skipped because payload is invalid or incomplete")
		return false
	
	if teacher_settings.last_modified != configuration.last_modified:
		Log.trace("UserDataManager: Updating teacher configuration (last_modified=%s)" % str(configuration.last_modified))
		# Update the teacher resource
		teacher_settings.update_from_dict(configuration)
		save_teacher_settings()
		
		# Check if the device still exists
		if not _device_settings.device_id in teacher_settings.students.keys():
			_device_settings.device_id = 0
			_save_device_settings()
			Log.warn("UserDataManager: Device ID not found in updated configuration; device ID reset to 0")
		
		# Cleanup the saves
		_delete_inexistants_students_saves()
	else:
		Log.trace("UserDataManager: Configuration already up to date")
	
	return true


func get_number_of_students() -> int:
	if not teacher_settings:
		return 0
	return teacher_settings.get_number_of_students()

#endregion

#region Student settings

func get_student_folder(student_code: int = 0) -> String:
	if student_code == 0:
		return _device_settings.get_folder_path().path_join(student)
	else:
		return _device_settings.get_folder_path().path_join(str(student_code))


func delete_student(student_code: int) -> void:
	teacher_settings.delete_student(student_code)

#endregion

#region Student progression

func get_student_progression_path(device: int = 0, student_code: int = 0) -> String:
	if student_code == 0:
		return get_student_folder().path_join("progression.tres")
	elif device == 0 and student_code != 0:
		return find_student_dir(student_code).path_join("progression.tres")
	else:
		var student_path: String ="user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(student_code))
		var remediation_path: String = student_path.path_join("progression.tres")
		return remediation_path


func _load_student_progression() -> void:
	var progression_path: String = get_student_progression_path()
	Log.trace("UserDataManager: Loading student progression from " + ProjectSettings.globalize_path(progression_path))
	if FileAccess.file_exists(progression_path):
		student_progression = safe_load_and_fix_resource(progression_path,
			["res://resources/user/user_progression.gd", "UserProgression"],
			["res://resources/user/student_progression.gd", "StudentProgression"])
	
	if not student_progression:
		student_progression = StudentProgression.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_progression()
		Log.info("UserDataManager: Created new student progression at " + ProjectSettings.globalize_path(progression_path))
	else:
		Log.trace("UserDataManager: Loaded student progression from " + ProjectSettings.globalize_path(progression_path))
	
	student_progression.init_unlocks()
	student_progression.progression_changed.connect(_on_user_progression_changed)


func _save_student_progression() -> void:
	var progression_path: String = get_student_progression_path()
	Log.trace("UserDataManager: Saving student progression in " + ProjectSettings.globalize_path(progression_path))
	var error: Error = ResourceSaver.save(student_progression, progression_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save student progression to %s. Error: %s" % [progression_path, error_string(error)])
	else:
		Log.trace("UserDataManager: Student progression saved successfully at " + ProjectSettings.globalize_path(progression_path))


func _on_user_progression_changed() -> void:
	_save_student_progression()


func get_student_progression_for_code(device: int, code: int) -> StudentProgression:
	if device == 0:
		var device_path: String = find_device_dir_for_student(code)
		var device_name: String = device_path.get_file()
		if device_name.is_valid_int():
			device = int(device_name)
		else:
			return null
	if not teacher_settings or not teacher_settings.students.has(device):
		return
	
	var student_path: String ="user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(code))
	var progression_path: String = student_path.path_join("progression.tres")
	
	var progression: StudentProgression
	
	if FileAccess.file_exists(progression_path):
		progression = safe_load_and_fix_resource(progression_path,
				["res://resources/user/user_progression.gd", "UserProgression"],
				["res://resources/user/student_progression.gd", "StudentProgression"])

	else:
		Log.info("UserDataManager: Creating student progression for device %s code %s at %s" % [str(device), str(code), ProjectSettings.globalize_path(progression_path)])
		progression = StudentProgression.new()
		progression.last_modified = ""
		DirAccess.make_dir_recursive_absolute(student_path)
		ResourceSaver.save(progression, progression_path)
	
	return progression


func save_student_progression_for_code(device: int, code: int, progression: StudentProgression) -> void:
	var progression_path: String = "user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(code)).path_join("progression.tres")
	Log.trace("UserDataManager: Saving progression for device %s code %s in %s" % [str(device), str(code), ProjectSettings.globalize_path(progression_path)])
	var error: Error = ResourceSaver.save(progression, progression_path)
	if error != OK:
		Log.error("UserDataManager: SaveStudentProgressionForCode: Device = %s, Code = %s: error %s" % [str(device), str(code), error_string(error)])
	else:
		Log.trace("UserDataManager: Saved progression for device %s code %s" % [str(device), str(code)])


func set_student_progression_data(student_code: int, version: String, new_data: Dictionary[int, Dictionary], updated_at: String, highest_boss_defeated: int = -1) -> void:
	Log.trace("UserDataManager: Setting student progression data for code %s version %s" % [str(student_code), version])
	var current_data: StudentProgression = get_student_progression_for_code(0, student_code)
	if current_data == null:
		current_data = StudentProgression.new()
	current_data.version = version
	current_data.unlocks = new_data
	if highest_boss_defeated >= 0:
		current_data.highest_boss_defeated = highest_boss_defeated
	current_data.last_modified = updated_at
	var err: Error = ResourceSaver.save(current_data, get_student_progression_path(0, student_code))
	if err != OK:
		Log.error("UserDataManager: Error while saving student progression: %s" % error_string(err))
	else:
		Log.trace("UserDataManager: Student progression updated for code %s" % str(student_code))


func add_level_time(lesson_number: int, game_number: int, time_spent: int) -> void:
	if not student_progression:
		Log.warn("UserDataManager: Cannot save time spent in level because data of student progression cannot be found")
		return
	student_progression.add_level_time(lesson_number, game_number, time_spent)

#endregion

#region Student remediation

func _get_student_remediation_path(device: int = 0, student_code: int = 0) -> String:
	if student_code == 0:
		return get_student_folder().path_join("remediation.tres")
	elif device == 0 and student_code != 0:
		return find_student_dir(student_code).path_join("remediation.tres")
	else:
		var student_path: String ="user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(student_code))
		var remediation_path: String = student_path.path_join("remediation.tres")
		return remediation_path


func _load_student_remediation() -> void:
	var remediation_path: String = _get_student_remediation_path()
	Log.trace("UserDataManager: Loading student remediation from " + ProjectSettings.globalize_path(remediation_path))
	if FileAccess.file_exists(remediation_path):
		_student_remediation = load(remediation_path)
	
	if not _student_remediation:
		_student_remediation = UserRemediation.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_remediation()
		Log.info("UserDataManager: Created new student remediation at " + ProjectSettings.globalize_path(remediation_path))
	else:
		Log.trace("UserDataManager: Loaded student remediation from " + ProjectSettings.globalize_path(remediation_path))
	_student_remediation.score_changed.connect(_save_student_remediation)


func get_student_remediation_data(student_code: int) -> UserRemediation:
	var remediation_data_path: String = _get_student_remediation_path(0, student_code)
	if FileAccess.file_exists(remediation_data_path):
		var student_remediation: UserRemediation
		student_remediation = load(remediation_data_path)
		return student_remediation
	Log.trace("UserDataManager: Remediation data of student code %d not found" % student_code)
	return null


func set_student_remediation_gp_data(student_code: int, new_scores: Dictionary[int, int], updated_at: String) -> void:
	var remediation_data_path: String = _get_student_remediation_path(0, student_code)
	var student_remediation: UserRemediation
	if FileAccess.file_exists(remediation_data_path):
		student_remediation = load(remediation_data_path)
	else:
		student_remediation = UserRemediation.new()
	student_remediation.set_gp_scores(new_scores)
	student_remediation.set_gp_last_modified(updated_at)
	var error: Error = ResourceSaver.save(student_remediation, remediation_data_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save remediation GP data to %s. Error: %s" % [remediation_data_path, error_string(error)])


func set_student_remediation_syllables_data(student_code: int, new_scores: Dictionary[int, int], updated_at: String) -> void:
	var remediation_data_path: String = _get_student_remediation_path(0, student_code)
	var student_remediation: UserRemediation
	if FileAccess.file_exists(remediation_data_path):
		student_remediation = load(remediation_data_path)
	else:
		student_remediation = UserRemediation.new()
	student_remediation.set_syllables_scores(new_scores)
	student_remediation.set_syllables_last_modified(updated_at)
	var error: Error = ResourceSaver.save(student_remediation, remediation_data_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save remediation syllables data to %s. Error: %s" % [remediation_data_path, error_string(error)])


func set_student_remediation_words_data(student_code: int, new_scores: Dictionary[int, int], updated_at: String) -> void:
	var remediation_data_path: String = _get_student_remediation_path(0, student_code)
	var student_remediation: UserRemediation
	if FileAccess.file_exists(remediation_data_path):
		student_remediation = load(remediation_data_path)
	else:
		student_remediation = UserRemediation.new()
	student_remediation.set_words_scores(new_scores)
	student_remediation.set_words_last_modified(updated_at)
	var error: Error = ResourceSaver.save(student_remediation, remediation_data_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save remediation words data to %s. Error: %s" % [remediation_data_path, error_string(error)])


func _save_student_remediation() -> void:
	var remediation_path: String = _get_student_remediation_path()
	Log.trace("UserDataManager: Saving student remediation in " + ProjectSettings.globalize_path(remediation_path))
	var error: Error = ResourceSaver.save(_student_remediation, remediation_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save student remediation to %s. Error: %s" % [remediation_path, error_string(error)])
	else:
		Log.trace("UserDataManager: Student remediation saved successfully at " + ProjectSettings.globalize_path(remediation_path))


func get_gp_remediation_score(gp_id: int) -> int:
	if not _student_remediation:
		return 0
	return _student_remediation.get_gp_score(gp_id)


func update_remediation_gp_scores(remediation_gp_scores: Dictionary) -> void:
	if not _student_remediation:
		Log.warn("UserDataManager: No student remediation data for " + str(student))
		return
	if remediation_gp_scores:
		_student_remediation.update_gp_scores(remediation_gp_scores)


func update_remediation_syllables_scores(remediation_syllables_scores: Dictionary) -> void:
	if not _student_remediation:
		Log.warn("UserDataManager: No student remediation data for " + str(student))
		return
	if remediation_syllables_scores:
		_student_remediation.update_syllables_scores(remediation_syllables_scores)


func update_remediation_words_scores(remediation_words_scores: Dictionary) -> void:
	if not _student_remediation:
		Log.warn("UserDataManager: No student remediation data for " + str(student))
		return
	if remediation_words_scores:
		_student_remediation.update_words_scores(remediation_words_scores)

#endregion

#region Student Confusion Matrix

func _get_student_confusion_matrix_path(device: int = 0, student_code: int = 0) -> String:
	if student_code == 0:
		return get_student_folder().path_join("confusion_matrix.tres")
	elif device == 0 and student_code != 0:
		return find_student_dir(student_code).path_join("confusion_matrix.tres")
	else:
		var student_path: String ="user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(student_code))
		var confusion_matrix_path: String = student_path.path_join("confusion_matrix.tres")
		return confusion_matrix_path


func _load_student_confusion_matrix() -> void:
	var confusion_path: String = _get_student_confusion_matrix_path()
	Log.trace("UserDataManager: Loading student confusion matrix from " + ProjectSettings.globalize_path(confusion_path))
	if FileAccess.file_exists(confusion_path):
		_student_confusion_matrix = load(confusion_path)
	
	if not _student_confusion_matrix:
		_student_confusion_matrix = UserConfusionMatrix.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_confusion_matrix()
		Log.info("UserDataManager: Created new student confusion matrix at " + ProjectSettings.globalize_path(confusion_path))
	else:
		Log.trace("UserDataManager: Loaded student confusion matrix from " + ProjectSettings.globalize_path(confusion_path))
	_student_confusion_matrix.score_changed.connect(_save_student_confusion_matrix)


func get_student_confusion_matrix_data(student_code: int) -> UserConfusionMatrix:
	var confusion_matrix_data_path: String = _get_student_confusion_matrix_path(0, student_code)
	if FileAccess.file_exists(confusion_matrix_data_path):
		var student_confusion_matrix: UserConfusionMatrix
		student_confusion_matrix = load(confusion_matrix_data_path)
		return student_confusion_matrix
	Log.trace("UserDataManager: Confusion matrix data of student code %d not found" % student_code)
	return null


func set_student_confusion_matrix_gp_data(student_code: int, new_scores: Dictionary[int, PackedInt32Array], updated_at: String) -> void:
	var confusion_matrix_data_path: String = _get_student_confusion_matrix_path(0, student_code)
	var student_confusion_matrix: UserConfusionMatrix
	if FileAccess.file_exists(confusion_matrix_data_path):
		student_confusion_matrix = load(confusion_matrix_data_path)
	else:
		student_confusion_matrix = UserConfusionMatrix.new()
	student_confusion_matrix.set_gp_scores(new_scores)
	student_confusion_matrix.set_gp_last_modified(updated_at)
	var error: Error = ResourceSaver.save(student_confusion_matrix, confusion_matrix_data_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save confusion matrix GP data to %s. Error: %s" % [confusion_matrix_data_path, error_string(error)])


func _save_student_confusion_matrix() -> void:
	var confusion_matrix_path: String = _get_student_confusion_matrix_path()
	Log.trace("UserDataManager: Saving student confusion_matrix in " + ProjectSettings.globalize_path(confusion_matrix_path))
	var error: Error = ResourceSaver.save(_student_confusion_matrix, confusion_matrix_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save student confusion matrix to %s. Error: %s" % [confusion_matrix_path, error_string(error)])
	else:
		Log.trace("UserDataManager: Student confusion matrix saved successfully at " + ProjectSettings.globalize_path(confusion_matrix_path))


func get_gp_confusion_matrix_score(gp_id: int) -> PackedInt32Array:
	if not _student_confusion_matrix:
		return []
	return _student_confusion_matrix.get_gp_scores(gp_id)


func update_confusion_matrix_gp_scores(confusion_matrix_gp_scores: Dictionary) -> void:
	if not _student_confusion_matrix:
		Log.warn("UserDataManager: No student confusion matrix data for " + str(student))
		return
	if confusion_matrix_gp_scores:
		_student_confusion_matrix.update_gp_scores(confusion_matrix_gp_scores)

#endregion

#region Student Boss Data

func _get_student_boss_data_path(device: int = 0, student_code: int = 0) -> String:
	if student_code == 0:
		return get_student_folder().path_join("boss.tres")
	elif device == 0 and student_code != 0:
		return find_student_dir(student_code).path_join("boss.tres")
	else:
		var student_path: String ="user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(student_code))
		var boss_path: String = student_path.path_join("boss.tres")
		return boss_path


func _load_student_boss_data() -> void:
	var boss_path: String = _get_student_boss_data_path()
	Log.trace("UserDataManager: Loading student boss data from " + ProjectSettings.globalize_path(boss_path))
	if FileAccess.file_exists(boss_path):
		_student_boss_data = load(boss_path)
	
	if not _student_boss_data:
		_student_boss_data = UserBossData.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_boss_data()
		Log.info("UserDataManager: Created new student boss data at " + ProjectSettings.globalize_path(boss_path))
	else:
		Log.trace("UserDataManager: Loaded student boss data from " + ProjectSettings.globalize_path(boss_path))
	_student_boss_data.boss_data_changed.connect(_save_student_boss_data)


func _save_student_boss_data() -> void:
	var boss_path: String = _get_student_boss_data_path()
	Log.trace("UserDataManager: Saving student boss data in " + ProjectSettings.globalize_path(boss_path))
	var error: Error = ResourceSaver.save(_student_boss_data, boss_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save student boss data to %s. Error: %s" % [boss_path, error_string(error)])
	else:
		Log.trace("UserDataManager: Student boss data saved successfully at " + ProjectSettings.globalize_path(boss_path))


func get_student_boss_data(student_code: int) -> UserBossData:
	var boss_data_path: String = _get_student_boss_data_path(0, student_code)
	if FileAccess.file_exists(boss_data_path):
		var student_boss_data: UserBossData
		student_boss_data = load(boss_data_path)
		return student_boss_data
	Log.trace("UserDataManager: Boss data of student code %d not found" % student_code)
	return null


func start_boss_session(timestamp: int) -> int:
	if not _student_boss_data:
		Log.warn("UserDataManager: No student boss data for " + str(student))
		return -1
	return _student_boss_data.start_session(timestamp)


func record_boss_answer(session_index: int, is_real_word: bool, word_length: int, response_time_ms: int, is_correct: bool) -> void:
	if not _student_boss_data:
		Log.warn("UserDataManager: No student boss data for " + str(student))
		return
	_student_boss_data.add_answer(session_index, is_real_word, word_length, response_time_ms, is_correct)


func finish_boss_session(session_index: int, victory: bool) -> void:
	if not _student_boss_data:
		Log.warn("UserDataManager: No student boss data for " + str(student))
		return
	_student_boss_data.finish_session(session_index, victory)

#endregion

#region Student Difficulty

func _get_student_difficulty_path() -> String:
	return get_student_folder().path_join("difficulty.tres")


func _load_student_difficulty() -> void:
	var difficulty_path: String = _get_student_difficulty_path()
	Log.trace("UserDataManager: Loading student difficulty from " + ProjectSettings.globalize_path(difficulty_path))
	if FileAccess.file_exists(difficulty_path):
		_student_difficulty = load(difficulty_path)
	
	if not _student_difficulty:
		_student_difficulty = UserDifficulty.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_difficulty()
		Log.info("UserDataManager: Created new student difficulty at " + ProjectSettings.globalize_path(difficulty_path))
	else:
		Log.trace("UserDataManager: Loaded student difficulty from " + ProjectSettings.globalize_path(difficulty_path))
	_student_difficulty.difficulty_changed.connect(_save_student_difficulty)


func _save_student_difficulty() -> void:
	var difficulty_path: String = _get_student_difficulty_path()
	Log.trace("UserDataManager: Saving student difficulty in " + ProjectSettings.globalize_path(difficulty_path))
	var error: Error = ResourceSaver.save(_student_difficulty, difficulty_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save student difficulty to %s. Error: %s" % [difficulty_path, error_string(error)])
	else:
		Log.trace("UserDataManager: Student difficulty saved successfully at " + ProjectSettings.globalize_path(difficulty_path))


func get_difficulty_for_minigame(minigame_name: String) -> int:
	if not _student_difficulty:
		Log.warn("UserDataManager: No student difficulty data for " + str(student))
		return 0
	return _student_difficulty.get_difficulty(minigame_name)


func update_difficulty_for_minigame(minigame_name: String, minigame_won: bool) -> void:
	if not _student_difficulty:
		Log.warn("UserDataManager: No student difficulty data for " + str(student))
		return
	_student_difficulty.add_game(minigame_name, minigame_won)

#endregion

#region Speeches

func _get_student_speeches_path() -> String:
	return get_student_folder().path_join("speeches.tres")


func _load_student_speeches() -> void:
	var speeches_path: String = _get_student_speeches_path()
	Log.trace("UserDataManager: Loading student speeches from " + ProjectSettings.globalize_path(speeches_path))
	if FileAccess.file_exists(speeches_path):
		_student_speeches = load(speeches_path)
	
	if not _student_speeches:
		_student_speeches = UserSpeeches.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_speeches()
		Log.info("UserDataManager: Created new student speeches at " + ProjectSettings.globalize_path(speeches_path))
	else:
		Log.trace("UserDataManager: Loaded student speeches from " + ProjectSettings.globalize_path(speeches_path))
	_student_speeches.speeches_changed.connect(_save_student_speeches)


func _save_student_speeches() -> void:
	var speeches_path: String = _get_student_speeches_path()
	Log.trace("UserDataManager: Saving student speeches in " + ProjectSettings.globalize_path(speeches_path))
	var error: Error = ResourceSaver.save(_student_speeches, speeches_path)
	if error != OK:
		Log.error("UserDataManager: Failed to save student speeches to %s. Error: %s" % [speeches_path, error_string(error)])
	else:
		Log.trace("UserDataManager: Student speeches saved successfully at " + ProjectSettings.globalize_path(speeches_path))


func mark_speech_as_played(speech: String) -> void:
	if not _student_speeches:
		if not Engine.is_editor_hint():
			Log.warn("UserDataManager: No student speeches data for " + str(student))
		return
	_student_speeches.add_speech(speech)


func is_speech_played(speech: String) -> bool:
	if not _student_speeches:
		if not Engine.is_editor_hint():
			Log.warn("UserDataManager: No student speeches data for " + str(student))
		return false
	return _student_speeches.is_speech_played(speech)
	
#endregion

#region utils

func move_user_device_folder(old_device: String, new_device: String, student_code: int) -> void:
	var parent_dir_path: String = "user://".path_join(_device_settings.teacher)
	var parent_dir: DirAccess = DirAccess.open(parent_dir_path)
	var old_child_dir: String = old_device.path_join(_device_settings.language).path_join(str(student_code))
	var new_child_dir: String = new_device.path_join(_device_settings.language).path_join(str(student_code))
	var new_parent_dir: String = new_child_dir.get_base_dir()
	if not parent_dir.dir_exists(new_parent_dir):
		var err: Error = parent_dir.make_dir_recursive(new_parent_dir)
		if err != OK:
			Log.error("UserDataManager: Cannot create parent folder: %s" % error_string(err))
			return
	if parent_dir.dir_exists(str(old_child_dir)):
		var err: Error = parent_dir.rename(old_child_dir, new_child_dir)
		if err != OK:
			Log.error("UserDataManager: Error while renaming folder: %s" % error_string(err))
		else:
			Log.trace("UserDataManager: Student folder moved successfully to %s" % new_child_dir)
	else:
		Log.error("UserDataManager: The folder '%s' cannot be moved because it does no exists in %s." % [old_device, parent_dir_path])
		return
	save_teacher_settings()


func find_student_dir(student_code: int) -> String:
	return _scan_teacher_devices(func(_device_dir: String, lang_dir: String, sub_file: String) -> String:
		if sub_file == str(student_code):
			return lang_dir.path_join(sub_file)
		return "")


func find_device_dir_for_student(student_code: int) -> String:
	return _scan_teacher_devices(func(device_dir: String, _lang_dir: String, sub_file: String) -> String:
		if sub_file == str(student_code):
			return device_dir
		return "")


func _scan_teacher_devices(match_callback: Callable) -> String:
	var teacher_path: String = "user://".path_join(_device_settings.teacher)
	var dir: DirAccess = DirAccess.open(teacher_path)
	if not dir:
		Log.error("UserDataManager: Impossible to open teacher folder: %s" % teacher_path)
		return ""

	var language: String = _device_settings.language

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name.is_valid_int():
			var device_dir: String = teacher_path.path_join(file_name)
			var lang_dir: String = device_dir.path_join(language)

			if DirAccess.dir_exists_absolute(lang_dir):
				var lang_subdir: DirAccess = DirAccess.open(lang_dir)
				if lang_subdir:
					lang_subdir.list_dir_begin()
					var sub_file: String = lang_subdir.get_next()
					while sub_file != "":
						if lang_subdir.current_is_dir():
							var result: Variant = match_callback.call(device_dir, lang_dir, sub_file)
							if result != "":
								return result
						sub_file = lang_subdir.get_next()
					lang_subdir.list_dir_end()
			else:
				Log.warn("UserDataManager: Device folder %s has no language sub-folder" % device_dir)    

		file_name = dir.get_next()
	dir.list_dir_end()
	return ""


func save_all() -> void:
	Log.info("UserDataManager: Saving all user data - Started")
	_save_device_settings()
	save_teacher_settings()
	if student_progression != null:
		_save_student_progression()
	if _student_remediation != null:
		_save_student_remediation()
	if _student_confusion_matrix != null:
		_save_student_confusion_matrix()
	if _student_difficulty != null:
		_save_student_difficulty()
	if _student_speeches != null:
		_save_student_speeches()
	Log.info("UserDataManager: Saving all user data - Finished")

#endregion

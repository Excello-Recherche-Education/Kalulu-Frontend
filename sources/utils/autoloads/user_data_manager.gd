extends Node


var student: String = "":
	set(student_name):
		student = student_name
		student_progression = null
		if student:
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
var student_progression: StudentProgression
var _student_remediation: UserRemediation
var _student_difficulty: UserDifficulty
var _student_speeches: UserSpeeches

var user_database_synchronizer: UserDatabaseSynchronizer
var synchronization_timer: int = 0
var synchronization_timer_running: bool = false
var synchronization_time_limit: int = 300000 # 5 minutes in milliseconds
var now: int
var last_time: int = 0
var real_delta: int

func _ready() -> void:
	if get_device_settings().teacher:
		_load_teacher_settings()
	
	purge_user_folders_if_needed()
	
	user_database_synchronizer = UserDatabaseSynchronizer.new()

func purge_user_folders_if_needed() -> void:
	var current_version: String = ProjectSettings.get_setting("application/config/version")
	var previous_version: String = _device_settings.game_version
	
	if previous_version == "" or compare_versions(previous_version, "2.1.3") < 0:
		Logger.trace("UserDataManager: Version difference detected, need to purge user folder to avoid data incompatibility")
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if dir.current_is_dir() and file_name != "." and file_name != "..":
					var full_path: String = "user://".path_join(file_name)
					Utils.delete_dir(full_path)
					var err: Error = DirAccess.remove_absolute(full_path)
					if err != OK:
						Logger.error("UserDataManager: Failed to delete folder %s. Error %s" % [full_path, error_string(err)])
				file_name = dir.get_next()
			dir.list_dir_end()
		
		Logger.trace("UserDataManager: Purge completed")
		_device_settings.game_version = current_version
		ResourceSaver.save(_device_settings, "user://device_settings.tres")


func compare_versions(version_a: String, version_b: String) -> int:
	var va: PackedStringArray = version_a.split(".")
	var vb: PackedStringArray = version_b.split(".")
	
	for index: int in 3:
		var ai: int = int(va[index]) if index < va.size() else 0
		var bi: int = int(vb[index]) if index < vb.size() else 0
		if ai < bi:
			return -1
		elif ai > bi:
			return 1
	return 0

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
			user_database_synchronizer.synchronize()

#region synchronization

func start_synchronization_timer() -> void:
	if not synchronization_timer_running:
		synchronization_timer = 0
		synchronization_timer_running = true


func stop_synchronization_timer() -> void:
	synchronization_timer_running = false

#endregion

#region Registering and logging in

func register(register_settings: TeacherSettings) -> bool:
	if not register_settings:
		Logger.warn("UserDataManager: register called with invalid register_settings")
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
		teacher_settings = safe_load_and_fix_resource(path, 
				["res://resources/user/children_data.gd"],
				["res://resources/user/student_data.gd"]) as TeacherSettings
	
	teacher_settings.update_from_dict(infos)
	save_teacher_settings()
	
	if teacher_settings.students.keys().size() == 1:
		set_device_id(teacher_settings.students.keys()[0] as int)
	
	return true

func safe_load_and_fix_resource(path: String, old_texts: Array[String], new_texts: Array[String]) -> Resource:
	if not FileAccess.file_exists(path):
		Logger.error("UserDataManager: File not found: " + path)
		return null

	var content: String = FileAccess.get_file_as_string(path)

	for index: int in range(old_texts.size()):
		if content.find(old_texts[index]) != -1:
			Logger.info("UserDataManager: Fix resource:" + path)
			content = content.replace(old_texts[index], new_texts[index])
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			file.store_string(content)
			file.close()

	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		Logger.error("UserDataManager: Loading failed after correction: " + path)
	else:
		Logger.trace("UserDataManager: Loading success: " + path)
	return resource

func set_device_id(device: int) -> bool:
	if not _device_settings:
		Logger.warn("UserDataManager: set_device_id called with no device settings loaded")
		return false
	
	if not device:
		Logger.warn("UserDataManager: set_device_id called with invalid device")
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
		Utils.delete_dir(get_teacher_folder())

func student_exists(code: String) -> bool:
	if not _device_settings:
		Logger.trace("UserDataManager: student_exists called with invalid _device_settings")
		return false
	if not teacher_settings:
		Logger.trace("UserDataManager: student_exists called with invalid teacher_settings")
		return false
	var students: Array[StudentData] = teacher_settings.students[_device_settings.device_id] as Array[StudentData]
	if students:
		for stud: StudentData in students:
			if int(stud.code) == int(code):
				return true
	return false

func login_student(code: String) -> bool:
	if not _device_settings:
		Logger.warn("UserDataManager: login_student failed because of invalid _device_settings")
		return false
	if not teacher_settings:
		Logger.warn("UserDataManager: login_student failed because of invalid teacher_settings")
		return false
	
	var students: Array[StudentData] = teacher_settings.students[_device_settings.device_id] as Array[StudentData]
	if students:
		for stud: StudentData in students:
			if int(stud.code) == int(code):
				student = code
				(ServerManager as ServerManagerClass).first_login_student()
				return true
	
	Logger.warn("UserDataManager: login_student failed, code not found: " + code)
	return false

func logout_student() -> bool:
	if not _device_settings:
		Logger.warn("UserDataManager: logout_student failed because of invalid _device_settings")
		return false
	if not teacher_settings:
		Logger.warn("UserDataManager: logout_student failed because of invalid teacher_settings")
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
		_device_settings.init_os_language()
		_save_device_settings()

func _save_device_settings() -> void:
	Logger.trace("UserDataManager: Saving device settings in " + ProjectSettings.globalize_path(get_device_settings_path()))
	ResourceSaver.save(_device_settings, get_device_settings_path())

func set_language(language: String) -> void:
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

func _get_teacher_settings_path(teacher: String) -> String:
	return "user://".path_join(teacher).path_join("teacher_settings.tres")

func get_teacher_settings_path() -> String:
	return _get_teacher_settings_path(_device_settings.teacher)

func _load_teacher_settings() -> void:
	if FileAccess.file_exists(get_teacher_settings_path()):
		teacher_settings = safe_load_and_fix_resource(get_teacher_settings_path(),
				["res://resources/user/children_data.gd"],
				["res://resources/user/student_data.gd"]) as TeacherSettings
	if not teacher_settings:
		_device_settings.teacher = ""
		_device_settings.device_id = 0
		_save_device_settings()

func save_teacher_settings() -> void:
	Logger.trace("UserDataManager: Saving teacher settings in " + ProjectSettings.globalize_path(get_teacher_settings_path()))
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
				Utils.delete_dir(path.path_join(device))
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
					for s_data: StudentData in teacher_settings.students[int(device)]:
						if str(s_data.code) == p_student:
							exists = true
							break
					# If the code doesn't exists in the configuration, delete the folder
					if not exists:
						Utils.delete_dir(path.path_join(device).path_join(language).path_join(p_student))
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
	if FileAccess.file_exists(get_student_progression_path()):
		student_progression = safe_load_and_fix_resource(	get_student_progression_path(),
				["res://resources/user/user_progression.gd", "UserProgression"],
				["res://resources/user/student_progression.gd", "StudentProgression"])
	
	if not student_progression:
		student_progression = StudentProgression.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_progression()
	
	student_progression.init_unlocks()
	student_progression.unlocks_changed.connect(_on_user_progression_unlocks_changed)

func _save_student_progression() -> void:
	Logger.trace("UserDataManager: Saving student progression in " + ProjectSettings.globalize_path(get_student_progression_path()))
	ResourceSaver.save(student_progression, get_student_progression_path())

func _on_user_progression_unlocks_changed() -> void:
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
		progression = StudentProgression.new()
		progression.last_modified = Time.get_datetime_string_from_system(true)
		DirAccess.make_dir_recursive_absolute(student_path)
		ResourceSaver.save(progression, progression_path)
	
	return progression

func save_student_progression_for_code(device: int, code: int, progression: StudentProgression) -> void:
	var progression_path: String = "user://".path_join(_device_settings.teacher).path_join(str(device)).path_join(_device_settings.language).path_join(str(code)).path_join("progression.tres")
	var error: Error = ResourceSaver.save(progression, progression_path)
	if error != OK:
		Logger.error("UserDataManager: save_student_progression_for_code(device = %s, code = %s): error %s" % [str(device), str(code), error_string(error)])

func set_student_progression_data(student_code: int, version: String, new_data: Dictionary, updated_at: String) -> void:
	var current_data: StudentProgression = get_student_progression_for_code(0, student_code)
	if current_data == null:
		current_data = StudentProgression.new()
	current_data.version = version
	current_data.unlocks = new_data
	current_data.last_modified = updated_at
	var err: Error = ResourceSaver.save(current_data, get_student_progression_path(0, student_code))
	if err != OK:
		Logger.error("UserDataManager: Error while saving student progression: %s" % error_string(err))

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
	if FileAccess.file_exists(_get_student_remediation_path()):
		_student_remediation = load(_get_student_remediation_path())
	
	if not _student_remediation:
		_student_remediation = UserRemediation.new()
		DirAccess.make_dir_recursive_absolute(get_student_folder())
		_save_student_remediation()
	
	_student_remediation.score_changed.connect(_save_student_remediation)

func get_student_remediation_data(student_code: int) -> UserRemediation:
	var remediation_data_path: String = _get_student_remediation_path(0, student_code)
	if FileAccess.file_exists(remediation_data_path):
		var student_remediation: UserRemediation
		student_remediation = load(remediation_data_path)
		return student_remediation
	Logger.trace("UserDataManager: Remediation data of student code %d not found" % student_code)
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
	ResourceSaver.save(student_remediation, remediation_data_path)

func set_student_remediation_syllables_data(student_code: int, new_scores: Dictionary[int, int], updated_at: String) -> void:
	var remediation_data_path: String = _get_student_remediation_path(0, student_code)
	var student_remediation: UserRemediation
	if FileAccess.file_exists(remediation_data_path):
		student_remediation = load(remediation_data_path)
	else:
		student_remediation = UserRemediation.new()
	student_remediation.set_syllables_scores(new_scores)
	student_remediation.set_syllables_last_modified(updated_at)
	ResourceSaver.save(student_remediation, remediation_data_path)

func set_student_remediation_words_data(student_code: int, new_scores: Dictionary[int, int], updated_at: String) -> void:
	var remediation_data_path: String = _get_student_remediation_path(0, student_code)
	var student_remediation: UserRemediation
	if FileAccess.file_exists(remediation_data_path):
		student_remediation = load(remediation_data_path)
	else:
		student_remediation = UserRemediation.new()
	student_remediation.set_words_scores(new_scores)
	student_remediation.set_words_last_modified(updated_at)
	ResourceSaver.save(student_remediation, remediation_data_path)

func _save_student_remediation() -> void:
	Logger.trace("UserDataManager: Saving student remediation in " + ProjectSettings.globalize_path(_get_student_remediation_path()))
	ResourceSaver.save(_student_remediation, _get_student_remediation_path())

func get_gp_remediation_score(gp_id: int) -> int:
	if not _student_remediation:
		return 0
	return _student_remediation.get_gp_score(gp_id)

func update_remediation_gp_scores(gp_scores: Dictionary) -> void:
	if not _student_remediation:
		Logger.warn("UserDataManager: No student remediation data for " + str(student))
		return
	if gp_scores:
		_student_remediation.update_gp_scores(gp_scores)

func update_remediation_syllables_scores(syllables_scores: Dictionary) -> void:
	if not _student_remediation:
		Logger.warn("UserDataManager: No student remediation data for " + str(student))
		return
	if syllables_scores:
		_student_remediation.update_syllables_scores(syllables_scores)

func update_remediation_words_scores(words_scores: Dictionary) -> void:
	if not _student_remediation:
		Logger.warn("UserDataManager: No student remediation data for " + str(student))
		return
	if words_scores:
		_student_remediation.update_words_scores(words_scores)

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
	Logger.trace("UserDataManager: Saving student difficulty in " + ProjectSettings.globalize_path(_get_student_difficulty_path()))
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
	Logger.trace("UserDataManager: Saving student speeches in " + ProjectSettings.globalize_path(_get_student_speeches_path()))
	ResourceSaver.save(_student_speeches, _get_student_speeches_path())

func mark_speech_as_played(speech: String) -> void:
	if not _student_speeches:
		if not Engine.is_editor_hint():
			Logger.warn("UserDataManager: No student speeches data for " + str(student))
		return
	_student_speeches.add_speech(speech)

func is_speech_played(speech: String) -> bool:
	if not _student_speeches:
		if not Engine.is_editor_hint():
			Logger.warn("UserDataManager: No student speeches data for " + str(student))
		return false
	return _student_speeches.is_speech_played(speech)
	
#endregion

#region utils

func move_user_device_folder(old_device: String, new_device: String, student_code: int) -> void:
	var parent_dir_path: String = "user://".path_join(_device_settings.teacher)
	var parent_dir: DirAccess = DirAccess.open(parent_dir_path)
	var old_child_dir: String = old_device.path_join(_device_settings.language).path_join(str(student_code))
	var new_child_dir: String = new_device.path_join(_device_settings.language).path_join(str(student_code))
	var new_parent_dir: String = new_child_dir.get_base_dir() # = "2/fr_FR"
	if not parent_dir.dir_exists(new_parent_dir):
		var err: Error = parent_dir.make_dir_recursive(new_parent_dir)
		if err != OK:
			push_error("UserDataManager: Cannot create parent folder: %s" % error_string(err))
			return
	if parent_dir.dir_exists(str(old_child_dir)):
		var err: Error = parent_dir.rename(old_child_dir, new_child_dir)
		if err != OK:
			Logger.error("UserDataManager: Error while renaming folder: %s" % error_string(err))
	else:
		Logger.error("UserDataManager: The folder '%s' cannot be moved because it does no exists in %s." % [old_device, parent_dir_path])
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
		Logger.error("UserDataManager: Impossible to open teacher folder: %s" % teacher_path)
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
				Logger.warn("UserDataManager: Device folder %s has no language sub-folder" % device_dir)    

		file_name = dir.get_next()
	dir.list_dir_end()
	return ""

func save_all() -> void:
	_save_device_settings()
	save_teacher_settings()
	if student_progression != null:
		_save_student_progression()
	if _student_remediation != null:
		_save_student_remediation()
	if _student_difficulty != null:
		_save_student_difficulty()
	if _student_speeches != null:
		_save_student_speeches()

#endregion

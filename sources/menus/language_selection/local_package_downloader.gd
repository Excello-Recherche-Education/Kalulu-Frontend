extends Control

const next_scene_path: = "res://sources/menus/main/main_menu.tscn"

const language_resources_path: =  "user://language_resources"

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var data_label: Label = %DataLabel

var mutex: Mutex
var thread: Thread

func _ready() -> void:
	await get_tree().process_frame
	
	if not DirAccess.dir_exists_absolute(language_resources_path.path_join(UserDataManager.get_device_settings().language)):
		mutex = Mutex.new()
		thread = Thread.new()
		thread.start(_copy_data.bind(self))
	else:
		_go_to_main_menu()


func _exit_tree() -> void:
	if thread:
		thread.wait_to_finish()


func _copy_data(this: Control) -> void:
	var unzipper: = FolderUnzipper.new()
	
	unzipper.file_count.connect(
		func(count: int) -> void:
			mutex.lock()
			this.progress_bar.set_deferred("max_value", count)
			mutex.unlock()
	)
	
	unzipper.file_copied.connect(
		func(count: int, name: String) -> void:
			mutex.lock()
			this.data_label.set_deferred("text", name)
			this.progress_bar.set_deferred("value", count)
			mutex.unlock()
	)
	
	unzipper.extract("res://fr_FR.zip", language_resources_path, false)
	this.call_thread_safe("_go_to_main_menu")


func _go_to_main_menu() -> void:
	if not Database.is_open:
		Database.connect_to_db()
	get_tree().change_scene_to_file(next_scene_path)

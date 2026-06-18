class_name DeveloperSettings
extends Control

const LOG_LEVEL_ELEMENT: PackedScene = preload("res://sources/menus/settings/log_level_element.tscn")
const CLEAR_LOCAL_DATA_CONFIRMATIONS: int = 5
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 3.0
const ZOOM_STEP_WHEEL: float = 0.1

static var return_path: String = "res://sources/menus/main/main_menu.tscn"

var filters: Dictionary[int, bool] = {}
var line_steps: PackedInt32Array = [10, 50, 100, 200, 500, 1000, -1] # -1 = all
var loglevel_regex: RegEx
var clear_local_data_confirmations: int = 0
var showing_previous_session_logs: bool = false
var previous_session_logs: PackedStringArray = []
var zoom_level: float = 1.0


@onready var slider: HSlider = $VBoxContainer/Controls/LineCountSlider
@onready var slider_label: Label = $VBoxContainer/Controls/SliderLabel
@onready var toggle_log_source_button: Button = $VBoxContainer/Controls/ToggleLogSourceButton
@onready var log_level_dropdown: OptionButton = $VBoxContainer/LogControls/LogLevelDropdown
@onready var filters_container: HBoxContainer = $VBoxContainer/Filters
@onready var log_text: TextEdit = $VBoxContainer/ColorRect/LogText
@onready var api_path_input: LineEdit = $VBoxContainer/ApiPathControls/PathRow/ApiPathEdit
@onready var api_path_status_label: Label = $VBoxContainer/ApiPathControls/StatusLabel
@onready var prod_button: Button = $VBoxContainer/ApiPathControls/EnvironmentButtons/ProdButton
@onready var dev_button: Button = $VBoxContainer/ApiPathControls/EnvironmentButtons/DevButton
@onready var clear_local_data_popup: ConfirmPopup = $VBoxContainer/DangerZoneContainer/DangerZoneButtonRow/ClearLocalDataButton/ClearLocalDataPopup
@onready var restart_required_popup: ConfirmPopup = $RestartRequiredPopup


func _ready() -> void:
	slider.min_value = 0
	slider.max_value = line_steps.size() - 1
	slider.step = 1
	slider.value = 5
	
	var levels: Array[String] = []
	log_level_dropdown.clear()
	for level_name: String in Log.LogLevel.keys():
		var value: int = Log.LogLevel[level_name]
		log_level_dropdown.add_item(level_name, value)
		if level_name != "NONE":
			levels.append(level_name)
			var element: LogLevelElement = LOG_LEVEL_ELEMENT.instantiate()
			filters_container.add_child(element)
			element.log_level.text = level_name
			element.check_box.button_pressed = Log.current_level <= value
			element.check_box.toggled.connect(_on_filters_changed.bind(value))
			_on_filters_changed(Log.current_level <= value, value)
	
	var pattern: String = "\\[(" + "|".join(levels) + ")\\]"
	loglevel_regex = RegEx.new()
	loglevel_regex.compile(pattern)
	
	log_level_dropdown.select(Log.current_level)
	log_level_dropdown.item_selected.connect(_on_level_changed)
	
	slider.value_changed.connect(_on_slider_changed)
	toggle_log_source_button.pressed.connect(_on_toggle_log_source_button_pressed)
	_update_log_source_button_text()
	_update_log_text()
	
	api_path_input.text = ServerManager.environment_url
	api_path_input.text_submitted.connect(_on_api_path_submitted)
	api_path_status_label.text = ""
	
	await OpeningCurtain.open()


func _update_log_text() -> void:
	var idx: int = int(slider.value)
	var lines_to_show: int = line_steps[idx]
	var source_logs: PackedStringArray = _get_logs_source()
	var total: int = source_logs.size()
	
	var subset: PackedStringArray
	if lines_to_show == -1:
		slider_label.text = "Show: all (%d lines)" % total
		subset = source_logs
	else:
		slider_label.text = "Show: %d last lines" % lines_to_show
		var start: int = maxi(total - lines_to_show, 0)
		subset = source_logs.slice(start, total)
	
	var filtered: Array[String] = []
	for line: String in subset:
		var level: int = _extract_log_level(line)
		if level == -1:
			filtered.append(line)
		elif filters.has(level) and filters[level]:
			filtered.append(line)
	
	log_text.text = "\n".join(filtered)
	if showing_previous_session_logs and filtered.is_empty():
		log_text.text = "No previous session logs found."
	log_text.scroll_vertical = log_text.get_line_count() # Scroll down


func _get_logs_source() -> PackedStringArray:
	if not showing_previous_session_logs:
		return Log.all_logs
	if previous_session_logs.is_empty():
		previous_session_logs = Log.get_previous_session_logs()
	return previous_session_logs


func _extract_log_level(line: String) -> int:
	var result: RegExMatch = loglevel_regex.search(line)
	if result:
		var log_level_name: String = result.get_string(1) # "DEBUG", "INFO"…
		if Log.LogLevel.has(log_level_name):
			return Log.LogLevel[log_level_name]
	return -1


func _on_level_changed(_index: int) -> void:
	var selected_level: Log.LogLevel = log_level_dropdown.get_selected_id() as Log.LogLevel
	Log.current_level = selected_level
	UserDataManager.get_device_settings().log_level = selected_level
	UserDataManager._save_device_settings()
	Log.info("DeveloperSettings: Log level changed to %s" % Log.LogLevel.keys()[selected_level])


func _on_filters_changed(checked: bool, index: int) -> void:
	filters[index] = checked
	Log.trace("DeveloperSettings: Filters changed: %s" % str(filters))
	if loglevel_regex != null:
		_update_log_text()


func _input(event: InputEvent) -> void:
	# Pinch to zoom on mobile
	if event is InputEventMagnifyGesture:
		var magnify_event: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		var new_zoom: float = clampf(zoom_level * magnify_event.factor, ZOOM_MIN, ZOOM_MAX)
		_apply_zoom(new_zoom, magnify_event.position)
		get_viewport().set_input_as_handled()
	# Mouse wheel zoom on desktop
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			var new_zoom: float = zoom_level
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				new_zoom = clampf(zoom_level + ZOOM_STEP_WHEEL, ZOOM_MIN, ZOOM_MAX)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				new_zoom = clampf(zoom_level - ZOOM_STEP_WHEEL, ZOOM_MIN, ZOOM_MAX)
			if new_zoom != zoom_level:
				_apply_zoom(new_zoom, mouse_event.position)
				get_viewport().set_input_as_handled()


func _apply_zoom(new_zoom: float, screen_pos: Vector2) -> void:
	# Convert screen position to local (pre-scale) coordinates
	var local_pos: Vector2 = (screen_pos - pivot_offset) / zoom_level + pivot_offset
	# Shift the pivot so the point under the gesture/cursor stays fixed on screen
	if not is_equal_approx(new_zoom, 1.0):
		pivot_offset = (screen_pos - local_pos * new_zoom) / (1.0 - new_zoom)
	zoom_level = new_zoom
	scale = Vector2(zoom_level, zoom_level)


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	if return_path == "":
		return_path = "res://sources/menus/main/main_menu.tscn"
	get_tree().change_scene_to_file(return_path)


func _on_slider_changed(_value: float) -> void:
	_update_log_text()


func _on_toggle_log_source_button_pressed() -> void:
	showing_previous_session_logs = not showing_previous_session_logs
	if showing_previous_session_logs:
		previous_session_logs = Log.get_previous_session_logs()
	_update_log_source_button_text()
	_update_log_text()


func _update_log_source_button_text() -> void:
	if showing_previous_session_logs:
		toggle_log_source_button.text = "Show current session logs"
		return
	toggle_log_source_button.text = "Show previous session logs"


func _on_api_path_submitted(_value: String) -> void:
	_update_api_path()


func _on_api_path_apply_pressed() -> void:
	_update_api_path()


func _on_clear_local_data_button_pressed() -> void:
	clear_local_data_confirmations = 0
	clear_local_data_popup.content_text = tr("CLEAR_LOCAL_DATA_CONFIRM") % 5
	clear_local_data_popup.show()


func _on_clear_local_data_popup_accepted() -> void:
	clear_local_data_confirmations += 1
	if clear_local_data_confirmations >= CLEAR_LOCAL_DATA_CONFIRMATIONS:
		clear_local_data_confirmations = 0
		UserDataManager.delete_teacher_data()
		UserDataManager.logout()
		UserDataManager.clear_all_local_data()
		await get_tree().process_frame
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		await get_tree().process_frame
		get_tree().set_auto_accept_quit(true)
		get_tree().quit()
		await get_tree().process_frame
		await get_tree().process_frame
		_show_restart_required_popup()
		return
	clear_local_data_popup.content_text = tr("CLEAR_LOCAL_DATA_CONFIRM") % (5 - clear_local_data_confirmations)
	await get_tree().process_frame
	clear_local_data_popup.show()


func _on_clear_local_data_popup_refused() -> void:
	clear_local_data_confirmations = 0


func _show_restart_required_popup() -> void:
	restart_required_popup.content_text = tr("RESTART_APP_REQUIRED")
	restart_required_popup.close_on_action = false
	restart_required_popup.set_buttons_visible(false)
	restart_required_popup.set_buttons_enabled(false)
	restart_required_popup.show()


func _on_prod_button_pressed() -> void:
	_set_environment(1, "PROD")


func _on_dev_button_pressed() -> void:
	_set_environment(0, "DEV")


func _set_environment(env: int, label: String) -> void:
	Log.info("DeveloperSettings: Selecting %s environment (env=%d)" % [label, env])
	(ServerManager as ServerManagerClass).set_environment(env)
	api_path_input.text = (ServerManager as ServerManagerClass).environment_url
	api_path_status_label.text = "%s environment selected" % label


func _update_api_path() -> void:
	var new_path: String = api_path_input.text
	Log.info("DeveloperSettings: Updating API path to %s" % new_path)
	(ServerManager as ServerManagerClass).set_environment_url(new_path)
	api_path_input.text = (ServerManager as ServerManagerClass).environment_url
	api_path_status_label.text = "AWS API path updated"

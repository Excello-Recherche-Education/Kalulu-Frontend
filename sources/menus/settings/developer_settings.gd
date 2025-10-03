class_name DeveloperSettings
extends Control

#const MAIN_MENU_PATH: String = "res://sources/menus/main/main_menu.tscn"
const LOGIN_MENU_PATH: String = "res://sources/menus/login/login.tscn"
const LOG_LEVEL_ELEMENT: PackedScene = preload("res://sources/menus/settings/log_level_element.tscn")
#const DEVICE_SELECTION_SCENE_PATH: String = "res://sources/menus/device_selection/device_selection.tscn"
#const DEVICE_TAB_SCENE: PackedScene = preload("res://sources/menus/settings/device_tab.tscn")
#
#var last_device_id: int = -1
#
#@onready var devices_tab_container: TabContainer = %DevicesTabContainer
#@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks
#@onready var delete_popup: ConfirmPopup = %DeletePopup
#@onready var loading_popup: LoadingPopup = %LoadingPopup
#@onready var account_type_option_button: OptionButton = %AccountTypeOptionButton
#@onready var education_method_option_button: OptionButton = %EducationMethodOptionButton
#@onready var add_device_button: Button = %AddDeviceButton
#@onready var add_student_button: Button = %AddStudentButton
#@onready var label_internet_mandatory: Label = %LabelInternetMandatory
#@onready var add_device_popup: CanvasLayer = %AddDevicePopup
#@onready var add_student_popup: CanvasLayer = %AddStudentPopup
#@onready var delete_student_popup: CanvasLayer = %DeleteStudentPopup

var filters: Dictionary[int, bool] = {}
var line_steps: PackedInt32Array = [10, 50, 100, 200, 500, 1000, -1] # -1 = all
var loglevel_regex: RegEx

@onready var slider: HSlider = $VBoxContainer/Controls/LineCountSlider
@onready var slider_label: Label = $VBoxContainer/Controls/SliderLabel
@onready var log_level_dropdown: OptionButton = $VBoxContainer/LogControls/LogLevelDropdown
@onready var filters_container: HBoxContainer = $VBoxContainer/Filters
@onready var log_text: TextEdit = $VBoxContainer/ColorRect/LogText


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
	
	log_level_dropdown.item_selected.connect(_on_level_changed)
	
	slider.value_changed.connect(_on_slider_changed)
	_update_log_text()
	
	await OpeningCurtain.open()


func _update_log_text() -> void:
	var idx: int = int(slider.value)
	var lines_to_show: int = line_steps[idx]
	var total: int = Log.all_logs.size()
	
	var subset: PackedStringArray
	if lines_to_show == -1:
		slider_label.text = "Show: all (%d lines)" % total
		subset = Log.all_logs
	else:
		slider_label.text = "Show: %d last lines" % lines_to_show
		var start: int = maxi(total - lines_to_show, 0)
		subset = Log.all_logs.slice(start, total)
	
	var filtered: Array[String] = []
	for line: String in subset:
		var level: int = _extract_log_level(line)
		if level == -1:
			filtered.append(line)
		elif filters.has(level) and filters[level]:
			filtered.append(line)
	
	log_text.text = "\n".join(filtered)
	log_text.scroll_vertical = log_text.get_line_count() # Scroll down


func _extract_log_level(line: String) -> int:
	var result: RegExMatch = loglevel_regex.search(line)
	if result:
		var log_level_name: String = result.get_string(1) # "DEBUG", "INFO"…
		if Log.LogLevel.has(log_level_name):
			return Log.LogLevel[log_level_name]
	return -1


func _on_level_changed(_index: int) -> void:
	var selected_level: int = log_level_dropdown.get_selected_id()
	Log.current_level = selected_level as Log.LogLevel
	Log.info("Log level changed to %s" % Log.LogLevel.keys()[selected_level])


func _on_filters_changed(checked: bool, index: int) -> void:
	filters[index] = checked
	Log.trace("DeveloperSettings: Filters changed: %s" % str(filters))
	if loglevel_regex != null:
		_update_log_text()


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(LOGIN_MENU_PATH)


func _on_slider_changed(_value: float) -> void:
	_update_log_text()

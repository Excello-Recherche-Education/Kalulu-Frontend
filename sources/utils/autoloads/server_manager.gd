extends CanvasLayer
class_name ServerManagerClass

signal request_completed(success: bool, code: int, body: Dictionary)
signal internet_check_completed(has_acces: bool)

@onready var internet_check: HTTPRequest = $InternetCheck
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var loading_rect: TextureRect = $TextureRect

const INTERNET_CHECK_URL: String = "https://google.com"
var environment_url: String = ""

func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://environment.cfg") == OK:
		var env: int = int(config.get_value("environment", "current", 0) as int)
		set_environment(env)
	else:
		set_environment(1)  # fallback PROD


func set_environment(env: int) -> void:
	match env:
		0: environment_url = "https://iu695b0nk5.execute-api.eu-west-3.amazonaws.com/dev/"
		1: environment_url = "https://uqkpbayw1k.execute-api.eu-west-3.amazonaws.com/prod/"
		_: environment_url = ""
	Logger.info("Environment URL set to " + environment_url)


func submit_student_level_time(level: int, elapsed_time: int) -> void:
	await _post_json_request("submit_student_metrics", {"student_id": UserDataManager.student, "level": level, "time_spent": elapsed_time})


func first_login_student() -> void:
	await _post_json_request("submit_student_session", {"student_id": UserDataManager.student})


func check_email(email: String) -> Dictionary:
	loading_rect.show()
	await _get_request("checkemail", {"mail" : email})
	return _response()


func register(data: Dictionary) -> Dictionary:
	loading_rect.show()
	await _post_json_request("register", data)
	return _response()


func login(mail: String, password: String) -> Dictionary:
	loading_rect.show()
	await _post_json_request("login", {"mail": mail, "password": password})
	return _response()


func get_configuration() -> Dictionary:
	await _get_request("configuration", {})
	return _response()


func delete_account() -> Dictionary:
	loading_rect.show()
	await _delete_request("delete_account")
	return _response()


func get_language_pack_url(locale: String) -> Dictionary:
	await _get_request("language", {"locale": locale})
	return _response()


func get_user_data_timestamp() -> Dictionary:
	await _get_request("get_user_data_timestamp", {})
	return _response()


func get_user_data() -> Dictionary:
	await _get_request("get_user_data", {})
	return _response()


func update_user_data(teacher: TeacherSettings, timestamp: String, force: bool = false) -> Dictionary:
	var data: Dictionary = {"account_type": teacher.account_type, "education_method": teacher.education_method ,"timestamp": timestamp}
	if force:
		data.merge({"force_sync": "YES"})
	await _post_json_request("update_user_data", data)
	return _response()

func update_student_remediation_data(student_code: int, student_remediation: UserRemediation) -> Dictionary:
	if not student_remediation:
		Logger.trace("ServerManager: Cannot update studient remediation data because data does not exists")
		success = true
		code = -1
		json = {}
		return _response()
	var tuple_list: Array = []
	for key: int in student_remediation.gps_scores.keys():
		tuple_list.append([key, student_remediation.gps_scores[key]])
	var data: Dictionary = {"student_id": student_code, "score_remediation": tuple_list}
	await _post_json_request("submit_gp_remediation", data)
	return _response()

# p_student must have a device key
# it can contain a name, level and age key for parents
# TODO POUR ADD / UPDATE / REMOVE STUDENT : RECUPERER LE TIMESTAMP POUR METTRE A JOUR LE USER
func add_student(p_student: Dictionary) -> Dictionary:
	await _post_request("add_student", p_student)
	return _response()


func update_student(student: StudentData) -> Dictionary:
	await _post_request("update_student", {"code": student.code, "name": student.name, "level": student.level, "age": student.age})
	return _response()


func remove_student(p_code: int) -> Dictionary:
	await _delete_request("remove_student", {"code": p_code})
	return _response()


func get_student_data_timestamp(student_code: int) -> Dictionary:
	await _get_request("get_student_data_timestamp", {"student_id": student_code})
	return _response()


func set_student_data(student_code: int, data: Dictionary) -> Dictionary:
	data.merge({"student_id": student_code})
	await _post_request("set_student_data", data)
	return _response()
	
#region Sender functions

func check_internet_access() -> bool:
	Logger.trace("ServerManager Sending simple request to " + INTERNET_CHECK_URL + " to check if internet is available")
	var res: Error = internet_check.request(INTERNET_CHECK_URL)
	if res == OK:
		return await internet_check_completed
	return false


func _create_URI_with_parameters(URI: String, params: Dictionary) -> String:
	var is_first_param: bool = true
	for key: String in params.keys():
		if is_first_param:
			URI += "?"
			is_first_param = false
		else:
			URI += "&"
		URI += str(key) + "=" + str(params[key])
	return URI


func _create_request_headers(contentTypeJSON: bool = false) -> PackedStringArray:
	var headers: PackedStringArray = []
	var teacher_settings: TeacherSettings = UserDataManager.teacher_settings
	if teacher_settings and teacher_settings.token:
		headers.append("Authorization: Bearer " + teacher_settings.token)
	if contentTypeJSON:
		headers.append("Content-Type: application/json")
	Logger.trace("ServerManager Create Header : " + str(headers))
	return headers


# Response from the last request
var success: bool
var code: int
var json: Dictionary = {}

func _response() -> Dictionary:
	var res: Dictionary = {
			"success" : success,
			"code" : code,
			"body" : json
		}
	return res


func _get_request(URI: String, params: Dictionary) -> void:
	resetResult()
	var headers: PackedStringArray = _create_request_headers()
	if params.has("password"):
		Logger.trace("ServerManager Sending GET request.\n    URI = %s\n    Parameters not logged because it contains a password." % URI)
	else:
		Logger.trace("ServerManager Sending GET request.\n    URI = %s\n    Parameters = %s" % [URI, params])
	if http_request.request(_create_URI_with_parameters(environment_url + URI, params), headers) == OK:
		await request_completed
	else:
		Logger.error("ServerManager Error sending GET request")
		code = 500
		json = {message = "Internal Server Error"}


func _post_request(URI: String, params: Dictionary) -> void:
	resetResult()
	var url: String = _create_URI_with_parameters(environment_url + URI, params)
	var headers: PackedStringArray = _create_request_headers()
	if params.has("password"):
		Logger.trace("ServerManager Sending POST request.\n    URI = %s\n    Parameters not logged because it contains a password." % URI)
	else:
		Logger.trace("ServerManager Sending POST request.\n    URI = %s\n    Parameters = %s" % [URI, params])
	if http_request.request(url, headers, HTTPClient.METHOD_POST, "") == OK:
		await request_completed
	else:
		Logger.error("ServerManager Error sending POST request")
		code = 500
		json = {message = "Internal Server Error"}


func _post_json_request(URI: String, data: Dictionary) -> void:
	resetResult()
	var req: String = environment_url + URI
	var headers: PackedStringArray = _create_request_headers(true)
	if data.has("password"):
		Logger.trace("ServerManager sending POST JSON request.\n    URI = %s\n    Data not logged because it contains a password." % URI)
	else:
		Logger.trace("ServerManager Sending POST JSON request.\n    URI = %s\n    Data = %s" % [URI, data])
	if http_request.request(req, headers, HTTPClient.METHOD_POST, JSON.stringify(data)) == OK:
		await request_completed
	else:
		Logger.error("ServerManager Error sending POST JSON request")
		code = 500
		json = {message = "Internal Server Error"}


func _delete_request(URI: String, params: Dictionary = {}) -> void:
	resetResult()
	var req: String = _create_URI_with_parameters(environment_url + URI, params)
	var headers: PackedStringArray = _create_request_headers()
	Logger.trace("ServerManager Sending DELETE request.\n    URI = %s\n    Parameters = %s" % [URI, params])
	if http_request.request(req, headers, HTTPClient.METHOD_DELETE, "") == OK:
		await request_completed
	else:
		Logger.error("ServerManager Error sending DELETE request")
		code = 500
		json = {message = "Internal Server Error"}

#endregion

func _on_http_request_request_completed(result_code: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result_code != OK:
		Logger.trace("Cannot complete http request. Error code %d = %s" % [result_code, error_string(result_code)])
	else:
		code = response_code
		if body:
			Logger.trace("ServerManager Request Completed.\n    Response code = %d\n    Body received = %s" % [response_code, body.get_string_from_utf8()])
			var strBody: String = body.get_string_from_utf8()
			var result: Variant = JSON.parse_string(strBody)
			if result != null:
				json = result
			else:
				Logger.trace("ServerManager: result null after parsing String to JSON")
	success = result_code == OK and response_code == 200
	request_completed.emit(success, response_code, json)
	loading_rect.hide()


func _on_internet_check_request_completed(result_code: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result_code != OK:
		Logger.trace("Cannot check internet request. Error code %d = %s" % [result_code, error_string(result_code)])
	else:
		Logger.trace("ServerManager Internet check completed.\n    Response code = %s. (200 = OK)" % str(response_code))
	success = result_code == OK and response_code == 200
	internet_check_completed.emit(success)


func resetResult() -> void:
	success = false
	code = 0
	json = {}

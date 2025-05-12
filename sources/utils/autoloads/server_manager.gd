extends CanvasLayer
signal request_completed(code: int, body: Dictionary)
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


# Response from the last request
var code: int
var json: Dictionary = {}


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
	await _get_request("login", {"mail": mail, "password": password})
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


# p_student must have a device key
# it can contain a name, level and age key for parents
func add_student(p_student: Dictionary) -> Dictionary:
	await _post_request("add_student", p_student)
	return _response()


func update_student(p_name: String, level: StudentData.Level, age: int) -> Dictionary:
	await _post_request("update_student", {"name": p_name, "level": level, "age": age})
	return _response()


func remove_student(p_code: int) -> Dictionary:
	await _delete_request("remove_student", {"code": p_code})
	return _response()
	
#region Sender functions

func check_internet_access() -> bool:
	Logger.debug("ServerManager Sending simple request to Google to check if internet is available")
	var res: Error = internet_check.request("https://google.com")
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


func _create_request_headers() -> PackedStringArray:
	var headers: PackedStringArray = []
	var teacher_settings: TeacherSettings = UserDataManager.teacher_settings
	if teacher_settings and teacher_settings.token:
		headers.append("Authorization: Bearer " + teacher_settings.token)
		Logger.trace("ServerManager Create Header : " + str(headers))
	return headers


func _response() -> Dictionary:
	var res: Dictionary = {
			"code" : code,
			"body" : json
		}
	return res


func _get_request(URI: String, params: Dictionary) -> void:
	code = 0
	json = {}
	if params.has("password"):
		Logger.debug("ServerManager Sending GET request. URI = %s.\nParameters contains password." % URI)
	else:
		Logger.debug("ServerManager Sending GET request. URI = %s.\nParameters = %s " % [URI, params])
	if http_request.request(_create_URI_with_parameters(environment_url + URI, params), _create_request_headers()) == 0:
		await request_completed
	else:
		Logger.error("ServerManager Error sending GET request")
		code = 500
		json = {message = "Internal Server Error"}


func _post_request(URI: String, params: Dictionary) -> void:
	code = 0
	json = {}
	var url: String = _create_URI_with_parameters(environment_url + URI, params)
	var headers: PackedStringArray = _create_request_headers()
	if params.has("password"):
		Logger.debug("ServerManager Sending POST request. URI = %s.\nHeaders = %s " % [URI, str(headers)])
	else:
		Logger.debug("ServerManager Sending POST request. URL = %s.\nHeaders = %s " % [url, str(headers)])
	if http_request.request(url, headers, HTTPClient.METHOD_POST, "") == 0:
		await request_completed
	else:
		Logger.error("ServerManager Error sending POST request")
		code = 500
		json = {message = "Internal Server Error"}


func _post_json_request(URI: String, data: Dictionary) -> void:
	code = 0
	json = {}
	var req: String = environment_url + URI
	var headers: PackedStringArray = _create_request_headers()
	headers.append("Content-Type: application/json")
	Logger.debug("ServerManager Sending JSON request. Request = %s" % req)
	if data.has("password"):
		Logger.debug("ServerManager sending JSON request. Data contains a password")
	else:
		Logger.debug("ServerManager Sending JSON request. Data = %s" % data)
	if http_request.request(req, headers, HTTPClient.METHOD_POST, JSON.stringify(data)) == 0:
		await request_completed
	else:
		Logger.error("ServerManager Error sending JSON request")
		code = 500
		json = {message = "Internal Server Error"}


func _delete_request(URI: String, params: Dictionary = {}) -> void:
	code = 0
	json = {}
	var req: String = _create_URI_with_parameters(environment_url + URI, params)
	var headers: PackedStringArray = _create_request_headers()
	Logger.debug("ServerManager Sending DELETE request. URI = %s. Parameters = %s " % [URI, params])
	if http_request.request(req, headers, HTTPClient.METHOD_DELETE, "") == 0:
		await request_completed
	else:
		Logger.error("ServerManager Error sending DELETE request")
		code = 500
		json = {message = "Internal Server Error"}

#endregion

func _on_http_request_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	code = response_code
	if body:
		Logger.debug("ServerManager Request Completed. Response code = %d. Body received = %s " % [response_code, body.get_string_from_utf8()])
		json = JSON.parse_string(body.get_string_from_utf8())
	
	request_completed.emit(response_code, json)
	loading_rect.hide()


func _on_internet_check_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	Logger.debug("ServerManager Internet check completed. Response code = %d. (200 = OK)" % response_code)
	internet_check_completed.emit(response_code == 200)

class_name ServerManagerClass
extends CanvasLayer

signal request_completed(success: bool, code: int, body: Dictionary)
signal internet_check_completed(has_access: bool)

const INTERNET_CHECK_URL: String = "https://google.com"
const AWS_API_GATEWAY_DOMAIN_ADRESS: String = "api.kalulu.org/"
const SUBDOMAIN_DEV: String = "dev."
const PROTOCOL: String = "https://"
const STAGE_DEV: String = "dev/"
const STAGE_PROD: String = "prod/"

# Response from the last request
var success: bool
var code: int
var json: Dictionary = {}
var environment_url: String = ""
var custom_environment_url: String = ""
var environment_setting: int = 1

@onready var internet_check: HTTPRequest = $InternetCheck
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var loading_rect: TextureRect = $TextureRect


func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://environment.cfg") == OK:
		environment_setting = int(config.get_value("environment", "current", 0) as int)
		custom_environment_url = str(config.get_value("environment", "custom_url", ""))
		set_environment(environment_setting, custom_environment_url)
	else:
		set_environment(1) # fallback PROD


func set_environment(env: int, custom_url: String = "") -> void:
	environment_setting = env
	custom_environment_url = _normalize_url(custom_url)
	environment_url = _resolve_environment_url()
	_save_environment_config()
	Log.info("ServerManager: Environment URL set to " + environment_url)


func set_environment_url(new_url: String) -> void:
	custom_environment_url = _normalize_url(new_url)
	environment_url = _resolve_environment_url()
	_save_environment_config()
	Log.info("ServerManager: Custom environment URL updated to " + environment_url)


func _resolve_environment_url() -> String:
	if custom_environment_url.strip_edges() != "":
		return _normalize_url(custom_environment_url)

	match environment_setting:
		0: return AWS_API_GATEWAY_ADRESS + "/dev/"
		1: return AWS_API_GATEWAY_ADRESS + "/prod/"
		_: return ""


func _normalize_url(url: String) -> String:
	var normalized: String = url.strip_edges()
	if normalized == "":
		return ""
	if not normalized.ends_with("/"):
		normalized += "/"
	return normalized


func _save_environment_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("environment", "current", environment_setting)
	config.set_value("environment", "custom_url", custom_environment_url)
	config.save("user://environment.cfg")


func first_login_student() -> void:
	await _post_json_request("submit_student_session", {"student_id": UserDataManager.student})


func check_email(email: String) -> Dictionary:
	loading_rect.show()
	await _get_request("checkemail", {"mail": email})
	return _response()


func register(data: Dictionary) -> Dictionary:
	loading_rect.show()
	await _post_json_request("register", data)
	return _response()


func login(mail: String, password: String) -> Dictionary:
	loading_rect.show()
	await _post_json_request("login", {"mail": mail, "password": password})
	return _response()


func reset_password(mail: String) -> Dictionary:
	await _post_json_request("forgot", {"email": mail})
	return _response()


func delete_account() -> Dictionary:
	loading_rect.show()
	await _delete_request("delete_account")
	return _response()


func get_language_pack_url(locale: String) -> Dictionary:
	await _get_request("language", {"locale": locale})
	return _response()


func pull_timestamps() -> Dictionary:
	await _get_request("pull_timestamps", {})
	return _response()


func send_server_synchronization_instructions(data: Dictionary) -> Dictionary:
	await _post_json_request("pull_sync_status", data)
	return _response()


func get_dashboard() -> Dictionary:
	await _get_request("dashboard_user", {})
	return _response()


func add_student(p_student: Dictionary) -> Dictionary:
	await _post_request("add_student", p_student)
	return _response()


func remove_student(p_code: int) -> Dictionary:
	await _delete_request("remove_student", {"code": p_code})
	return _response()


func set_student_data(student_code: int, data: Dictionary) -> Dictionary:
	data.merge({"student_id": student_code})
	await _post_request("set_student_data", data)
	return _response()


func get_user_language() -> Dictionary:
	await _get_request("get_language", {})
	return _response()


func set_user_language(language: String) -> Dictionary:
	var data: Dictionary = {"language": language}
	await _post_request("set_language", data)
	return _response()

#region Sender functions

func check_internet_access() -> bool:
	Log.trace("ServerManager: Sending simple request to " + INTERNET_CHECK_URL + " to check if internet is available")
	var res: Error = internet_check.request(INTERNET_CHECK_URL)
	if res == OK:
		return await internet_check_completed
	return false


func _create_uri_with_parameters(uri: String, params: Dictionary) -> String:
	if params.is_empty():
		return uri

	var query_parts: Array[String] = []
	for key: String in params.keys():
		var encoded_key: String = str(key).uri_encode()
		var encoded_value: String = str(params[key]).uri_encode()
		query_parts.append("%s=%s" % [encoded_key, encoded_value])

	var full_uri: String = uri + "?" + "&".join(query_parts)
	if not params.has("password"):
		Log.trace("ServerManager: Encoded URI = %s" % full_uri)
	else:
		Log.warn("ServerManager: A password should probably not be sent as URI parameter")
	return full_uri


func _create_request_headers(content_type_json: bool = false) -> PackedStringArray:
	var headers: PackedStringArray = []
	var teacher_settings: TeacherSettings = UserDataManager.teacher_settings
	if teacher_settings and teacher_settings.token:
		headers.append("authorization: Bearer " + teacher_settings.token)
	if content_type_json:
		headers.append("Content-Type: application/json")
	Log.trace("ServerManager: Create Header: " + str(headers))
	return headers


func _response() -> Dictionary:
	var res: Dictionary = {
			"success": success,
			"code": code,
			"body": json
		}
	return res


func _get_request(uri: String, params: Dictionary) -> void:
	reset_result()
	var headers: PackedStringArray = _create_request_headers()
	if params.has("password"):
		Log.trace("ServerManager: Sending GET request.\n    URI = %s\n    Parameters not logged because it contains a password." % uri)
	else:
		Log.trace("ServerManager: Sending GET request.\n    URI = %s\n    Parameters = %s" % [uri, params])
	if http_request.request(_create_uri_with_parameters(environment_url + uri, params), headers) == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending GET request")
		code = 500
		json = {message = "Internal Server Error"}


func _post_request(uri: String, params: Dictionary) -> void:
	reset_result()
	var url: String = _create_uri_with_parameters(environment_url + uri, params)
	Log.debug(url)
	var headers: PackedStringArray = _create_request_headers()
	if params.has("password"):
		Log.trace("ServerManager: Sending POST request.\n    URI = %s\n    Parameters not logged because it contains a password." % uri)
	else:
		Log.trace("ServerManager: Sending POST request.\n    URI = %s\n    Parameters = %s" % [uri, params])
	if http_request.request(url, headers, HTTPClient.METHOD_POST, "") == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending POST request")
		code = 500
		json = {message = "Internal Server Error"}


func _post_json_request(uri: String, data: Dictionary) -> void:
	reset_result()
	var req: String = environment_url + uri
	Log.debug(req)
	var headers: PackedStringArray = _create_request_headers(true)
	if data.has("password"):
		Log.trace("ServerManager: Sending POST JSON request.\n    URI = %s\n    Data not logged because it contains a password." % uri)
	else:
		Log.trace("ServerManager: Sending POST JSON request.\n    URI = %s\n    Data = %s" % [uri, data])
	if http_request.request(req, headers, HTTPClient.METHOD_POST, JSON.stringify(data)) == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending POST JSON request")
		code = 500
		json = {message = "Internal Server Error"}


func _delete_request(uri: String, params: Dictionary = {}) -> void:
	reset_result()
	var req: String = _create_uri_with_parameters(environment_url + uri, params)
	Log.debug(req)
	var headers: PackedStringArray = _create_request_headers()
	Log.trace("ServerManager: Sending DELETE request.\n    URI = %s\n    Parameters = %s" % [uri, params])
	if http_request.request(req, headers, HTTPClient.METHOD_DELETE, "") == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending DELETE request")
		code = 500
		json = {message = "Internal Server Error"}

#endregion

func _on_http_request_request_completed(result_code: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result_code != OK:
		Log.warn("ServerManager: Cannot complete http request. Error code %d = %s" % [result_code, error_string(result_code)])
	else:
		code = response_code
		if code == 200:
			Log.trace("ServerManager: Request Completed. Response code = %d" % response_code)
		else:
			Log.warn("ServerManager: Request Completed. Response code = %d" % response_code)
		if body:
			var str_body: String = body.get_string_from_utf8()
			var result: Variant = JSON.parse_string(str_body)
			
			if result is Dictionary or result is Array:
				var pretty: String = JSON.stringify(result, "\t")
				if code == 200:
					Log.trace("ServerManager: Prettyfied Body received :\n%s" % pretty)
				else:
					Log.warn("ServerManager: Prettyfied Body received :\n%s" % pretty)
			else:
				if code == 200:
					Log.trace("ServerManager: Body received = %s" % str_body)
				else:
					Log.warn("ServerManager: Body received = %s" % str_body)
			if result != null:
				json = result
			else:
				if code == 200:
					Log.trace("ServerManager: Result null after parsing String to JSON")
				else:
					Log.warn("ServerManager: Result null after parsing String to JSON")
		else:
			if code == 200:
				Log.trace("ServerManager: Body received is empty")
			else:
				Log.warn("ServerManager: Body received is empty")
	success = result_code == OK and response_code == 200
	request_completed.emit(success, response_code, json)
	loading_rect.hide()


func _on_internet_check_request_completed(result_code: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result_code != OK:
		Log.warn("ServerManager: Cannot check internet request. Error code %d = %s" % [result_code, error_string(result_code)])
	else:
		Log.trace("ServerManager: Internet check completed.\n    Response code = %s. (200 = OK)" % str(response_code))
	success = result_code == OK and response_code == 200
	internet_check_completed.emit(success)


func reset_result() -> void:
	success = false
	code = 0
	json = {}

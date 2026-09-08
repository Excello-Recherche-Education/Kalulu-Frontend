class_name ServerManagerClass
extends CanvasLayer

signal request_completed(success: bool, code: int, body: Dictionary)
signal internet_check_completed(has_access: bool)

## What stopped a request that never reached the server.
enum ConnectionFailure {
	## The request did get an HTTP response.
	NONE,
	## The device has no route to the internet at all.
	NO_NETWORK,
	## The internet is reachable, but something stops this app.
	KALULU_BLOCKED,
}

const CONFIG_PATH: String = "user://environment.cfg"
const INTERNET_CHECK_URL: String = "https://google.com"
const AWS_API_GATEWAY_DOMAIN_ADRESS: String = "api.kalulu.org/"
const SUBDOMAIN_DEV: String = "dev."
const PROTOCOL: String = "https://"
const STAGE_DEV: String = "dev/"
const STAGE_PROD: String = "prod/"
## Names for the codes HTTPRequest reports in its request_completed signal.
##
## error_string() cannot be used on them: it translates the global Error enum, where the
## same numbers mean something else entirely. A TLS handshake failure is HTTPRequest's 5,
## and error_string(5) calls it "Parameter out of range" -- which sent a support ticket
## chasing a bad login parameter while the real cause was the device never reaching the
## server. The constant names are kept verbatim so a log line can be grepped straight
## against the engine documentation.
const HTTP_RESULT_NAMES: Dictionary[int, String] = {
	HTTPRequest.RESULT_SUCCESS: "RESULT_SUCCESS",
	HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: "RESULT_CHUNKED_BODY_SIZE_MISMATCH",
	HTTPRequest.RESULT_CANT_CONNECT: "RESULT_CANT_CONNECT",
	HTTPRequest.RESULT_CANT_RESOLVE: "RESULT_CANT_RESOLVE",
	HTTPRequest.RESULT_CONNECTION_ERROR: "RESULT_CONNECTION_ERROR",
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "RESULT_TLS_HANDSHAKE_ERROR",
	HTTPRequest.RESULT_NO_RESPONSE: "RESULT_NO_RESPONSE",
	HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "RESULT_BODY_SIZE_LIMIT_EXCEEDED",
	HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: "RESULT_BODY_DECOMPRESS_FAILED",
	HTTPRequest.RESULT_REQUEST_FAILED: "RESULT_REQUEST_FAILED",
	HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: "RESULT_DOWNLOAD_FILE_CANT_OPEN",
	HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: "RESULT_DOWNLOAD_FILE_WRITE_ERROR",
	HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: "RESULT_REDIRECT_LIMIT_REACHED",
	HTTPRequest.RESULT_TIMEOUT: "RESULT_TIMEOUT",
}

# Response from the last request
var success: bool
var code: int
var json: Dictionary = {}
# The raw HTTPRequest result of the last request and of the last internet probe.
# A failure that never got an HTTP response leaves code at 0 and says nothing more,
# so these are what a diagnosis has to work from.
var last_result_code: int = HTTPRequest.RESULT_SUCCESS
var last_internet_result_code: int = HTTPRequest.RESULT_SUCCESS
# Whether a probe is in flight. There is one HTTPRequest for it, shared by every
# caller, and it answers ERR_BUSY while it is working -- which used to be returned
# as a verdict, so a second caller was told the device had no internet purely
# because the first one was still asking.
var internet_check_running: bool = false
var environment_url: String = ""
var custom_environment_url: String = ""
var environment_setting: int = 1

@onready var internet_check: HTTPRequest = $InternetCheck
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var loading_rect: TextureRect = $TextureRect


func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(CONFIG_PATH)
	if load_error == OK:
		environment_setting = int(config.get_value("environment", "current", 0) as int)
		custom_environment_url = str(config.get_value("environment", "custom_url", ""))
		set_environment(environment_setting, custom_environment_url)
		Log.info("ServerManager: Loaded environment config (setting=%d, custom_url=%s)" % [environment_setting, custom_environment_url])
	else:
		Log.warn("ServerManager: Could not load environment config at %s. Error: %s. Falling back to PROD environment." % [ProjectSettings.globalize_path(CONFIG_PATH), error_string(load_error)])
		set_environment(1)


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
		0: return PROTOCOL + SUBDOMAIN_DEV + AWS_API_GATEWAY_DOMAIN_ADRESS + STAGE_DEV
		1: return PROTOCOL + 				 AWS_API_GATEWAY_DOMAIN_ADRESS + STAGE_PROD
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
	var error: Error = config.save(CONFIG_PATH)
	if error != OK:
		Log.error("ServerManager: Failed to save environment config to %s. Error: %s" % [ProjectSettings.globalize_path(CONFIG_PATH), error_string(error)])
	else:
		Log.trace("ServerManager: Environment configuration saved to " + ProjectSettings.globalize_path(CONFIG_PATH))


func first_login_student() -> void:
	await _post_json_request("submit_student_session", {"student_id": UserDataManager.student})


func check_email(email: String) -> Dictionary:
	loading_rect.show()
	await _get_request("checkemail", {"mail": email})
	return _response()


func register(data: Dictionary) -> Dictionary:
	loading_rect.show()
	if data.has("email"):
		Log.info("ServerManager: Registration request initiated for email %s" % str(data.email))
	else:
		Log.error("ServerManager: Registration request cancelled: email not provided")
		reset_result()
		return _response()
	await _post_json_request("register", data)
	return _response()


func login(mail: String, password: String) -> Dictionary:
	loading_rect.show()
	Log.info("ServerManager: Login request initiated for email %s" % mail)
	await _post_json_request("login", {"mail": mail, "password": password})
	return _response()


func reset_password(mail: String) -> Dictionary:
	Log.info("ServerManager: Password reset requested for email %s" % mail)
	await _post_json_request("forgot", {"email": mail})
	return _response()


func delete_account() -> Dictionary:
	loading_rect.show()
	Log.warn("ServerManager: Delete account request initiated")
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
	Log.info("ServerManager: Add student request initiated")
	await _post_request("add_student", p_student)
	return _response()


func remove_student(p_code: int) -> Dictionary:
	Log.info("ServerManager: Remove student request initiated for code %d" % p_code)
	await _delete_request("remove_student", {"code": p_code})
	return _response()


func set_student_data(student_code: int, data: Dictionary) -> Dictionary:
	data.merge({"student_id": student_code})
	Log.info("ServerManager: Set student data request initiated for code %d" % student_code)
	await _post_request("set_student_data", data)
	return _response()


func get_user_language() -> Dictionary:
	await _get_request("get_language", {})
	return _response()


func set_user_language(language: String) -> Dictionary:
	var data: Dictionary = {"language": language}
	await _post_request("set_language", data)
	return _response()


func reset_language(language: String) -> Dictionary:
	loading_rect.show()
	Log.warn("ServerManager: Reset language request initiated for %s" % language)
	var data: Dictionary = {"language": language}
	await _post_request("reset_language", data)
	return _response()

#region Sender functions

## Whether anything at all can be reached, on a host unrelated to Kalulu.
##
## The probe node carries a 15s timeout, where the request node has 30s. It needs one
## at all because 0 means never: a network that drops packets rather than refusing
## them would leave this awaiting forever, and the login screen with its button
## disabled and no message. 15s rather than something snappier because the answer is
## used to tell a teacher whether her internet works, and a slow network answering
## late is not the same as no network -- a 5s limit was measured declaring a probe
## dead that then completed on its own. A probe on an idle app answers in ~400ms, so
## the limit only bites when something is genuinely struggling.
func check_internet_access() -> bool:
	# Two callers asking at once want the same answer, so the second waits for the
	# probe already running rather than being refused and reading that as offline.
	if internet_check_running:
		Log.trace("ServerManager: An internet check is already running, waiting for its answer")
		return await internet_check_completed
	Log.trace("ServerManager: Sending simple request to " + INTERNET_CHECK_URL + " to check if internet is available")
	internet_check_running = true
	var res: Error = internet_check.request(INTERNET_CHECK_URL)
	if res == OK:
		return await internet_check_completed
	internet_check_running = false
	# No probe ran, so the code from the previous one must not be read as this one's.
	last_internet_result_code = HTTPRequest.RESULT_REQUEST_FAILED
	Log.warn("ServerManager: Could not start the internet check. Error: %s" % error_string(res))
	return false


## Tells "you have no internet" apart from "this network blocks Kalulu".
##
## Both end the same way -- no HTTP response, code left at 0 -- but the teacher has to
## do two completely different things about them, and "check your internet access" is
## actively misleading for the second: the internet is fine, and a school firewall or a
## TLS-intercepting proxy is what refuses the API. One was diagnosed from a
## RESULT_TLS_HANDSHAKE_ERROR that vanished the moment the teacher got home.
##
## The failed request's own result code cannot decide it. Filtering by DNS makes a
## blocked host look exactly like an absent network, and a proxy makes an unreachable
## one look like a certificate problem. So the answer comes from a second probe, on a
## host that has nothing to do with Kalulu.
func diagnose_connection_failure() -> ConnectionFailure:
	if last_result_code == HTTPRequest.RESULT_SUCCESS:
		return ConnectionFailure.NONE
	var reached: bool = await check_internet_access()
	var failure: ConnectionFailure = diagnosis_for(reached, last_internet_result_code)
	Log.info("ServerManager: Diagnosed %s (request %s, probe %s)" % [
			ConnectionFailure.keys()[failure],
			http_result_name(last_result_code),
			http_result_name(last_internet_result_code)])
	return failure


## The diagnosis, given what the probe found.
##
## Split out so every answer can be checked without a network, the probe's outcome
## being the only input.
static func diagnosis_for(probe_reached_internet: bool, probe_result_code: int) -> ConnectionFailure:
	if probe_reached_internet:
		# The device is online and only this app is being stopped.
		return ConnectionFailure.KALULU_BLOCKED
	# A probe that got as far as a rejected TLS handshake still proves something
	# answered on the other side. That is a proxy presenting its own certificate for
	# every host it is asked for, Kalulu included -- not an absent network.
	if probe_result_code == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
		return ConnectionFailure.KALULU_BLOCKED
	return ConnectionFailure.NO_NETWORK


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
		headers.append("Authorization: Bearer " + teacher_settings.token)
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
	var req_url: String = _create_uri_with_parameters(environment_url + uri, params)
	var request_error: Error = http_request.request(req_url, headers)
	if request_error == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending GET request to %s. Error: %s" % [req_url, error_string(request_error)])
		code = 500
		json = {message = "Internal Server Error"}


func _post_request(uri: String, params: Dictionary) -> void:
	reset_result()
	var url: String = _create_uri_with_parameters(environment_url + uri, params)
	var headers: PackedStringArray = _create_request_headers()
	if params.has("password"):
		Log.trace("ServerManager: Sending POST request.\n    URI = %s\n    Parameters not logged because it contains a password." % uri)
	else:
		Log.trace("ServerManager: Sending POST request.\n    URI = %s\n    Parameters = %s" % [uri, params])
	var request_error: Error = http_request.request(url, headers, HTTPClient.METHOD_POST, "")
	if request_error == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending POST request to %s. Error: %s" % [url, error_string(request_error)])
		code = 500
		json = {message = "Internal Server Error"}


func _post_json_request(uri: String, data: Dictionary) -> void:
	reset_result()
	var req: String = environment_url + uri
	var headers: PackedStringArray = _create_request_headers(true)
	if data.has("password"):
		Log.trace("ServerManager: Sending POST JSON request.\n    URI = %s\n    Data not logged because it contains a password." % uri)
	else:
		Log.trace("ServerManager: Sending POST JSON request.\n    URI = %s\n    Data = %s" % [uri, data])
	var request_error: Error = http_request.request(req, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if request_error == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending POST JSON request to %s. Error: %s" % [req, error_string(request_error)])
		code = 500
		json = {message = "Internal Server Error"}


func _delete_request(uri: String, params: Dictionary = {}) -> void:
	reset_result()
	var req: String = _create_uri_with_parameters(environment_url + uri, params)
	var headers: PackedStringArray = _create_request_headers()
	Log.trace("ServerManager: Sending DELETE request.\n    URI = %s\n    Parameters = %s" % [uri, params])
	var request_error: Error = http_request.request(req, headers, HTTPClient.METHOD_DELETE, "")
	if request_error == OK:
		await request_completed
	else:
		Log.error("ServerManager: Error sending DELETE request to %s. Error: %s" % [req, error_string(request_error)])
		code = 500
		json = {message = "Internal Server Error"}

#endregion

func _on_http_request_request_completed(result_code: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	last_result_code = result_code
	if result_code != HTTPRequest.RESULT_SUCCESS:
		Log.warn("ServerManager: Cannot complete http request. Result code %d = %s. No HTTP response, so the response code stays 0." % [result_code, http_result_name(result_code)])
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
	success = result_code == HTTPRequest.RESULT_SUCCESS and response_code == 200
	request_completed.emit(success, response_code, json)
	loading_rect.hide()


func _on_internet_check_request_completed(result_code: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	internet_check_running = false
	last_internet_result_code = result_code
	if result_code != HTTPRequest.RESULT_SUCCESS:
		Log.warn("ServerManager: Cannot check internet request. Result code %d = %s" % [result_code, http_result_name(result_code)])
	else:
		Log.trace("ServerManager: Internet check completed.\n    Response code = %s. (200 = OK)" % str(response_code))
	success = result_code == HTTPRequest.RESULT_SUCCESS and response_code == 200
	internet_check_completed.emit(success)


static func http_result_name(result_code: int) -> String:
	return HTTP_RESULT_NAMES.get(result_code, "unknown result code")


func reset_result() -> void:
	success = false
	code = 0
	json = {}

extends CanvasLayer
signal request_completed(code: int, body: Dictionary)

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var loading_rect: TextureRect = $TextureRect

# TODO Put in a file
const URL: String = "https://uqkpbayw1k.execute-api.eu-west-3.amazonaws.com/dev/"

# Response from the last request
var code: int
var json: Dictionary

func check_email(email: String) -> Dictionary:
	await _get_request("checkemail", {"mail" : email})
	return _response()

func register(data: Dictionary) -> Dictionary:
	await _post_json_request("register", data)
	return _response()

func login(type: TeacherSettings.AccountType, device:int, mail: String, password: String) -> Dictionary:
	await _get_request("login", {"type":type, "device":device, "mail": mail, "password": password})
	return _response()


#region Sender functions

func _response() -> Dictionary:
	return {
			"code" : code,
			"body" : json
		}


func _get_request(URI: String, params: Dictionary) -> void:
	loading_rect.visible = true
	code = 0
	json = {}
	
	var req: = URL + URI
	var is_first_param: bool = true
	for key in params.keys():
		if is_first_param:
			req += "?"
			is_first_param = false
		else:
			req += "&"
		req += str(key) + "=" + str(params[key])
	
	if http_request.request(req) == 0:
		await request_completed


func _post_json_request(URI: String, data: Dictionary) -> void:
	loading_rect.visible = true
	code = 0
	json = {}
	
	var req: = URL + URI
	var headers: = ["Content-Type: application/json"]
	
	var json = JSON.stringify(data)
	print(json)
	if http_request.request(req, headers, HTTPClient.METHOD_POST, json) == 0:
		await request_completed

#endregion

func _on_http_request_request_completed(result, response_code, headers, body):
	code = response_code
	print("Response received : " + str(code))
	print(headers)
	if body:
		json = JSON.parse_string(body.get_string_from_utf8())
		print(json)
	request_completed.emit(response_code, json)
	loading_rect.visible = false

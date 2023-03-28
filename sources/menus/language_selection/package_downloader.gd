extends Control

signal completed()

const download_url: = "http://localhost:8000/"

@onready var http_request: = $HTTPRequest
@onready var progress_bar: = $ProgressBar
var request_type: = -1
var package_name: String


func download_package(p_package_name: String) -> void:
	package_name = p_package_name
	# Perform a HEAD request to check that the file is here and to know its size
	http_request.download_file = "user://" + package_name + ".tmp"
	request_type = HTTPClient.METHOD_HEAD
	var error = http_request.request(download_url + package_name, PackedStringArray(), request_type)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _on_HTTPRequest_request_completed(_result: int, _response_code: int, headers: PackedStringArray, _body: PackedByteArray) -> void:
	# Response to HEAD request
	if request_type == HTTPClient.METHOD_HEAD:
		for header in headers:
			if header.begins_with("Content-Length"):
				progress_bar.max_value = int(header.right("Content-Length".length() + 1))
				break
		# Do the GET request to download the file
		request_type = HTTPClient.METHOD_GET
		var error = http_request.request(download_url + package_name, PackedStringArray(), request_type)
		if error != OK:
			push_error("An error occurred in the HTTP request.")
	
	# Response to the GET request
	else:
		DirAccess.rename_absolute(http_request.download_file, "user://" + package_name)
		emit_signal("completed")


func _process(_delta: float) -> void:
	if request_type == HTTPClient.METHOD_GET:
		progress_bar.value = http_request.get_downloaded_bytes()

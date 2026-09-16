class_name ServerManagerClass
extends CanvasLayer

signal request_completed(success: bool, code: int, body: Dictionary)
signal internet_check_completed(has_access: bool)

## What stopped a request that never reached the server.
##
## The order matters to nothing, but the membership does: each value is a cause a
## reader has a *different* thing to do about, and none is here because it was
## technically distinguishable. KALULU_BLOCKED stays the general case -- anything
## refusing Kalulu that the evidence does not pin down more precisely lands there,
## and its notice is the one that names the domains to unblock.
enum ConnectionFailure {
	## The request did get an HTTP response.
	NONE,
	## The device has no route to the internet at all.
	NO_NETWORK,
	## The internet is reachable, but something stops this app.
	KALULU_BLOCKED,
	## The API's hostname is refused or redirected before anything is dialled.
	## Parental control, a school resolver, a filtering box on the line.
	DNS_FILTERED,
	## Something answers for our host with a certificate we cannot verify: an
	## antivirus decrypting HTTPS, or a filtering proxy. Usually on the device
	## itself, which is why it follows the teacher from one network to the next.
	TLS_INTERCEPTED,
	## The device clock is far enough out that no certificate can be valid against
	## it. The only cause on this list the reader can fix alone, in a minute.
	CLOCK_SKEW,
	## A proxy is in the way and wants credentials before it will carry anything.
	PROXY_REQUIRED,
	## The machine has a proxy of its own, Kalulu was not using it, and going through
	## it works. Already switched on by the time this is returned: there is nothing
	## for the reader to decide, only something to be told.
	PROXY_AVAILABLE,
}

## How far the device clock has to be out before it is named as the cause.
##
## Below a day it cannot be: certificates are issued for months, so an hour or a
## day of drift invalidates nothing and blaming it would send the reader to the
## clock settings for no reason. Well above it, the handshake fails for this and
## nothing else -- a tablet that has been in a cupboard since June comes back
## believing it is still June.
const CLOCK_SKEW_THRESHOLD_SECONDS: int = 86400
const CONFIG_PATH: String = "user://environment.cfg"
const INTERNET_CHECK_URL: String = "https://google.com"
## The status a proxy answers with when it is there and wants to be authenticated to.
const PROXY_AUTH_REQUIRED_CODE: int = 407
## The route the diagnostic probes ask for: no parameters, no token, a fixed answer.
const HEALTH_ROUTE: String = "health"
## What /health answers with, and therefore how our own reply is told from a block page.
const HEALTH_ANSWER_MARKER: String = "\"status\""
## Long enough for a slow school line, short enough not to sit on a dead one. The
## screen is showing "diagnosing" for the whole of it, so it is a visible cost.
const UNSAFE_PROBE_TIMEOUT_SECONDS: float = 15.0
## Passed instead of a result code by a caller whose failure *was* the last request.
##
## Not every caller's did. The language pack downloader gives up before it ever calls
## the API -- its own internet probe failed first -- so [member last_result_code] there
## belongs to whatever ran last, which may well have succeeded. Read as this failure's,
## it would report a healthy connection over a screen that cannot reach anything.
const USE_LAST_RESULT: int = -1
## Month names as an HTTP Date header spells them -- the format is fixed by RFC 7231
## and is always English, whatever the device's locale.
const MONTHS: PackedStringArray = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]
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
## The last cause [method diagnose_connection_failure] settled on, for a screen that
## has to decide what to offer -- the proxy field is only worth showing for some of
## them -- after the notice it came with has been dismissed.
var last_diagnosis: ConnectionFailure = ConnectionFailure.NONE
## The proxy every request goes through, when there is one. Empty host means direct,
## which is what this app did unconditionally before and still does by default.
var proxy_host: String = ""
var proxy_port: int = 0
## Whether to use the pair above. Kept apart from the host so switching the proxy off
## does not throw away an address that was hard to obtain in the first place.
var proxy_enabled: bool = false
## What the operating system says the rest of the machine uses, looked up once.
## Empty on mobile and web, and on the large majority of desktops.
var system_proxy: Dictionary = {}
## Whether that lookup has happened. Kept apart from the result, which is empty both
## before it runs and when it finds nothing.
var system_proxy_lookup_done: bool = false

@onready var internet_check: HTTPRequest = $InternetCheck
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var loading_rect: TextureRect = $TextureRect


func _ready() -> void:
	load_configuration()


## Reads the whole of user://environment.cfg into this node.
##
## Split out of _ready so the order below can be checked: the environment and the
## proxy come out of one file, one of them is saved back during the read, and getting
## that sequence wrong loses the other silently -- a launch that looks perfectly
## normal, and a next one that cannot connect.
func load_configuration() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(CONFIG_PATH)

	# Read first, and before set_environment below, which saves the whole file: it
	# would write these three back at their defaults and a proxy found to work on a
	# previous run would be gone from disk. This launch would not notice -- the values
	# are read out of the ConfigFile already in memory just after -- and the next one
	# would come up unable to connect, on the machines that need a proxy most.
	proxy_host = str(config.get_value("network", "proxy_host", ""))
	proxy_port = int(config.get_value("network", "proxy_port", 0) as int)
	proxy_enabled = bool(config.get_value("network", "proxy_enabled", false))

	if load_error == OK:
		environment_setting = int(config.get_value("environment", "current", 0) as int)
		custom_environment_url = str(config.get_value("environment", "custom_url", ""))
		set_environment(environment_setting, custom_environment_url)
		Log.info("ServerManager: Loaded environment config (setting=%d, custom_url=%s)" % [environment_setting, custom_environment_url])
	else:
		Log.warn("ServerManager: Could not load environment config at %s. Error: %s. Falling back to PROD environment." % [ProjectSettings.globalize_path(CONFIG_PATH), error_string(load_error)])
		set_environment(1)

	# In place before anything is sent, rather than after the first failure.
	_apply_proxy()


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
	config.set_value("network", "proxy_host", proxy_host)
	config.set_value("network", "proxy_port", proxy_port)
	config.set_value("network", "proxy_enabled", proxy_enabled)
	var error: Error = config.save(CONFIG_PATH)
	if error != OK:
		Log.error("ServerManager: Failed to save environment config to %s. Error: %s" % [ProjectSettings.globalize_path(CONFIG_PATH), error_string(error)])
	else:
		Log.trace("ServerManager: Environment configuration saved to " + ProjectSettings.globalize_path(CONFIG_PATH))


#region Proxy

## Sends every request through a proxy, or stops doing so, and remembers the choice.
##
## Applied to the probes as well as to the API: a diagnosis run over a different route
## from the one that failed describes a network nobody is on.
func set_proxy(host: String, port: int, enabled: bool) -> void:
	proxy_host = host.strip_edges()
	proxy_port = port
	proxy_enabled = enabled and not proxy_host.is_empty() and proxy_port > 0
	_apply_proxy()
	_save_environment_config()
	Log.info("ServerManager: Proxy %s" % [
			"set to %s:%d" % [proxy_host, proxy_port] if proxy_enabled else "switched off"])


## Whether showing the proxy field to the reader would be anything but noise.
##
## It stays hidden by default and that is the point: almost nobody is behind a proxy,
## and a box asking for a "server address" on a screen that has just failed is an
## invitation to type something into it. So it appears only where it could be the
## answer -- when the machine itself is configured for one, when one is already in
## use and might need turning off, or when the failure is of the shape a proxy
## explains. A clock two years out and an unplugged cable are not that shape.
##
## Static and given everything it needs, so the rule can be checked on its own.
static func proxy_is_worth_offering(cause: ConnectionFailure, has_system_proxy: bool,
		already_enabled: bool) -> bool:
	if has_system_proxy or already_enabled:
		return true
	return cause in [
		ConnectionFailure.PROXY_REQUIRED,
		ConnectionFailure.PROXY_AVAILABLE,
		ConnectionFailure.KALULU_BLOCKED,
		ConnectionFailure.TLS_INTERCEPTED,
	]


## Tries the machine's own proxy once, with certificate verification left on.
##
## Verification stays on deliberately, unlike the diagnostic retry: this one decides
## whether to route real traffic through the proxy from now on, so it has to prove the
## route is sound and not merely that something answers on it.
func system_proxy_reaches_server() -> bool:
	if system_proxy.is_empty() or OS.has_feature("web"):
		return false

	var probe: HTTPRequest = HTTPRequest.new()
	probe.timeout = UNSAFE_PROBE_TIMEOUT_SECONDS
	probe.set_http_proxy(str(system_proxy["host"]), int(system_proxy["port"]))
	probe.set_https_proxy(str(system_proxy["host"]), int(system_proxy["port"]))
	add_child(probe)
	Log.trace("ServerManager: Trying the machine's own proxy %s:%d" % [
			system_proxy["host"], system_proxy["port"]])
	var started: Error = probe.request(environment_url + HEALTH_ROUTE)
	if started != OK:
		Log.warn("ServerManager: Could not start the proxy probe. Error: %s" % error_string(started))
		probe.queue_free()
		return false

	var result: Array = await probe.request_completed
	probe.queue_free()
	var reached: bool = proxy_probe_succeeded(result[0] as int, result[1] as int,
			(result[3] as PackedByteArray).get_string_from_utf8())
	Log.info("ServerManager: The machine's proxy %s" % [
			"reaches the server" if reached else "does not reach the server either"])
	return reached


## Whether that probe proves the proxy carries Kalulu's traffic, rather than answering
## for it.
##
## A 200 is not enough, and this is the one place where accepting one does lasting
## damage: a filtering proxy serving its own page, or a captive portal, answers 200
## with HTML for any address it is given. Taken as proof, the proxy is switched on and
## written to disk, and from then on every API call comes back as that page -- an
## empty body under a successful code, which the login reads as a server error and
## registration as missing fields. Neither is a network message, so the panel that
## could switch the proxy back off is hidden on exactly the screens where it is
## needed. The answer has to be ours.
static func proxy_probe_succeeded(result_code: int, response_code: int, body: String) -> bool:
	return result_code == HTTPRequest.RESULT_SUCCESS and response_code == 200 \
			and body.contains(HEALTH_ANSWER_MARKER)


## Looks the machine's own proxy up, once, the first time it could matter.
##
## Deferred rather than done at startup, where it would cost a subprocess on every
## launch of every desktop build to answer a question that only arises once a request
## has already failed -- which for almost every teacher is never.
func ensure_system_proxy_known() -> void:
	if system_proxy_lookup_done:
		return
	system_proxy_lookup_done = true
	system_proxy = SystemProxy.detect()
	# Prefilled even while unused, so the field a teacher is eventually shown already
	# holds the right answer and there is nothing for her to type. Never overwrites a
	# proxy she set herself.
	if proxy_host.is_empty() and not system_proxy.is_empty():
		proxy_host = str(system_proxy["host"])
		proxy_port = int(system_proxy["port"])


func _apply_proxy() -> void:
	apply_proxy_to(http_request)
	apply_proxy_to(internet_check)


## Points somebody else's [HTTPRequest] at the same proxy, or back at a direct route.
##
## Public because this app does not make all of its requests here. The language pack
## is an archive of tens of megabytes fetched straight from S3, so the downloader owns
## the node that fetches it -- and on a network whose only way out is a proxy, leaving
## that one direct means the API answers, the pack does not, and a fresh install with
## no pack on disk has nowhere to go. Call it before the request, not once at startup:
## the proxy is usually set in the middle of a failure, after the node was made.
func apply_proxy_to(request: HTTPRequest) -> void:
	if not request:
		return
	# An empty host is how HTTPRequest is told to go direct, so switching the proxy
	# off does not need the node rebuilt.
	var host: String = proxy_host if proxy_enabled else ""
	var port: int = proxy_port if proxy_enabled else 0
	request.set_http_proxy(host, port)
	request.set_https_proxy(host, port)

#endregion

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
func diagnose_connection_failure(http_code: int = 0,
		request_result: int = USE_LAST_RESULT) -> ConnectionFailure:
	var result: int = last_result_code if request_result == USE_LAST_RESULT else request_result
	if result == HTTPRequest.RESULT_SUCCESS and http_code != PROXY_AUTH_REQUIRED_CODE:
		return ConnectionFailure.NONE

	var evidence: ConnectionEvidence = await gather_evidence(http_code, request_result)
	var failure: ConnectionFailure = diagnose(evidence)
	last_diagnosis = failure
	Log.info(("ServerManager: Diagnosed %s (request %s, probe %s, host %s, "
			+ "unverified retry %s, clock offset %s)") % [
			ConnectionFailure.keys()[failure],
			http_result_name(evidence.request_result),
			http_result_name(evidence.probe_result),
			evidence.host_address if evidence.host_resolved else "did not resolve",
			("reached, %s" % ["our answer" if evidence.unsafe_body_is_ours else "somebody else's"]) \
					if evidence.unsafe_reached else "no answer",
			("%ds" % evidence.clock_offset_seconds) if evidence.clock_offset_known else "unknown"])
	return failure


## Runs every probe the platform allows and writes down what each one answered.
##
## Deliberately concludes nothing -- see [ConnectionEvidence]. Probes run in the order
## that lets the cheap ones spare the expensive ones: a name that does not resolve
## makes the unverified retry pointless, and the retry answering makes the third-party
## probe pointless, since something is demonstrably reachable.
func gather_evidence(http_code: int = 0,
		request_result: int = USE_LAST_RESULT) -> ConnectionEvidence:
	var evidence: ConnectionEvidence = ConnectionEvidence.new()
	evidence.request_result = last_result_code if request_result == USE_LAST_RESULT \
			else request_result
	evidence.proxy_auth_required = http_code == PROXY_AUTH_REQUIRED_CODE
	if evidence.proxy_auth_required:
		# It has named itself. Every further probe would go through the same proxy and
		# come back with the same 407, so there is nothing left to learn.
		return evidence

	# Asked first, and skipped outright on the large majority of machines: no system
	# proxy means nothing to try. When there is one, it is both the likeliest
	# explanation and the only one that fixes itself.
	ensure_system_proxy_known()
	if not system_proxy.is_empty() and not proxy_enabled:
		evidence.system_proxy_works = await system_proxy_reaches_server()
		if evidence.system_proxy_works:
			set_proxy(str(system_proxy["host"]), int(system_proxy["port"]), true)
			return evidence

	var host: String = api_host()
	var address: String = await resolve_host(host)
	evidence.host_resolved = not address.is_empty()
	evidence.host_address = address
	if ConnectionEvidence.address_is_local(address):
		# What answers is not on the internet. Probing further only measures the filter.
		return evidence

	# Only asked when the failure was about a certificate, which is the only thing
	# this retry can explain -- and it is a request with verification switched off, so
	# it is not made for curiosity's sake. It also costs up to its full timeout on the
	# networks this runs on.
	if evidence.host_resolved \
			and evidence.request_result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
		var retry: Dictionary = await probe_without_certificate_check()
		evidence.unsafe_reached = retry["reached"] as bool
		evidence.unsafe_body_is_ours = retry["body_is_ours"] as bool
		if retry["date_header"] != "":
			evidence.clock_offset_seconds = clock_offset_from(str(retry["date_header"]))
			evidence.clock_offset_known = true
		if evidence.unsafe_reached:
			return evidence

	# Either the name did not resolve, or nothing answered on it. Both leave the same
	# question, and it is the one that separates a filter from an absent network:
	# does anything on this device reach the internet at all.
	evidence.probe_reached_internet = await check_internet_access()
	evidence.probe_result = last_internet_result_code
	return evidence


## The API's hostname, without scheme, port, path or trailing dot.
func api_host() -> String:
	return host_of(environment_url)


## Split out from [method api_host] so it can be checked against the shapes a custom
## environment URL arrives in, none of which involve a network.
static func host_of(url: String) -> String:
	var rest: String = url
	var scheme_end: int = rest.find("://")
	if scheme_end != -1:
		rest = rest.substr(scheme_end + 3)
	rest = rest.split("/")[0]
	# Strip credentials and port: user:pass@host:443 is a legal authority.
	if rest.contains("@"):
		rest = rest.split("@")[-1]
	if rest.contains(":") and not rest.contains("]"):
		rest = rest.split(":")[0]
	return rest.trim_suffix(".")


## Asks DNS on its own, and nothing else.
##
## Returns the address, or "" when the name is refused. The point of asking here
## rather than reading it off a failed request is that [HTTPRequest] folds resolution,
## connection and handshake into one result code: a filtered name and an unplugged
## cable both come back as "it did not work". This separates the first of the three.
##
## Queued rather than resolved outright: [method IP.resolve_hostname] blocks, and on
## exactly the networks this exists for -- the ones that drop packets in silence --
## it blocks for the full resolver timeout with the screen frozen behind it.
func resolve_host(host: String) -> String:
	if host.is_empty():
		return ""
	var item: int = IP.resolve_hostname_queue_item(host, IP.TYPE_ANY)
	if item == -1:
		Log.warn("ServerManager: Could not queue a resolution for %s" % host)
		return ""
	while IP.get_resolve_item_status(item) == IP.RESOLVER_STATUS_WAITING:
		await get_tree().process_frame
	var address: String = ""
	if IP.get_resolve_item_status(item) == IP.RESOLVER_STATUS_DONE:
		address = IP.get_resolve_item_address(item)
	IP.erase_resolve_item(item)
	Log.trace("ServerManager: %s resolves to '%s'" % [host, address])
	return address


## Asks the server again with certificate verification switched off.
##
## This is the observation the interception cases rest on: if a request that verifies
## nothing gets through where the real one could not, then something *is* there and
## the only thing wrong was its certificate. That is an antivirus decrypting HTTPS, a
## filtering proxy, or a device clock so far out that no certificate can be valid.
##
## [b]This must never carry anything and never be reused for the API.[/b] It has its
## own node, built here and freed here, and it only ever asks for /health -- a route
## that takes no parameters, needs no token and answers a fixed string. Verification
## is off, so whatever answers could be anybody: the reply is evidence about the
## network and is not data. Reading the body is how a proxy's block page is told from
## our own answer, and nothing else is done with it.
func probe_without_certificate_check() -> Dictionary:
	var answer: Dictionary = {"reached": false, "body_is_ours": false, "date_header": ""}
	if OS.has_feature("web"):
		# The browser owns the connection and neither TLS options nor a proxy mean
		# anything here. Left unobserved rather than guessed at.
		return answer

	var probe: HTTPRequest = HTTPRequest.new()
	probe.timeout = UNSAFE_PROBE_TIMEOUT_SECONDS
	probe.set_tls_options(TLSOptions.client_unsafe())
	apply_proxy_to(probe)
	add_child(probe)
	var url: String = environment_url + HEALTH_ROUTE
	Log.trace("ServerManager: Retrying %s without certificate verification, for diagnosis only" % url)
	var started: Error = probe.request(url)
	if started != OK:
		Log.warn("ServerManager: Could not start the unverified retry. Error: %s" % error_string(started))
		probe.queue_free()
		return answer

	var result: Array = await probe.request_completed
	probe.queue_free()
	var result_code: int = result[0] as int
	var headers: PackedStringArray = result[2] as PackedStringArray
	var body: PackedByteArray = result[3] as PackedByteArray
	answer["reached"] = result_code == HTTPRequest.RESULT_SUCCESS
	if not answer["reached"]:
		Log.trace("ServerManager: The unverified retry failed too (%s)" % http_result_name(result_code))
		return answer

	answer["body_is_ours"] = body.get_string_from_utf8().contains(HEALTH_ANSWER_MARKER)
	for header: String in headers:
		if header.to_lower().begins_with("date:"):
			answer["date_header"] = header.substr(header.find(":") + 1).strip_edges()
			break
	return answer


## How far the device clock is from the server's, in seconds, positive when ahead.
##
## Parsed from an HTTP Date header, which is RFC 7231's fixed form:
## "Tue, 15 Sep 2026 06:59:20 GMT". Static, so the arithmetic can be checked against
## a written-down header rather than whatever today happens to be.
static func clock_offset_from(date_header: String, now_unix: int = -1) -> int:
	var parts: PackedStringArray = date_header.replace(",", "").split(" ", false)
	if parts.size() < 5:
		return 0
	var day: int = int(parts[1])
	var month: int = MONTHS.find(parts[2]) + 1
	var year: int = int(parts[3])
	var clock: PackedStringArray = parts[4].split(":")
	if month == 0 or year == 0 or clock.size() < 3:
		return 0
	var server_unix: int = int(Time.get_unix_time_from_datetime_dict({
			"year": year, "month": month, "day": day,
			"hour": int(clock[0]), "minute": int(clock[1]), "second": int(clock[2])}))
	var device_unix: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	return device_unix - server_unix


## Whether a reply is one the screens should diagnose rather than describe.
##
## 0 is the familiar one: no HTTP response at all, so the code was never set. 407 is
## the one that looks like an answer and is not -- it comes from a proxy standing in
## the way, not from Kalulu's server, and read as an ordinary status code it falls
## through to "wrong email or password", which is a lie about a password the server
## never saw.
static func needs_diagnosis(http_code: int) -> bool:
	return http_code == 0 or http_code == PROXY_AUTH_REQUIRED_CODE


## The diagnosis, given everything that was observed.
##
## Pure, and the only place a cause is decided, so every answer can be checked
## against made-up evidence with no network anywhere near it. The probes that fill
## a [ConnectionEvidence] in are the half that needs one, and they conclude nothing.
##
## The order of the tests is the argument. Several causes produce byte-identical
## symptoms -- a wrong clock and an intercepting antivirus both fail the handshake
## and both let an unverified retry through -- so the one with the narrower proof
## has to be asked first or it is never reached. Nothing is returned that the
## evidence does not carry: an observation that was never made leaves its field at
## the innocent default and the conclusion it would support is simply not available.
static func diagnose(evidence: ConnectionEvidence) -> ConnectionFailure:
	# Asked before "did the request succeed", because a 407 *is* a successful HTTP
	# exchange -- with the proxy, which is the whole problem. Weighed second, it would
	# be reported as a healthy connection carrying an unrecognised status code.
	if evidence.proxy_auth_required:
		return ConnectionFailure.PROXY_REQUIRED

	if evidence.request_result == HTTPRequest.RESULT_SUCCESS:
		return ConnectionFailure.NONE

	# Whatever stopped the direct attempt, a route that demonstrably works outranks
	# naming it: the reader has nothing to do and nothing to be told to check.
	if evidence.system_proxy_works:
		return ConnectionFailure.PROXY_AVAILABLE

	# An address that belongs to this LAN is positive evidence all on its own: an
	# absent network answers nothing, it does not answer 127.0.0.1. So this one needs
	# no corroboration, and is asked before anything about connections -- a filter
	# answering for our host would otherwise read as our server behaving strangely.
	if ConnectionEvidence.address_is_local(evidence.host_address):
		return ConnectionFailure.DNS_FILTERED

	# Both of these say the certificate was the problem, so the failed request has to
	# have said so too. An unverified retry getting through proves only that the host
	# is reachable *now*: after a timeout or a dropped connection it succeeds
	# routinely, and read on its own it turns every transient failure -- and every
	# pack download that stalled on a different host -- into "an antivirus is
	# intercepting your connection", which is a specific accusation about software on
	# the teacher's machine and is simply untrue.
	if evidence.unsafe_reached \
			and evidence.request_result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
		# Something is there, and the only reason the real request failed is that its
		# certificate could not be trusted. Two things do that, and they are told
		# apart by the clock, which is why the offset is measured at all.
		if evidence.clock_offset_known \
				and absi(evidence.clock_offset_seconds) > CLOCK_SKEW_THRESHOLD_SECONDS:
			return ConnectionFailure.CLOCK_SKEW
		return ConnectionFailure.TLS_INTERCEPTED

	if evidence.probe_reached_internet:
		# A name that does not resolve is only filtering if something else on this
		# device does reach the internet. With no network at all nothing resolves
		# either, and calling that a DNS filter sends somebody in airplane mode to
		# argue with an administrator about a domain nobody blocked.
		if not evidence.host_resolved:
			return ConnectionFailure.DNS_FILTERED
		# The device is online and only this app is being stopped.
		return ConnectionFailure.KALULU_BLOCKED
	# A probe that got as far as a rejected TLS handshake still proves something
	# answered on the other side. That is a proxy presenting its own certificate for
	# every host it is asked for, Kalulu included -- not an absent network.
	if evidence.probe_result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
		return ConnectionFailure.KALULU_BLOCKED
	return ConnectionFailure.NO_NETWORK


## The diagnosis from the probe alone, for a caller that has nothing else.
##
## The package downloader is one: it fails on a file transfer rather than on an API
## call, so there is no API host to resolve and no unverified retry to make. It gets
## the two answers its evidence supports, which are the two this app could give at
## all before the rest of the probes existed.
static func diagnosis_for(probe_reached_internet: bool, probe_result_code: int) -> ConnectionFailure:
	var evidence: ConnectionEvidence = ConnectionEvidence.new()
	# Any failure will do: this overload is only ever called on one.
	evidence.request_result = HTTPRequest.RESULT_CANT_CONNECT
	evidence.probe_reached_internet = probe_reached_internet
	evidence.probe_result = probe_result_code
	return diagnose(evidence)


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

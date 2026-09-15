extends GutTest
## What the downloader makes of a server it cannot reach.
##
## Two failures land here and mean opposite things to the reader: the device is
## offline, or the device is online and this network is filtering Kalulu. Telling a
## working network it has no internet sends the adult to the router, where there is
## nothing to find -- it cost a support ticket once.
##
## Both decisions are extracted, so none of this needs a server, a scene or a
## network: PackageDownloader._ready starts a real download, which is not something
## a test should set off.

var downloader: PackageDownloader


func before_each() -> void:
	downloader = PackageDownloader.new()


func after_each() -> void:
	downloader.free()


# --- The answer for the language pack URL -------------------------------------
func test_a_usable_answer_is_used() -> void:
	assert_eq(PackageDownloader.outcome_for_pack_url(200), PackageDownloader.PackUrlOutcome.USE)


func test_a_rejected_token_signs_the_device_out() -> void:
	# The one case where signing out is the honest answer: the server said so.
	assert_eq(PackageDownloader.outcome_for_pack_url(401), PackageDownloader.PackUrlOutcome.SIGN_OUT)


func test_no_answer_at_all_never_signs_the_device_out() -> void:
	# The regression this test exists for. Code 0 means no HTTP response, so nothing
	# was said about the account -- and logout() clears the token from disk, which
	# would leave a device on a network that blocks the API unable to sign in again
	# from that network, with the pack it already had out of reach too.
	assert_eq(PackageDownloader.outcome_for_pack_url(0), PackageDownloader.PackUrlOutcome.OFFLINE,
		"a network failure must not be treated as a rejected account")


func test_an_unusable_answer_is_a_download_failure() -> void:
	for code: int in [400, 403, 404, 500, 502, 503]:
		assert_eq(PackageDownloader.outcome_for_pack_url(code), PackageDownloader.PackUrlOutcome.FAILED,
			"%d came from the server, so it is the server's problem" % code)


func test_a_server_error_never_signs_the_device_out() -> void:
	# The backend keeps its side of this: core/auth.py deliberately lets a database
	# outage surface as a 500 rather than a 401, so that an outage is never mistaken
	# for a bad token. This end used to undo that by signing the device out anyway --
	# and logout() clears the token from disk, so a bad afternoon on the server logged
	# every device out for good.
	for code: int in [500, 502, 503, 504]:
		assert_ne(PackageDownloader.outcome_for_pack_url(code), PackageDownloader.PackUrlOutcome.SIGN_OUT,
			"%d is the server's problem, not the account's" % code)


func test_only_a_rejected_token_signs_the_device_out() -> void:
	# The single guard behind the whole thing: _start signs out on this one answer and
	# no other, so nothing else may ever produce it.
	var codes: Array[int] = [0, 200, 201, 204, 301, 400, 402, 403, 404, 409, 418, 429, 500, 502, 503, 504]
	for code: int in codes:
		assert_ne(PackageDownloader.outcome_for_pack_url(code), PackageDownloader.PackUrlOutcome.SIGN_OUT,
			"%d must not clear the token from disk" % code)
	assert_eq(PackageDownloader.outcome_for_pack_url(401), PackageDownloader.PackUrlOutcome.SIGN_OUT,
		"401 is the one answer that is about the account")


# --- How the pack download ended ----------------------------------------------
func test_a_whole_archive_goes_to_the_extraction_thread() -> void:
	assert_eq(PackageDownloader.outcome_for_pack_download(HTTPRequest.RESULT_SUCCESS, 200),
		PackageDownloader.DownloadOutcome.EXTRACT)


func test_a_truncated_archive_is_not_extracted() -> void:
	# The regression this one exists for: an HTTP 200 was enough on its own, so a body
	# that never arrived whole went to the extraction thread and failed there as a
	# corrupt package -- which reads as a bad pack rather than a bad connection. A
	# proxy cutting the download short produces exactly this pair.
	for result_code: int in [HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED,
			HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH,
			HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED]:
		assert_eq(PackageDownloader.outcome_for_pack_download(result_code, 200),
			PackageDownloader.DownloadOutcome.NO_RESPONSE,
			"%s with a 200 still means the file is not all there"
			% ServerManagerClass.http_result_name(result_code))


func test_a_download_that_got_nothing_back_is_the_network() -> void:
	for result_code: int in [HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, HTTPRequest.RESULT_TIMEOUT,
			HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT]:
		assert_eq(PackageDownloader.outcome_for_pack_download(result_code, 0),
			PackageDownloader.DownloadOutcome.NO_RESPONSE)


func test_an_answer_that_is_not_the_file_is_a_refusal() -> void:
	# The pack URL is presigned and short-lived, so a 403 is a URL that went stale
	# rather than anything wrong with the network. Asking again mints a new one.
	for response_code: int in [400, 403, 404, 500, 503]:
		assert_eq(PackageDownloader.outcome_for_pack_download(HTTPRequest.RESULT_SUCCESS, response_code),
			PackageDownloader.DownloadOutcome.REFUSED,
			"S3 answered %d, so it is not the connection" % response_code)


# --- Which no-server error to report ------------------------------------------
##
## The diagnosis itself is ServerManager's and is exercised in test_network_evidence.gd
## against made-up evidence. What is this screen's own is the mapping from a diagnosed
## cause to one of its errors, and that is the half that silently rots: the enum here
## exists for archives and folders, so a network cause with no entry falls through to
## "you have no internet access" -- the wrong instruction for four of the five new ones.

func test_every_diagnosed_cause_has_an_error_of_its_own() -> void:
	var seen: Array[int] = []
	for cause: int in ServerManagerClass.ConnectionFailure.values():
		if cause == ServerManagerClass.ConnectionFailure.NONE:
			continue
		var slot: String = ConnectionNotice.slot_for(cause)
		assert_true(PackageDownloader.NETWORK_ERRORS.has(slot),
			"%s (%s) has no error on the download screen"
				% [ServerManagerClass.ConnectionFailure.keys()[cause], slot])
		seen.append(PackageDownloader.error_for(slot))
	assert_eq(seen.size(), (seen as Array).duplicate().size(),
		"the causes should not share an error")


func test_a_reachable_internet_still_means_kalulu_is_blocked() -> void:
	# The probe got through and the API did not, so the network is filtering this app.
	# The general case, and the one every unrecognised cause falls back to.
	assert_eq(PackageDownloader.error_for("blocked"),
		PackageDownloader.DownloadError.KALULU_BLOCKED)
	assert_eq(PackageDownloader.error_for("something-nobody-has-written-yet"),
		PackageDownloader.DownloadError.KALULU_BLOCKED,
		"never silence, and never the internet-access message")


func test_an_unreachable_internet_still_means_the_device_is_offline() -> void:
	assert_eq(PackageDownloader.error_for("offline"),
		PackageDownloader.DownloadError.NO_INTERNET)


func test_the_causes_the_reader_can_act_on_alone_are_not_offered_for_copying() -> void:
	# A clock is corrected in the device's settings and a proxy Kalulu has already
	# switched on has nobody left to tell. Mailing either to a technician sends the
	# reader down a corridor to be told to go back and press the button.
	for slot: String in ["clock", "proxy_available"]:
		assert_false(PackageDownloader.error_for(slot) in PackageDownloader.REPORTABLE_ERRORS,
			"%s is fixed where the reader is standing" % slot)
	for slot: String in ["blocked", "offline", "dns", "intercepted", "proxy_required"]:
		assert_true(PackageDownloader.error_for(slot) in PackageDownloader.REPORTABLE_ERRORS,
			"%s is somebody else's to act on" % slot)


func test_every_network_error_has_a_heading_for_the_dead_end_notice() -> void:
	# With no usable pack there is nowhere to send the device, so the notice is the
	# whole screen and a heading-less one reads as a fragment.
	for slot: String in PackageDownloader.NETWORK_ERRORS:
		var error: int = PackageDownloader.error_for(slot)
		if error == PackageDownloader.DownloadError.NO_INTERNET:
			continue  # keeps the original "an internet connection is required" heading
		assert_true(PackageDownloader.DEAD_END_NOTICES.has(error),
			"%s needs a heading" % slot)


# --- The messages -------------------------------------------------------------
func test_every_error_has_a_message() -> void:
	# The enum indexes into ERROR_MESSAGES, so a value added to one and not the other
	# reads past the end of the array.
	assert_eq((PackageDownloader.ERROR_MESSAGES as Array[String]).size(),
		(PackageDownloader.DownloadError.keys() as Array).size(),
		"every DownloadError needs its translation key, in the same order")


func test_every_network_notice_is_written_in_every_language_the_app_speaks() -> void:
	# A row missing from one column of the CSV shows the raw key, in capitals, to the
	# teachers reading that language and to nobody else -- so it survives every test
	# run on a French machine. That is exactly how USED_EMAIL_ADDRESS shipped.
	var was: String = TranslationServer.get_locale()
	for locale: String in ["fr", "es", "pt_BR", "it"]:
		TranslationServer.set_locale(locale)
		for slot: String in PackageDownloader.NETWORK_ERRORS:
			var error: int = PackageDownloader.error_for(slot)
			var keys: Array[String] = [PackageDownloader.ERROR_MESSAGES[error]]
			if PackageDownloader.DEAD_END_NOTICES.has(error):
				keys.append(str(PackageDownloader.DEAD_END_NOTICES[error]["title"]))
				keys.append(str(PackageDownloader.DEAD_END_NOTICES[error]["message"]))
			for key: String in keys:
				assert_ne(tr(key), key, "%s has no %s translation" % [key, locale])
	TranslationServer.set_locale(was)


func test_the_blocked_message_is_translated_and_says_what_to_do() -> void:
	for key: String in ["KALULU_BLOCKED_TITLE", "DOWNLOAD_KALULU_BLOCKED"]:
		assert_ne(tr(key), key, "%s should be translated" % key)

	var message: String = tr("DOWNLOAD_KALULU_BLOCKED")
	assert_gt(message.length(), 60, "it should explain, not just label")
	assert_string_contains(message.to_lower(), "internet",
		"it has to say the internet is working, which is the whole point")


func test_the_server_error_notice_does_not_blame_the_connection() -> void:
	# Shown when the server failed and there is no pack to fall back on. The notice it
	# replaces asks for an internet connection that is working perfectly.
	for key: String in ["SERVER_UNAVAILABLE_TITLE", "NO_LANGUAGE_PACK_SERVER_ERROR"]:
		assert_ne(tr(key), key, "%s should be translated" % key)

	var message: String = tr("NO_LANGUAGE_PACK_SERVER_ERROR")
	assert_gt(message.length(), 60, "it should explain, not just label")
	# "serv" rather than a whole word: it has to hold in whichever locale the suite
	# runs in, and serveur / servidor / server all start there.
	assert_string_contains(message.to_lower(), "serv",
		"it should name the server as the cause")


func test_the_blocked_message_is_the_one_the_error_maps_to() -> void:
	var messages: Array[String] = PackageDownloader.ERROR_MESSAGES
	assert_eq(messages[PackageDownloader.DownloadError.KALULU_BLOCKED], "DOWNLOAD_KALULU_BLOCKED")
	assert_eq(messages[PackageDownloader.DownloadError.NO_INTERNET], "NO_INTERNET_ACCESS")

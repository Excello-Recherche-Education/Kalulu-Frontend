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


# --- Which no-server error to report ------------------------------------------

func test_a_reachable_internet_means_kalulu_is_blocked() -> void:
	# The probe got through and the API did not, so the network is filtering this app.
	downloader.internet_reachable = true
	assert_eq(downloader._no_server_error(), PackageDownloader.DownloadError.KALULU_BLOCKED)


func test_an_unreachable_internet_means_the_device_is_offline() -> void:
	downloader.internet_reachable = false
	ServerManager.last_internet_result_code = HTTPRequest.RESULT_CANT_RESOLVE
	assert_eq(downloader._no_server_error(), PackageDownloader.DownloadError.NO_INTERNET)


func test_a_probe_refused_at_the_tls_handshake_still_means_blocked() -> void:
	# Nothing was reachable, but something answered and then refused its own
	# certificate: a proxy standing in for every host, Kalulu included.
	downloader.internet_reachable = false
	ServerManager.last_internet_result_code = HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR
	assert_eq(downloader._no_server_error(), PackageDownloader.DownloadError.KALULU_BLOCKED)


# --- The messages -------------------------------------------------------------

func test_every_error_has_a_message() -> void:
	# The enum indexes into ERROR_MESSAGES, so a value added to one and not the other
	# reads past the end of the array.
	assert_eq((PackageDownloader.ERROR_MESSAGES as Array[String]).size(),
		(PackageDownloader.DownloadError.keys() as Array).size(),
		"every DownloadError needs its translation key, in the same order")


func test_the_blocked_message_is_translated_and_says_what_to_do() -> void:
	for key: String in ["KALULU_BLOCKED_TITLE", "DOWNLOAD_KALULU_BLOCKED"]:
		assert_ne(tr(key), key, "%s should be translated" % key)

	var message: String = tr("DOWNLOAD_KALULU_BLOCKED")
	assert_gt(message.length(), 60, "it should explain, not just label")
	assert_string_contains(message.to_lower(), "internet",
		"it has to say the internet is working, which is the whole point")


func test_the_blocked_message_is_the_one_the_error_maps_to() -> void:
	var messages: Array[String] = PackageDownloader.ERROR_MESSAGES
	assert_eq(messages[PackageDownloader.DownloadError.KALULU_BLOCKED], "DOWNLOAD_KALULU_BLOCKED")
	assert_eq(messages[PackageDownloader.DownloadError.NO_INTERNET], "NO_INTERNET_ACCESS")

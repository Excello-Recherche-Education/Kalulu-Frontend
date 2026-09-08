extends GutTest
## ServerManager.diagnosis_for, which decides what a failed request is blamed on.
##
## The distinction is worth testing because the two answers ask the teacher to do
## opposite things: check the tablet's connection, or leave the tablet alone and go
## through the network. Telling a working network it has no internet is the failure
## these tests exist to prevent -- it cost a support ticket to identify once.
##
## diagnosis_for takes the probe's outcome as its only input, so none of this needs
## a network, a server, or ServerManager's live state.

const NO_NETWORK: ServerManagerClass.ConnectionFailure = ServerManagerClass.ConnectionFailure.NO_NETWORK
const BLOCKED: ServerManagerClass.ConnectionFailure = ServerManagerClass.ConnectionFailure.KALULU_BLOCKED


func test_a_reachable_internet_means_only_kalulu_is_blocked() -> void:
	# The tablet is online, so whatever stopped the login sits between it and the
	# API alone: a firewall rule, or DNS filtering on the domain.
	assert_eq(ServerManagerClass.diagnosis_for(true, HTTPRequest.RESULT_SUCCESS), BLOCKED)


func test_a_probe_refused_at_the_tls_handshake_still_means_blocked() -> void:
	# Something answered and then refused the certificate. That is a proxy standing
	# in for every host it is asked for, not an absent network -- and it is the shape
	# the school network took in the ticket.
	assert_eq(ServerManagerClass.diagnosis_for(false, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR), BLOCKED)


func test_an_unresolvable_probe_means_no_network() -> void:
	# Nothing answered at all, which is what airplane mode and a dead router look like.
	assert_eq(ServerManagerClass.diagnosis_for(false, HTTPRequest.RESULT_CANT_RESOLVE), NO_NETWORK)


func test_an_unconnectable_probe_means_no_network() -> void:
	assert_eq(ServerManagerClass.diagnosis_for(false, HTTPRequest.RESULT_CANT_CONNECT), NO_NETWORK)


func test_a_probe_that_timed_out_means_no_network() -> void:
	# A silent drop is indistinguishable from being offline from here, and "check
	# your connection" is the safer of the two instructions to give for it.
	assert_eq(ServerManagerClass.diagnosis_for(false, HTTPRequest.RESULT_TIMEOUT), NO_NETWORK)


func test_reaching_the_internet_wins_over_the_stale_code() -> void:
	# The probe records a code on every run, so a success carries the previous
	# failure's code with it. Reachability has to be read first.
	assert_eq(ServerManagerClass.diagnosis_for(true, HTTPRequest.RESULT_CANT_RESOLVE), BLOCKED)


func test_the_two_answers_are_the_ones_the_login_screen_maps() -> void:
	# welcome.gd only distinguishes KALULU_BLOCKED from everything else, so a third
	# failure added here would silently fall back to the internet-access message.
	assert_eq((ServerManagerClass.ConnectionFailure.keys() as Array).size(), 3,
		"NONE, NO_NETWORK and KALULU_BLOCKED; a new one needs a message in welcome.gd")


# --- One probe, several callers -----------------------------------------------
func test_a_second_caller_waits_instead_of_being_told_it_is_offline() -> void:
	# There is one HTTPRequest for the probe, shared by every caller, and it answers
	# ERR_BUSY while it is working. That used to be returned as a verdict, so a
	# second caller read "busy" as "offline" -- the same false alarm these tests
	# exist to prevent, on a network with nothing wrong with it at all.
	var manager: ServerManagerClass = ServerManager as ServerManagerClass
	var was_running: bool = manager.internet_check_running
	manager.internet_check_running = true

	var answers: Array[bool] = []
	var ask: Callable = func() -> void:
		answers.append(await manager.check_internet_access())
	ask.call()
	await get_tree().process_frame

	assert_eq(answers.size(), 0, "the second caller should be waiting, not answered")
	manager.internet_check_completed.emit(true)
	await get_tree().process_frame
	assert_eq(answers, [true] as Array[bool], "it should get the running probe's answer")

	manager.internet_check_running = was_running


# --- What the message hands to whoever runs the network ------------------------

## The pack is fetched straight from S3 with a presigned URL, so unblocking the API
## alone leaves the download failing. Kalulu-Languages-Checker reads the same bucket
## and spells the host out in available_packs.gd.
const PACK_HOST: String = "kalulu-app-language-packs.s3.eu-west-3.amazonaws.com"
## Each domain is marked, so a line that wraps -- which carries no mark -- cannot be
## read as one more domain. It was: the pack host broke mid-name and the tail looked
## like a third entry underneath.
const DOMAIN_MARK: String = "• "


func test_the_blocked_message_names_the_api_host_the_app_actually_calls() -> void:
	# Tied to the constant rather than to a copy of it: moving the API without
	# rewriting the message would hand a network administrator a dead domain.
	var api_host: String = ServerManagerClass.AWS_API_GATEWAY_DOMAIN_ADRESS.trim_suffix("/")
	for key: String in ["LOGIN_KALULU_BLOCKED", "DOWNLOAD_KALULU_BLOCKED"]:
		assert_string_contains(tr(key), api_host,
			"%s should name the host that was refused" % key)


func test_the_blocked_message_names_the_pack_host_too() -> void:
	# Both legs have to be named at once. A network opened for one and not the other
	# fails later, on a different screen, and looks like a new problem.
	for key: String in ["LOGIN_KALULU_BLOCKED", "DOWNLOAD_KALULU_BLOCKED"]:
		assert_string_contains(tr(key), PACK_HOST,
			"%s should name the language pack host as well" % key)


func test_the_domains_are_set_apart_from_the_advice() -> void:
	# They are for a different reader than the rest of the message, and they are meant
	# to be copied. One per line, after a blank line, rather than buried in a sentence.
	for key: String in ["LOGIN_KALULU_BLOCKED", "DOWNLOAD_KALULU_BLOCKED"]:
		var message: String = tr(key)
		assert_string_contains(message, "\n\n", "%s should break before the domains" % key)
		var lines: PackedStringArray = message.split("\n")
		assert_eq(lines[lines.size() - 2],
			DOMAIN_MARK + ServerManagerClass.AWS_API_GATEWAY_DOMAIN_ADRESS.trim_suffix("/"),
			"%s should end with one marked domain per line" % key)
		assert_eq(lines[lines.size() - 1], DOMAIN_MARK + PACK_HOST,
			"%s should end with one marked domain per line" % key)

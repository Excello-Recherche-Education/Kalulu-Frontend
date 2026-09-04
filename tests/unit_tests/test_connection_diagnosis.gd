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

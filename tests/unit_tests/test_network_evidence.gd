extends GutTest
## What each shape of failure is blamed on, given only what was observed.
##
## Every case here is a real one a teacher has reported or could report, written down
## as the evidence the probes would have gathered. None of it needs a network: the
## probes are impure and are not exercised, and [method ServerManagerClass.diagnose]
## -- the half that decides -- takes a [ConnectionEvidence] and nothing else.
##
## The fixture below is the important detail. It starts from a plain "the request did
## not come back" and each test changes only the field it is about, so a test that
## passes for the wrong reason is visible: if a field it never touches is what made
## the answer, the test above it would have given the same one.

const Cause: Dictionary = ServerManagerClass.ConnectionFailure


## A request that failed, with nothing yet learned about why.
func _failed() -> ConnectionEvidence:
	var evidence: ConnectionEvidence = ConnectionEvidence.new()
	evidence.request_result = HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR
	evidence.host_resolved = true
	evidence.host_address = "52.47.163.189"
	return evidence


func test_a_request_that_came_back_is_not_a_failure_at_all() -> void:
	var evidence: ConnectionEvidence = ConnectionEvidence.new()
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.NONE)


# --- DNS ------------------------------------------------------------------------

func test_a_name_that_does_not_resolve_on_a_working_connection_is_filtering() -> void:
	# The distinction the old single probe could not make: a refused name and an
	# unplugged cable both stop the request before anything is dialled. What tells
	# them apart is whether anything else on the device reaches the internet.
	var evidence: ConnectionEvidence = _failed()
	evidence.host_resolved = false
	evidence.host_address = ""
	evidence.probe_reached_internet = true
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.DNS_FILTERED)


func test_a_name_that_does_not_resolve_with_no_internet_either_is_just_offline() -> void:
	# In airplane mode nothing resolves. Reading that as a DNS filter would send a
	# teacher to argue with an administrator about a domain nobody has blocked --
	# and it is the likelier of the two situations by a long way.
	var evidence: ConnectionEvidence = _failed()
	evidence.host_resolved = false
	evidence.host_address = ""
	evidence.probe_reached_internet = false
	evidence.probe_result = HTTPRequest.RESULT_CANT_RESOLVE
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.NO_NETWORK)


func test_a_name_answered_with_a_local_address_needs_no_corroboration() -> void:
	# The commoner half of DNS filtering, and the invisible one: the name resolves,
	# the connection is made, and what answers is the filter's own block page.
	#
	# Unlike a name that will not resolve, this one stands on its own: an absent
	# network answers nothing at all, it does not answer 127.0.0.1. So it is read as
	# filtering even with no reachable internet to confirm it.
	for address: String in ["0.0.0.0", "127.0.0.1", "192.168.1.1", "10.0.0.5", "172.20.1.1"]:
		var evidence: ConnectionEvidence = _failed()
		evidence.host_address = address
		evidence.probe_reached_internet = false
		assert_eq(ServerManagerClass.diagnose(evidence), Cause.DNS_FILTERED,
			"%s cannot be Kalulu's API, which is on AWS" % address)


func test_the_private_range_stops_where_it_actually_stops() -> void:
	# 172.16 through 172.31 are private and 172.15 and 172.32 are not, so a prefix
	# match on "172." would call a public address a filter.
	assert_true(ConnectionEvidence.address_is_local("172.16.0.1"))
	assert_true(ConnectionEvidence.address_is_local("172.31.255.254"))
	assert_false(ConnectionEvidence.address_is_local("172.15.0.1"))
	assert_false(ConnectionEvidence.address_is_local("172.32.0.1"))
	assert_false(ConnectionEvidence.address_is_local("52.47.163.189"))


func test_an_address_nobody_asked_for_is_not_evidence_of_anything() -> void:
	# An empty address means the probe did not run, not that it failed.
	assert_false(ConnectionEvidence.address_is_local(""))


# --- Interception, and the clock it is confused with ------------------------------

func test_an_unverified_retry_getting_through_means_something_is_in_the_way() -> void:
	# The real request failed on the certificate and a retry that checks no
	# certificate succeeded. Something is there; only its identity was wrong.
	var evidence: ConnectionEvidence = _failed()
	evidence.unsafe_reached = true
	evidence.unsafe_body_is_ours = true
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.TLS_INTERCEPTED)


func test_a_block_page_coming_back_is_interception_as_well() -> void:
	# Same mechanism, different politeness: this one answers with its own page
	# instead of forwarding ours.
	var evidence: ConnectionEvidence = _failed()
	evidence.unsafe_reached = true
	evidence.unsafe_body_is_ours = false
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.TLS_INTERCEPTED)


func test_a_clock_far_enough_out_is_named_before_interception() -> void:
	# The two are indistinguishable up to this point -- both fail the handshake, both
	# let the unverified retry through -- so the clock has to be asked first or it is
	# never reached, and every stale tablet is reported as having an antivirus.
	var evidence: ConnectionEvidence = _failed()
	evidence.unsafe_reached = true
	evidence.unsafe_body_is_ours = true
	evidence.clock_offset_known = true
	evidence.clock_offset_seconds = -92 * 86400
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.CLOCK_SKEW)


func test_a_clock_that_merely_drifts_is_not_blamed() -> void:
	# Certificates are issued for months. An hour out invalidates nothing, and sending
	# a teacher to the date settings for it wastes the one instruction she is given.
	var evidence: ConnectionEvidence = _failed()
	evidence.unsafe_reached = true
	evidence.unsafe_body_is_ours = true
	evidence.clock_offset_known = true
	evidence.clock_offset_seconds = 3600
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.TLS_INTERCEPTED)


func test_an_unmeasured_clock_is_not_a_clock_of_zero() -> void:
	# Nothing carried a Date header, so the offset is unknown rather than fine. It
	# must not become evidence that the clock is right.
	var evidence: ConnectionEvidence = _failed()
	evidence.unsafe_reached = true
	evidence.clock_offset_seconds = 92 * 86400
	evidence.clock_offset_known = false
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.TLS_INTERCEPTED)


# --- Proxies ---------------------------------------------------------------------

func test_a_407_is_weighed_before_the_request_is_called_a_success() -> void:
	# It *is* a completed HTTP exchange -- with the proxy. Asked second, it would be
	# read as a healthy connection and the login screen would blame the password.
	var evidence: ConnectionEvidence = ConnectionEvidence.new()
	evidence.request_result = HTTPRequest.RESULT_SUCCESS
	evidence.proxy_auth_required = true
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.PROXY_REQUIRED)


func test_a_working_system_proxy_outranks_naming_what_blocked_the_direct_route() -> void:
	# There is nothing to tell the reader and nothing for her to do: the way through
	# has been found and switched on. Whatever stopped the direct attempt is true and
	# useless.
	var evidence: ConnectionEvidence = _failed()
	evidence.host_resolved = false
	evidence.probe_reached_internet = true
	evidence.system_proxy_works = true
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.PROXY_AVAILABLE)


# --- The two answers that existed before -----------------------------------------

func test_a_reachable_internet_with_nothing_else_found_is_still_blocked() -> void:
	var evidence: ConnectionEvidence = _failed()
	evidence.probe_reached_internet = true
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.KALULU_BLOCKED)


func test_nothing_reachable_anywhere_is_an_absent_network() -> void:
	var evidence: ConnectionEvidence = _failed()
	evidence.probe_reached_internet = false
	evidence.probe_result = HTTPRequest.RESULT_CANT_CONNECT
	assert_eq(ServerManagerClass.diagnose(evidence), Cause.NO_NETWORK)


# --- Reading a Date header --------------------------------------------------------

func test_the_clock_offset_is_read_off_a_real_header() -> void:
	# The shape is fixed by RFC 7231 and is always English, whatever the device's
	# locale -- which is why the month names are a constant and not a translation.
	var midnight: int = int(Time.get_unix_time_from_datetime_dict({
			"year": 2026, "month": 9, "day": 15, "hour": 6, "minute": 59, "second": 20}))
	assert_eq(ServerManagerClass.clock_offset_from(
			"Tue, 15 Sep 2026 06:59:20 GMT", midnight), 0)
	assert_eq(ServerManagerClass.clock_offset_from(
			"Tue, 15 Sep 2026 06:59:20 GMT", midnight + 3600), 3600,
		"a device an hour ahead reads as positive")


func test_a_header_that_makes_no_sense_offsets_nothing() -> void:
	# Better a missed diagnosis than a fabricated one: a garbled header must not
	# produce an offset of several decades and send a teacher to her clock settings.
	for header: String in ["", "yesterday", "Tue, 15 Zzz 2026 06:59:20 GMT", "Tue 15"]:
		assert_eq(ServerManagerClass.clock_offset_from(header, 0), 0,
			"'%s' says nothing about the clock" % header)


# --- Which host is even asked about ------------------------------------------------

func test_the_host_is_taken_out_of_whatever_shape_the_environment_url_is_in() -> void:
	# A custom environment URL is typed by hand in the developer settings, so all of
	# these reach this function.
	assert_eq(ServerManagerClass.host_of("https://api.kalulu.org/prod/"), "api.kalulu.org")
	assert_eq(ServerManagerClass.host_of("https://dev.api.kalulu.org/dev/"), "dev.api.kalulu.org")
	assert_eq(ServerManagerClass.host_of("http://192.168.1.4:8000/"), "192.168.1.4")
	assert_eq(ServerManagerClass.host_of("api.kalulu.org/prod/"), "api.kalulu.org")
	assert_eq(ServerManagerClass.host_of(""), "")

class_name ConnectionEvidence
extends RefCounted
## What was observed about one failed request, before anything is concluded from it.
##
## The diagnosis used to be taken from a single probe to a third-party host, which
## can only separate "no internet" from "something stops Kalulu". Those two cover
## the school firewall, and nothing else: a filtered DNS, an antivirus decrypting
## HTTPS and a device whose clock is two years out all arrive as the same silence,
## and each of the three needs a different thing done about it.
##
## So the observations are gathered first and interpreted afterwards. Every field is
## something measured; nothing here decides anything. [method ServerManagerClass.diagnose]
## is the only place that turns them into a cause, which is what makes that decision
## testable without a network -- the probes are the half that cannot be.
##
## The defaults are deliberately the innocent ones: a caller that could not run a
## given probe leaves its field alone and the diagnosis simply does not reach the
## conclusions that field would support. A missing observation must never become
## evidence of anything.

## The engine's own result for the request that failed. RESULT_SUCCESS means it did
## get an HTTP response and there is nothing here to explain.
var request_result: int = HTTPRequest.RESULT_SUCCESS
## Whether the probe to a host unrelated to Kalulu came back.
var probe_reached_internet: bool = false
## The engine's result for that probe.
var probe_result: int = HTTPRequest.RESULT_SUCCESS
## Whether the API's hostname resolved at all. False is an answered "no such host",
## which is what a DNS-level filter returns.
var host_resolved: bool = true
## What it resolved to, empty when it was not asked. A filter that answers with one
## of its own addresses rather than refusing is caught by [method address_is_local].
var host_address: String = ""
## Whether a retry that skipped certificate verification got an HTTP response.
##
## This is the one observation that separates "nothing is there" from "something is
## there wearing the wrong certificate", and every conclusion about interception
## rests on it.
var unsafe_reached: bool = false
## Whether that retry came back with Kalulu's own answer rather than somebody's
## block page. Both are interception; only one can be named to the reader.
var unsafe_body_is_ours: bool = false
## Signed difference between the device clock and the server's, in seconds.
var clock_offset_seconds: int = 0
## Whether any response carried a Date header to compare against. Without one the
## offset above is not zero, it is unknown.
var clock_offset_known: bool = false
## Whether a proxy answered 407, i.e. it is there and wants credentials.
var proxy_auth_required: bool = false
## Whether the proxy the rest of the machine uses got through where Kalulu could not.
##
## Only ever set when the machine has one configured at all, which is rare -- and
## decisive when it happens, because it means nothing is blocking Kalulu: the app was
## simply the one program on the machine dialling the internet directly.
var system_proxy_works: bool = false


## True when an address belongs to this machine or this LAN rather than the internet.
##
## A DNS filter has two ways to refuse a name: answer "no such host", or answer with
## an address of its own -- a loopback, an unroutable 0.0.0.0, or the filtering box
## itself on the local network. The second is the common one, because it lets the
## filter serve a "blocked" page, and it is invisible to every check except this one:
## the name resolves, the connection is made, and what answers is not us.
##
## Kalulu's API is on AWS and can therefore never legitimately be any of these.
static func address_is_local(address: String) -> bool:
	if address.is_empty():
		return false
	if address == "0.0.0.0" or address == "::" or address == "::1":
		return true
	if address.begins_with("127.") or address.begins_with("10.") \
			or address.begins_with("192.168.") or address.begins_with("169.254."):
		return true
	# fc00::/7 -- IPv6 unique local addresses, written fc.. or fd...
	if address.begins_with("fc") or address.begins_with("fd"):
		return true
	# 172.16.0.0/12 is the one private range that is not a plain prefix match:
	# 172.16 through 172.31 are private, 172.15 and 172.32 are not.
	if address.begins_with("172."):
		var second_octet: String = address.split(".")[1] if address.get_slice_count(".") > 1 else ""
		if second_octet.is_valid_int() and int(second_octet) >= 16 and int(second_octet) <= 31:
			return true
	return false

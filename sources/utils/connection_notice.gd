class_name ConnectionNotice
extends RefCounted
## Which notice a diagnosed failure deserves, shared by every screen that shows one.
##
## The cause is decided once, in [method ServerManagerClass.diagnose]. What is left is
## choosing words for it, and that happens on three screens -- the login, the
## registration wizard, the language pack downloader -- which phrase the same cause
## differently: "you cannot sign in" and "the account cannot be created" are not
## interchangeable, and a notice that says the wrong one reads as being about
## something else entirely.
##
## So the mapping from cause to *slot* lives here and the wording stays in the screen.
## That is the half that must not drift: a cause added to the enum and forgotten in
## one screen would silently fall back to "an error occurred", which is the failure
## this whole diagnosis exists to stop.

## The neutral name for each cause, and the key each screen keys its own wording on.
const SLOTS: Dictionary[int, String] = {
	ServerManagerClass.ConnectionFailure.NO_NETWORK: "offline",
	ServerManagerClass.ConnectionFailure.KALULU_BLOCKED: "blocked",
	ServerManagerClass.ConnectionFailure.DNS_FILTERED: "dns",
	ServerManagerClass.ConnectionFailure.TLS_INTERCEPTED: "intercepted",
	ServerManagerClass.ConnectionFailure.CLOCK_SKEW: "clock",
	ServerManagerClass.ConnectionFailure.PROXY_REQUIRED: "proxy_required",
	ServerManagerClass.ConnectionFailure.PROXY_AVAILABLE: "proxy_available",
}

## The slots nobody else can help with, and which are therefore not worth forwarding.
##
## A clock is corrected in the device's own settings, and a proxy Kalulu has already
## switched on has nothing left to arrange. Offering to mail either to a technician
## sends the reader down a corridor to be told to go back and press the button.
const SELF_INFLICTED_SLOTS: Array[String] = ["clock", "proxy_available"]


## The slot for a cause. "blocked" for anything unrecognised, which is the general
## case and carries the domains to unblock -- never silence.
static func slot_for(cause: ServerManagerClass.ConnectionFailure) -> String:
	return SLOTS.get(cause, "blocked")


## Whether a diagnosed failure is somebody else's to act on.
static func is_reportable(slot: String) -> bool:
	return not slot in SELF_INFLICTED_SLOTS

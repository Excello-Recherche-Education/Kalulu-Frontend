class_name SystemProxy
extends RefCounted
## Finds the proxy the rest of the machine is already using, so nobody has to type one.
##
## Godot does not read the system proxy. Not from the Windows registry, not from
## macOS's network settings, not from http_proxy in the environment -- [HTTPRequest]
## dials the host directly unless a proxy is set on it by hand. On a network whose
## only way out is an explicit proxy, that means every browser on the machine works
## and Kalulu alone does not, which reads exactly like "Kalulu is blocked" and is not.
##
## So the value is looked up where the operating system keeps it and offered as the
## default. The parsers are static and take the text rather than running anything,
## because that is the half worth testing: the platform-specific commands need the
## platform, but their output is just a string and every shape of it has been seen.
##
## Nothing here is applied on its own. [ServerManagerClass] decides whether to use
## what this finds, and the teacher can see and change it -- see [ProxySettings].

## Where each platform keeps it, in the order worth asking.
##
## The environment comes first everywhere: it is what a person who has already
## configured one tool by hand has set, and it costs nothing to read.
const ENVIRONMENT_KEYS: Array[String] = [
	"https_proxy", "HTTPS_PROXY", "http_proxy", "HTTP_PROXY", "all_proxy", "ALL_PROXY",
]
const WINDOWS_REGISTRY_KEY: String = \
	"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"
## The port a proxy is assumed to be on when the machine names a host and no port.
## 8080 rather than 80: a bare hostname in a proxy setting is a proxy, not a web server.
const DEFAULT_PORT: int = 8080


## Host and port as {"host": String, "port": int}, or an empty dictionary.
##
## Accepts every shape these values are written in: a bare "proxy.ac-normandie.fr",
## a "proxy:3128", a full "http://user:pass@proxy:3128/", and the
## "http=proxy:3128;https=proxy:3128" list Windows stores when the two differ.
## Credentials are dropped rather than carried: they belong to whoever configured
## the machine, and putting them in Kalulu's own config would copy a password out of
## the OS keystore into a file in the user directory.
static func parse(value: String) -> Dictionary:
	var text: String = value.strip_edges()
	if text.is_empty():
		return {}

	# "http=a:1;https=b:2" -- prefer the https entry, which is what we speak.
	if text.contains("="):
		var chosen: String = ""
		for entry: String in text.split(";", false):
			var pair: PackedStringArray = entry.split("=", true, 1)
			if pair.size() != 2:
				continue
			var scheme: String = pair[0].strip_edges().to_lower()
			if scheme == "https":
				chosen = pair[1]
				break
			if scheme == "http" and chosen.is_empty():
				chosen = pair[1]
		if chosen.is_empty():
			return {}
		text = chosen.strip_edges()

	var scheme_end: int = text.find("://")
	if scheme_end != -1:
		text = text.substr(scheme_end + 3)
	text = text.split("/")[0]
	if text.contains("@"):
		text = text.split("@")[-1]
	if text.is_empty():
		return {}

	var host: String = text
	var port: int = DEFAULT_PORT
	# A colon says a port follows, so one that is not a number makes the whole value
	# wrong rather than making the colon part of the hostname. Left as a hostname,
	# "proxy.ecole.fr:abc" was accepted, saved, and then dialled as a machine of that
	# name -- a typed mistake that reappeared as a connection failure with no
	# explanation. The bracket is for [::1]:3128, where the address has colons of its
	# own and only the last one can be a port.
	var colon: int = text.rfind(":")
	if colon > text.rfind("]") and colon > 0:
		var tail: String = text.substr(colon + 1)
		if not tail.is_valid_int():
			return {}
		host = text.substr(0, colon)
		port = int(tail)
	if host.is_empty() or port <= 0 or port > 65535:
		return {}
	return {"host": host, "port": port}


## The proxy in `scutil --proxy`'s output, or "".
##
## macOS prints a dictionary of flags and values; a proxy is only in use when its
## Enable flag is 1, and both halves have to be read together -- the host stays in
## the dictionary after the proxy is switched off, so reading it alone would offer a
## proxy the machine has stopped using.
static func parse_scutil(output: String) -> String:
	var values: Dictionary = {}
	for line: String in output.split("\n"):
		var pair: PackedStringArray = line.split(":", true, 1)
		if pair.size() != 2:
			continue
		values[pair[0].strip_edges()] = pair[1].strip_edges()
	for prefix: String in ["HTTPS", "HTTP"]:
		if str(values.get(prefix + "Enable", "0")) != "1":
			continue
		var host: String = str(values.get(prefix + "Proxy", ""))
		if host.is_empty():
			continue
		var port: String = str(values.get(prefix + "Port", ""))
		return "%s:%s" % [host, port] if port.is_valid_int() else host
	return ""


## The proxy in `reg query`'s output, or "".
##
## Same pairing as macOS: ProxyServer keeps its value while ProxyEnable is 0, which
## is the state a machine is left in when someone turns the proxy off for the day.
static func parse_windows_registry(output: String) -> String:
	var enabled: bool = false
	var server: String = ""
	for line: String in output.split("\n"):
		var fields: PackedStringArray = line.strip_edges().split(" ", false)
		if fields.size() < 3:
			continue
		match fields[0]:
			"ProxyEnable":
				# REG_DWORD prints as 0x0 / 0x1.
				enabled = fields[2] != "0x0"
			"ProxyServer":
				server = " ".join(fields.slice(2))
	return server if enabled else ""


## What the environment says, asking `getter` for each name in turn.
##
## The getter is a parameter so this can be checked against a made-up environment;
## [method detect] passes [method OS.get_environment].
static func from_environment(getter: Callable) -> String:
	for key: String in ENVIRONMENT_KEYS:
		var value: String = str(getter.call(key)).strip_edges()
		if not value.is_empty():
			return value
	return ""


## The proxy this machine is configured to use, as {"host", "port"}, or empty.
##
## The only impure function here. Mobile and web are skipped on purpose: neither
## exposes the setting, and a shell command that cannot run costs a stall on the
## exact screen a teacher is already waiting on.
static func detect() -> Dictionary:
	var raw: String = from_environment(OS.get_environment)
	if raw.is_empty():
		raw = _from_platform()
	if raw.is_empty():
		return {}
	var parsed: Dictionary = parse(raw)
	if parsed.is_empty():
		Log.warn("SystemProxy: Could not make sense of the system proxy setting")
		return {}
	Log.info("SystemProxy: The machine is configured for %s:%d" % [parsed["host"], parsed["port"]])
	return parsed


static func _from_platform() -> String:
	var output: Array = []
	match OS.get_name():
		"Windows":
			if OS.execute("reg", ["query", WINDOWS_REGISTRY_KEY], output, true) != 0:
				return ""
			return parse_windows_registry(_joined(output))
		"macOS":
			if OS.execute("scutil", ["--proxy"], output, true) != 0:
				return ""
			return parse_scutil(_joined(output))
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			if OS.execute("gsettings",
					["get", "org.gnome.system.proxy.http", "host"], output, true) != 0:
				return ""
			var host: String = _joined(output).strip_edges().trim_prefix("'").trim_suffix("'")
			if host.is_empty():
				return ""
			var port_output: Array = []
			if OS.execute("gsettings",
					["get", "org.gnome.system.proxy.http", "port"], port_output, true) != 0:
				return host
			return "%s:%s" % [host, _joined(port_output).strip_edges()]
	return ""


static func _joined(output: Array) -> String:
	var lines: Array[String] = []
	for chunk: Variant in output:
		lines.append(str(chunk))
	return "\n".join(lines)

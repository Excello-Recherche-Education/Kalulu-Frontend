class_name AppRelease
extends RefCounted
## One published version of the game, as the update check sees it.
##
## Read from the GitHub releases of Kalulu-Frontend. A release counts only once
## its Pre-release badge has come off: the release process drops it by hand when
## Apple and Google have both approved and published the same build, so it is the
## one signal that says "every user can get this now", store users included. Before
## that, a direct download would be ahead of the stores, and a store user would be
## told about an update their store does not offer yet.
##
## Pure data and parsing, with no network and no autoload, so every decision in it
## can be tested from a fixture.

## The prefix of the game's release tags. The Prof Tool's used to share this
## repository under `prof_tool/`, and those must never be offered to a game.
const TAG_PREFIX: String = "game/"

## The version, without the tag prefix: "3.1.7".
var version: String = ""
## The release's web page, for when nothing better can be offered.
var page_url: String = ""
## Every downloadable file of the release, keyed by its name. Each value has
## `url` (String), `size` (int) and `sha256` (String, lowercase hex, empty when
## GitHub gave none).
var assets: Dictionary[String, Dictionary] = {}


## The newest release a user can be offered, out of the list GitHub returns for
## `GET /repos/{owner}/{repo}/releases`, or null when there is none.
##
## Chosen by version rather than by position: the list is ordered by creation date,
## and a fix released for an older line would otherwise outrank the newest one.
static func newest_from_github_list(releases: Variant) -> AppRelease:
	if not releases is Array:
		return null
	var newest: AppRelease = null
	for entry: Variant in releases as Array:
		var release: AppRelease = from_github(entry)
		if release and (not newest or compare_versions(release.version, newest.version) > 0):
			newest = release
	return newest


## One release from GitHub's JSON, or null when it is not one to offer: a draft, a
## pre-release, another product's tag, or a tag that is not a version.
static func from_github(entry: Variant) -> AppRelease:
	if not entry is Dictionary:
		return null
	var data: Dictionary = entry as Dictionary
	if data.get("draft", true) != false or data.get("prerelease", true) != false:
		return null
	var tag: String = str(data.get("tag_name", ""))
	if not tag.begins_with(TAG_PREFIX):
		return null
	var release_version: String = tag.trim_prefix(TAG_PREFIX)
	if parse_version(release_version).is_empty():
		return null
	var release: AppRelease = AppRelease.new()
	release.version = release_version
	release.page_url = str(data.get("html_url", ""))
	var raw_assets: Variant = data.get("assets", [])
	if raw_assets is Array:
		for raw_asset: Variant in raw_assets as Array:
			if not raw_asset is Dictionary:
				continue
			var asset: Dictionary = raw_asset as Dictionary
			var asset_name: String = str(asset.get("name", ""))
			var url: String = str(asset.get("browser_download_url", ""))
			if asset_name.is_empty() or not url.begins_with("https://"):
				continue
			var digest: String = str(asset.get("digest", ""))
			release.assets[asset_name] = {
				"url": url,
				"size": int(asset.get("size", 0)),
				"sha256": digest.trim_prefix("sha256:").to_lower() if digest.begins_with("sha256:") else "",
			}
	return release


## The release's download for one platform: the asset whose name is
## `<prefix><version>.zip`, as `scripts/github-release.sh` names them
## (`Kalulu-Windows-3.1.7.zip`). Empty when the release has none.
func asset_for(prefix: String) -> Dictionary:
	if prefix.is_empty():
		return {}
	var asset_name: String = "%s%s.zip" % [prefix, version]
	if not assets.has(asset_name):
		return {}
	var asset: Dictionary = assets[asset_name].duplicate()
	asset["name"] = asset_name
	return asset


## The fields worth keeping between launches, so a check made yesterday can still
## show its answer offline.
func to_dictionary() -> Dictionary:
	return {"version": version, "page_url": page_url, "assets": assets}


static func from_dictionary(data: Dictionary) -> AppRelease:
	var release_version: String = str(data.get("version", ""))
	if parse_version(release_version).is_empty():
		return null
	var release: AppRelease = AppRelease.new()
	release.version = release_version
	release.page_url = str(data.get("page_url", ""))
	var raw_assets: Variant = data.get("assets", {})
	if raw_assets is Dictionary:
		for asset_name: Variant in raw_assets as Dictionary:
			var asset: Variant = (raw_assets as Dictionary)[asset_name]
			if asset is Dictionary:
				release.assets[str(asset_name)] = asset as Dictionary
	return release


## "3.1.7" as [3, 1, 7], or [] when it is not a dotted run of numbers.
##
## Strict on purpose: a version this cannot read is never offered, rather than
## compared as something it is not.
static func parse_version(text: String) -> Array[int]:
	var parts: Array[int] = []
	var pieces: PackedStringArray = text.strip_edges().split(".")
	if pieces.is_empty() or pieces.size() > 4:
		return []
	for piece: String in pieces:
		if piece.is_empty() or not piece.is_valid_int() or piece.begins_with("-") or piece.begins_with("+"):
			return []
		parts.append(piece.to_int())
	return parts


## -1, 0 or 1 as `a` is older than, the same as, or newer than `b`. A missing
## trailing number counts as 0, so "3.2" equals "3.2.0". An unreadable version
## compares as older than anything, so it can never cause an offer.
static func compare_versions(a: String, b: String) -> int:
	var left: Array[int] = parse_version(a)
	var right: Array[int] = parse_version(b)
	if left.is_empty() or right.is_empty():
		if left.is_empty() and right.is_empty():
			return 0
		return -1 if left.is_empty() else 1
	for index: int in maxi(left.size(), right.size()):
		var left_part: int = left[index] if index < left.size() else 0
		var right_part: int = right[index] if index < right.size() else 0
		if left_part != right_part:
			return -1 if left_part < right_part else 1
	return 0

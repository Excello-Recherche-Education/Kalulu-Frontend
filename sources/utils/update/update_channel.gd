class_name UpdateChannel
extends RefCounted
## Where this build of Kalulu came from, and therefore how it gets a newer one.
##
## The same project is exported as nine builds, and they must not all update the
## same way. A store build may only ever send its user to its own store: Google
## Play and the App Store both refuse an app that updates itself or points at a
## download elsewhere. A build downloaded from GitHub has no store, so it can
## fetch and install the new version itself.
##
## The export presets say which build is which, through custom feature tags --
## nothing at run time could tell an APK from an AAB, or the Mac App Store build
## from the notarized zip. A build with no tag (the editor, a test export) is
## treated as a direct download that may only open the download page, never as
## something that could install over itself.

enum Kind {
	## Not checked at all: the web build, which is always current.
	NONE,
	GOOGLE_PLAY,
	APP_STORE,
	MAC_APP_STORE,
	## Downloaded from GitHub. Installs in the app where the platform allows.
	DIRECT,
}

## The custom feature each export preset carries, in `export_presets.cfg`.
const FEATURE_GOOGLE_PLAY: String = "kalulu_google_play"
const FEATURE_MAC_APP_STORE: String = "kalulu_mac_app_store"
const FEATURE_DIRECT: String = "kalulu_direct_download"
## Kalulu's identities in the stores. The Play package is Godot's default name,
## shipped long ago and now permanent; both Apple platforms share one record.
const PLAY_PACKAGE: String = "org.godotengine.kalulu"
const APP_STORE_ID: String = "1639075967"
## Where the releases are read, and where their pages live.
const RELEASES_API_URL: String = "https://api.github.com/repos/Excello-Recherche-Education/Kalulu-Frontend/releases?per_page=20"
const RELEASES_PAGE_URL: String = "https://github.com/Excello-Recherche-Education/Kalulu-Frontend/releases"


## The channel of the running build.
static func current() -> Kind:
	return kind_for(func(feature: String) -> bool: return OS.has_feature(feature))


## The channel a build with these features belongs to. Takes the feature test as
## a callable so every combination can be checked without exporting anything.
static func kind_for(has_feature: Callable) -> Kind:
	if has_feature.call("web"):
		return Kind.NONE
	if has_feature.call("ios"):
		# The App Store is the only way onto an iPhone or iPad.
		return Kind.APP_STORE
	if has_feature.call(FEATURE_GOOGLE_PLAY):
		return Kind.GOOGLE_PLAY
	if has_feature.call(FEATURE_MAC_APP_STORE):
		return Kind.MAC_APP_STORE
	return Kind.DIRECT


## Whether the running build may replace itself. Only a direct-download build
## exported from its preset, never the editor or an untagged export.
static func may_install_itself() -> bool:
	return current() == Kind.DIRECT and OS.has_feature(FEATURE_DIRECT) \
			and not OS.has_feature("editor")


## The store pages to try in turn: the store app's own address first, the web
## page if that fails (a tablet without the Play Store, for instance).
static func store_urls(kind: Kind) -> Array[String]:
	match kind:
		Kind.GOOGLE_PLAY:
			return ["market://details?id=" + PLAY_PACKAGE,
					"https://play.google.com/store/apps/details?id=" + PLAY_PACKAGE]
		Kind.APP_STORE:
			return ["itms-apps://apps.apple.com/app/id" + APP_STORE_ID,
					"https://apps.apple.com/app/id" + APP_STORE_ID]
		Kind.MAC_APP_STORE:
			return ["macappstore://apps.apple.com/app/id" + APP_STORE_ID,
					"https://apps.apple.com/app/id" + APP_STORE_ID]
	return []


## The start of this platform's download name on a release, as
## `scripts/github-release.sh` names them, or "" when the release carries none for
## it. There is no 32-bit Android download: that APK is not published.
static func asset_prefix(has_feature: Callable) -> String:
	if has_feature.call("android"):
		return "" if has_feature.call("arm32") else "Kalulu-Android-"
	if has_feature.call("windows"):
		return "Kalulu-Windows-"
	if has_feature.call("linuxbsd"):
		return "Kalulu-Linux-"
	if has_feature.call("macos"):
		return "Kalulu-macOS-"
	return ""


static func current_asset_prefix() -> String:
	return asset_prefix(func(feature: String) -> bool: return OS.has_feature(feature))

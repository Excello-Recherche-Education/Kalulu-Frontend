extends GutTest
## UpdateChannel: each build is sent to the right place for its update, and a
## store build is never sent anywhere but its store.


func _features(names: Array) -> Callable:
	return func(feature: String) -> bool: return feature in names


func test_each_export_has_its_channel() -> void:
	assert_eq(UpdateChannel.kind_for(_features(["android", UpdateChannel.FEATURE_GOOGLE_PLAY])), UpdateChannel.Kind.GOOGLE_PLAY)
	assert_eq(UpdateChannel.kind_for(_features(["android", UpdateChannel.FEATURE_DIRECT])), UpdateChannel.Kind.DIRECT)
	assert_eq(UpdateChannel.kind_for(_features(["ios"])), UpdateChannel.Kind.APP_STORE)
	assert_eq(UpdateChannel.kind_for(_features(["macos", UpdateChannel.FEATURE_MAC_APP_STORE])), UpdateChannel.Kind.MAC_APP_STORE)
	assert_eq(UpdateChannel.kind_for(_features(["macos", UpdateChannel.FEATURE_DIRECT])), UpdateChannel.Kind.DIRECT)
	assert_eq(UpdateChannel.kind_for(_features(["windows", UpdateChannel.FEATURE_DIRECT])), UpdateChannel.Kind.DIRECT)
	assert_eq(UpdateChannel.kind_for(_features(["web"])), UpdateChannel.Kind.NONE)


func test_store_builds_only_open_their_own_store() -> void:
	for url: String in UpdateChannel.store_urls(UpdateChannel.Kind.GOOGLE_PLAY):
		assert_true("play.google.com" in url or url.begins_with("market://"), url)
		assert_true(UpdateChannel.PLAY_PACKAGE in url)
	for url: String in UpdateChannel.store_urls(UpdateChannel.Kind.APP_STORE):
		assert_true("apps.apple.com" in url, url)
	for url: String in UpdateChannel.store_urls(UpdateChannel.Kind.MAC_APP_STORE):
		assert_true("apps.apple.com" in url, url)
	assert_true(UpdateChannel.store_urls(UpdateChannel.Kind.DIRECT).is_empty())


func test_each_platform_finds_its_download() -> void:
	assert_eq(UpdateChannel.asset_prefix(_features(["windows"])), "Kalulu-Windows-")
	assert_eq(UpdateChannel.asset_prefix(_features(["linuxbsd"])), "Kalulu-Linux-")
	assert_eq(UpdateChannel.asset_prefix(_features(["macos"])), "Kalulu-macOS-")
	assert_eq(UpdateChannel.asset_prefix(_features(["android", "arm64"])), "Kalulu-Android-")
	assert_eq(UpdateChannel.asset_prefix(_features(["android", "arm32"])), "", "the 32-bit APK is not published")


## The presets are what tell the builds apart, so a preset losing its tag would
## turn a store build into one that installs itself -- which both stores forbid.
func test_every_export_preset_carries_its_channel() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	var expected: Dictionary[String, String] = {
		"Android Kalulu AAB": UpdateChannel.FEATURE_GOOGLE_PLAY,
		"Android Kalulu APK": UpdateChannel.FEATURE_DIRECT,
		"Android Kalulu APK 32 bits": UpdateChannel.FEATURE_DIRECT,
		"Windows Kalulu": UpdateChannel.FEATURE_DIRECT,
		"Linux Kalulu": UpdateChannel.FEATURE_DIRECT,
		"macOS Kalulu": UpdateChannel.FEATURE_DIRECT,
		"macOS Kalulu App Store": UpdateChannel.FEATURE_MAC_APP_STORE,
		"iOS Kalulu": "",
	}
	var seen: Array[String] = []
	for section: String in presets.get_sections():
		if section.contains(".options"):
			continue
		var preset_name: String = str(presets.get_value(section, "name", ""))
		if not expected.has(preset_name):
			continue
		seen.append(preset_name)
		var features: PackedStringArray = str(presets.get_value(section, "custom_features", "")).split(",", false)
		var channel_features: Array[String] = []
		for feature: String in features:
			if feature.strip_edges().begins_with("kalulu_"):
				channel_features.append(feature.strip_edges())
		var wanted: Array[String] = []
		if not expected[preset_name].is_empty():
			wanted.append(expected[preset_name])
		assert_eq(channel_features, wanted, preset_name)
	assert_eq(seen.size(), expected.size(), "every preset was found")


## Only the sideloaded APKs may ask to install packages: Google Play refuses an
## app that does, unless that is its purpose.
func test_only_the_direct_apks_may_install_packages() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	for section: String in presets.get_sections():
		if section.contains(".options"):
			continue
		var preset_name: String = str(presets.get_value(section, "name", ""))
		if not preset_name.begins_with("Android"):
			continue
		var permissions: PackedStringArray = presets.get_value(section + ".options",
				"permissions/custom_permissions", PackedStringArray()) as PackedStringArray
		var asks: bool = "android.permission.REQUEST_INSTALL_PACKAGES" in permissions
		assert_eq(asks, preset_name != "Android Kalulu AAB", preset_name)

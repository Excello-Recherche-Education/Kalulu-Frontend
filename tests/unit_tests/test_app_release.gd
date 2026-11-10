extends GutTest
## AppRelease: which GitHub release counts as an update, and how versions compare.


func _release(tag: String, prerelease: bool = false, draft: bool = false) -> Dictionary:
	return {
		"tag_name": tag,
		"prerelease": prerelease,
		"draft": draft,
		"html_url": "https://github.com/Excello-Recherche-Education/Kalulu-Frontend/releases/tag/" + tag,
		"assets": [
			{
				"name": "Kalulu-Windows-%s.zip" % tag.trim_prefix("game/"),
				"size": 1234,
				"digest": "sha256:ABCDEF",
				"browser_download_url": "https://github.com/x/y/releases/download/%s/Kalulu-Windows-%s.zip" % [tag, tag.trim_prefix("game/")],
			},
			{"name": "no-url.zip", "size": 1},
			{"name": "plain-http.zip", "browser_download_url": "http://example.com/plain-http.zip"},
		],
	}


func test_versions_compare_numerically() -> void:
	assert_eq(AppRelease.compare_versions("3.1.10", "3.1.9"), 1)
	assert_eq(AppRelease.compare_versions("3.1.9", "3.1.10"), -1)
	assert_eq(AppRelease.compare_versions("3.2", "3.2.0"), 0)
	assert_eq(AppRelease.compare_versions("4.0.0", "3.99.99"), 1)
	assert_eq(AppRelease.compare_versions("3.1.7", "3.1.7"), 0)


func test_an_unreadable_version_never_wins() -> void:
	assert_eq(AppRelease.compare_versions("3.1.x", "0.0.1"), -1)
	assert_eq(AppRelease.compare_versions("3.1.7", ""), 1)
	assert_eq(AppRelease.parse_version("3.1.7-rc1"), [] as Array[int])
	assert_eq(AppRelease.parse_version("-3.1"), [] as Array[int])
	assert_eq(AppRelease.parse_version("+3.1"), [] as Array[int])
	assert_eq(AppRelease.parse_version("3..1"), [] as Array[int])
	assert_eq(AppRelease.parse_version("3.1.7"), [3, 1, 7] as Array[int])


func test_only_published_game_releases_count() -> void:
	assert_not_null(AppRelease.from_github(_release("game/3.1.7")))
	assert_null(AppRelease.from_github(_release("game/3.1.7", true)), "a pre-release is not on the stores yet")
	assert_null(AppRelease.from_github(_release("game/3.1.7", false, true)), "a draft is not published")
	assert_null(AppRelease.from_github(_release("prof_tool/1.5.14")), "the Prof Tool's releases are not the game's")
	assert_null(AppRelease.from_github(_release("game/next")))
	assert_null(AppRelease.from_github("not a release"))
	assert_null(AppRelease.from_github({"tag_name": "game/3.1.7"}), "a release that does not say it is published is not one")


func test_the_newest_version_wins_whatever_the_order() -> void:
	var newest: AppRelease = AppRelease.newest_from_github_list([
		_release("game/3.1.6"),
		_release("game/3.1.8", true),
		_release("game/3.1.7"),
		_release("prof_tool/9.9.9"),
		_release("game/3.1.5"),
	])
	assert_eq(newest.version, "3.1.7")
	assert_null(AppRelease.newest_from_github_list([]))
	assert_null(AppRelease.newest_from_github_list({"message": "API rate limit exceeded"}))


func test_assets_keep_only_https_downloads_with_their_digest() -> void:
	var release: AppRelease = AppRelease.from_github(_release("game/3.1.7"))
	assert_eq(release.assets.keys(), ["Kalulu-Windows-3.1.7.zip"])
	var asset: Dictionary = release.asset_for("Kalulu-Windows-")
	assert_eq(asset["name"], "Kalulu-Windows-3.1.7.zip")
	assert_eq(asset["size"], 1234)
	assert_eq(asset["sha256"], "abcdef")
	assert_true(release.asset_for("Kalulu-Linux-").is_empty())
	assert_true(release.asset_for("").is_empty())


func test_a_release_survives_the_cache() -> void:
	var release: AppRelease = AppRelease.from_github(_release("game/3.1.7"))
	var config: ConfigFile = ConfigFile.new()
	config.set_value("release", "data", release.to_dictionary())
	var reloaded: ConfigFile = ConfigFile.new()
	assert_eq(reloaded.parse(config.encode_to_text()), OK)
	var restored: AppRelease = AppRelease.from_dictionary(reloaded.get_value("release", "data") as Dictionary)
	assert_eq(restored.version, "3.1.7")
	assert_eq(restored.page_url, release.page_url)
	assert_eq(restored.asset_for("Kalulu-Windows-")["url"], release.asset_for("Kalulu-Windows-")["url"])
	assert_null(AppRelease.from_dictionary({}))

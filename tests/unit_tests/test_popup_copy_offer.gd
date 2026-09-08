extends GutTest
## The offer to copy a notice out of the shared dialog, and the room it needs.
##
## The dialog is used by every screen in the app, so the point of most of this is
## what does NOT change: the offer and the extra width are opt-in, and both have to
## be taken back when one screen reuses one dialog for a second message.

const POPUP_SCENE: String = "res://sources/ui/popup.tscn"

var popup: ConfirmPopup


func before_each() -> void:
	popup = (load(POPUP_SCENE) as PackedScene).instantiate() as ConfirmPopup
	add_child_autofree(popup)
	await get_tree().process_frame


# --- The offer ----------------------------------------------------------------

func test_a_dialog_offers_nothing_by_default() -> void:
	# Every other dialog in the app has to look exactly as it did.
	assert_eq(popup.copy_text, "", "no text to copy unless a screen sets one")
	assert_false(popup.copy_button.visible, "and no button offering to")


func test_setting_something_to_copy_makes_the_offer() -> void:
	popup.copy_text = "quelque chose à transmettre"
	# Headless has no clipboard, and the dialog refuses to offer what it cannot do.
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		assert_false(popup.copy_button.visible, "nothing to copy to, so nothing offered")
		return
	assert_true(popup.copy_button.visible)


func test_clearing_it_takes_the_offer_back() -> void:
	# One dialog is reused for every error on the downloader, so a message that can
	# be forwarded must not leave the offer standing on the next one that cannot.
	popup.copy_text = "quelque chose"
	popup.copy_text = ""
	assert_false(popup.copy_button.visible, "the offer belongs to the message that set it")


# --- The room the hostnames need ----------------------------------------------

func test_the_message_keeps_the_width_the_scene_gave_it() -> void:
	var from_the_scene: float = popup.default_content_min_width
	assert_gt(from_the_scene, 0.0, "the card sizes its message")
	assert_eq(popup.content_label.custom_minimum_size.x, from_the_scene)


func test_a_notice_can_ask_for_more_room_and_give_it_back() -> void:
	popup.content_min_width = 1700.0
	assert_eq(popup.content_label.custom_minimum_size.x, 1700.0)
	popup.content_min_width = 0.0
	assert_eq(popup.content_label.custom_minimum_size.x, popup.default_content_min_width,
		"the next message gets the card back the shape it was")


func test_the_domains_are_never_split_in_the_notice() -> void:
	# What the width is for. Split across two lines a hostname is no use to the
	# person the notice is written for, and this one broke at "s3.eu-".
	popup.content_text = "DOWNLOAD_KALULU_BLOCKED"
	popup.content_min_width = PackageDownloader.BLOCKED_CONTENT_WIDTH
	popup.show()
	await get_tree().process_frame
	await get_tree().process_frame

	var label: Label = popup.content_label
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var available: float = label.get_global_rect().size.x
	for line: String in tr("DOWNLOAD_KALULU_BLOCKED").split("\n"):
		if not line.begins_with("•"):
			continue
		var needed: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(needed, available,
			"\"%s\" needs %d px and the notice offers %d" % [line, needed, available])


# --- What the downloader hands it ---------------------------------------------

func test_only_the_failures_somebody_else_can_fix_are_worth_copying() -> void:
	# A pack that will not extract is this device's own problem; mailing it to a
	# network administrator sends the reader down a corridor for nothing.
	for error: PackageDownloader.DownloadError in [PackageDownloader.DownloadError.KALULU_BLOCKED,
			PackageDownloader.DownloadError.NO_INTERNET,
			PackageDownloader.DownloadError.DOWNLOAD_FAILED]:
		assert_true(error in PackageDownloader.REPORTABLE_ERRORS,
			"%s is worth handing on" % PackageDownloader.DownloadError.keys()[error])
	for error: PackageDownloader.DownloadError in [PackageDownloader.DownloadError.DISCONNECTED,
			PackageDownloader.DownloadError.INVALID_LOCAL_PACK,
			PackageDownloader.DownloadError.EXTRACTION_FAILED,
			PackageDownloader.DownloadError.INVALID_PACKAGE,
			PackageDownloader.DownloadError.REPLACE_FAILED]:
		assert_false(error in PackageDownloader.REPORTABLE_ERRORS,
			"%s is this device's own" % PackageDownloader.DownloadError.keys()[error])


func test_a_fresh_attempt_does_not_report_the_previous_one_s_failure() -> void:
	# Every retry comes back through _start, which calls this. The leg that gets an
	# unusable answer from the server sets no result code of its own -- the request
	# succeeded and an HTTP 500 came back -- so a code left over from the attempt
	# before would be pasted under a message about the server, and sent to a network
	# administrator to chase a connection that was working.
	var downloader: PackageDownloader = autofree(PackageDownloader.new()) as PackageDownloader
	downloader.error_popup = popup
	downloader.failure_result_code = HTTPRequest.RESULT_CANT_CONNECT
	popup.title_text = "SERVER_UNAVAILABLE_TITLE"
	popup.content_text = "NO_LANGUAGE_PACK_SERVER_ERROR"

	downloader._forget_the_previous_failure()

	var report: String = downloader._report_for(PackageDownloader.DownloadError.DOWNLOAD_FAILED)
	assert_false(report.contains("RESULT_CANT_CONNECT"),
		"the previous attempt's failure has no place in this one's report")
	assert_false(report.contains("RESULT_"),
		"and nothing failed below HTTP this time, so no result line at all")
	assert_string_contains(report, tr("NO_LANGUAGE_PACK_SERVER_ERROR"),
		"what was on screen is still what is sent")


func test_the_report_is_what_was_on_screen_plus_what_its_reader_asks() -> void:
	# Read off the dialog rather than rebuilt, so nobody can be sent a message that
	# was never shown. The heading goes first: four words saying what this is about.
	var downloader: PackageDownloader = autofree(PackageDownloader.new()) as PackageDownloader
	downloader.error_popup = popup
	downloader.failure_result_code = HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR
	popup.title_text = "KALULU_BLOCKED_TITLE"
	popup.content_text = "DOWNLOAD_KALULU_BLOCKED"

	var report: String = downloader._report_for(PackageDownloader.DownloadError.KALULU_BLOCKED)
	assert_true(report.begins_with(tr("KALULU_BLOCKED_TITLE")), "the heading leads")
	assert_string_contains(report, tr("DOWNLOAD_KALULU_BLOCKED"), "then what was read")
	assert_string_contains(report, "kalulu-app-language-packs.s3.eu-west-3.amazonaws.com",
		"the domains have to survive the copy")
	assert_string_contains(report, Utils.get_application_version_with_code(), "which build")
	assert_string_contains(report, "RESULT_TLS_HANDSHAKE_ERROR",
		"and what failed -- this one says intercepted, not merely dropped")

extends GutTest
## What the downloader does with its extraction worker when an attempt fails.
##
## The worker is a Thread, and a Thread that is let go of without being joined makes
## the engine complain -- "A Thread object is being destroyed without its completion
## having been realized" -- and leaks until the process ends. Trying again starts a
## fresh download, which replaces the reference, so the old one has to be let go of
## properly first.
##
## Built without the scene: PackageDownloader._ready starts a real download, which is
## not something a test should set off. These reach the two functions directly, on a
## bare instance holding only what they touch -- which is why the join is covered on
## the function that does it rather than through _retry(), whose other half goes
## straight to the network.

var downloader: PackageDownloader
var keep_working: bool = false


func before_each() -> void:
	downloader = PackageDownloader.new()


func after_each() -> void:
	keep_working = false
	if downloader.thread:
		downloader.thread.wait_to_finish()
		downloader.thread = null
	downloader.free()


func _noop() -> void:
	pass


func _work_until_released() -> void:
	while keep_working:
		OS.delay_msec(5)


## A worker that has run and returned, but has not been joined.
func _finished_worker() -> Thread:
	var worker: Thread = Thread.new()
	worker.start(_noop)
	while worker.is_alive():
		await get_tree().process_frame
	return worker


func test_a_finished_worker_is_joined_and_let_go_of() -> void:
	# Held here as well, so it can still be asked whether it was joined after the
	# downloader has let go of it. is_started() is what tells the two apart: dropping
	# the reference alone leaves it true, and the engine warns and leaks.
	var worker: Thread = await _finished_worker()
	downloader.thread = worker

	downloader._release_extraction_thread()

	assert_false(worker.is_started(), "the worker should be joined, not merely dropped")
	assert_null(downloader.thread, "and the downloader should no longer hold it")


func test_letting_go_of_nothing_is_allowed() -> void:
	# It runs on the way out of the scene too, which can happen before any download.
	downloader._release_extraction_thread()

	assert_null(downloader.thread)


func test_trying_again_during_an_extraction_leaves_something_to_press() -> void:
	# It used to return in silence. The dialog had already closed itself, so on a
	# device with no usable pack -- where trying again is the only way forward --
	# that left a screen with nothing on it to press.
	var popup: ConfirmPopup = (load("res://sources/ui/popup.tscn") as PackedScene).instantiate()
	add_child_autofree(popup)
	popup.hide()
	downloader.error_popup = popup
	keep_working = true
	downloader.thread = Thread.new()
	downloader.thread.start(_work_until_released)

	downloader._retry()

	assert_true(popup.visible, "the notice should be back up, offering another go")
	assert_true(downloader.thread.is_alive(), "and the extraction should be left running")

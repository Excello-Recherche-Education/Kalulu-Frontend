extends GutTest

# Regression test for the fresh-install flow. Wiping user:// removes the language
# pack too, so the synchronization requested at teacher login cannot run yet: the
# progression the server returns is only readable against the pack's lesson
# count. synchronize() must then flag itself as postponed, because that flag is
# what makes the login screen retry once the pack is installed. Without it the
# students stay at zero progression until a teacher presses Synchronize by hand.

var _saved_path: String
var _saved_is_open: bool


func before_each() -> void:
	_saved_path = Database.db.path
	_saved_is_open = Database.is_open
	Database.close()


func after_each() -> void:
	Database.db.path = _saved_path
	if _saved_is_open:
		Database.connect_to_db()


# Closing the database makes Database and the synchronizer warn on purpose.
# Acknowledge those so GUT does not report them as unexpected errors. This must
# run inside the test: GUT checks for unhandled errors before after_each().
func _accept_missing_database_warnings() -> void:
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_synchronization_is_postponed_while_the_database_is_closed() -> void:
	var synchronizer: UserDatabaseSynchronizer = autofree(UserDatabaseSynchronizer.new())
	# synchronize() returns at the guard, before its first await.
	synchronizer.synchronize()
	assert_true(synchronizer.postponed, "a postponed synchronization must be flagged for retry")
	assert_false(synchronizer.synchronizing, "no synchronization may be in flight")
	_accept_missing_database_warnings()

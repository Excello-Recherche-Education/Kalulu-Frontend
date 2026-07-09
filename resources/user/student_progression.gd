class_name StudentProgression
extends Resource

signal progression_changed()

enum Status{
	LOCKED,
	UNLOCKED,
	COMPLETED,
}

# Timeline slot used by apply_manual_progression() to target a lesson's
# look-and-learn step (minigames use their 0-based index).
const LOOK_AND_LEARN_SLOT: int = -1

static var cached_boss_gate_lessons: Array[int] = []
static var cached_boss_gate_lessons_total: int = -1

@export var version: String = Utils.get_application_config_version()
@export var unlocks: Dictionary[int, Dictionary] = {}:
	set(value):
		unlocks = ensure_data_integrity(value)
@export var highest_boss_defeated: int = 0:
	set(value):
		highest_boss_defeated = _sanitize_highest_boss(value)
@export var boss_failure_streak: int = 0
@export var boss_blocked: bool = false
@export var last_modified: String


func _init() -> void:
	init_unlocks()


static func get_minigame_count_for_lesson(lesson_number: int) -> int:
	return Database.get_exercise_for_lesson(lesson_number).size()


# Manually moves the progression frontier from the teacher settings screen.
# The whole progression is one linear timeline of steps: for each lesson, its
# look-and-learn followed by its minigames in order. Editing any step to
# `status` rewrites the timeline so the sequential invariants always hold —
# every step before the frontier is COMPLETED, the frontier step is UNLOCKED,
# and every step after it is LOCKED:
#   status == UNLOCKED  → the frontier is this step
#   status == COMPLETED → the frontier is the next step (this and all before COMPLETED)
#   status == LOCKED    → the frontier is the previous step (this and all after LOCKED)
# `slot` is LOOK_AND_LEARN_SLOT for the look-and-learn column, otherwise the
# 0-based minigame index. The frontier is clamped, so lesson 1's look-and-learn
# can never end up LOCKED and the "everything completed" state is reachable.
static func apply_manual_progression(target_unlocks: Dictionary, lesson_number: int, slot: int, status: Status) -> void:
	var steps: Array[Dictionary] = _build_step_timeline(target_unlocks)
	var target_position: int = _find_step_position(steps, lesson_number, slot)
	if target_position < 0:
		return

	var frontier: int = target_position
	if status == Status.COMPLETED:
		frontier = target_position + 1
	elif status == Status.LOCKED:
		frontier = target_position - 1
	frontier = clampi(frontier, 0, steps.size())

	for index: int in range(steps.size()):
		var step_status: Status = Status.LOCKED
		if index < frontier:
			step_status = Status.COMPLETED
		elif index == frontier:
			step_status = Status.UNLOCKED
		_write_step_status(target_unlocks, steps[index], step_status)


# Flattens the unlocks into the ordered list of steps described above.
static func _build_step_timeline(target_unlocks: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var lesson_numbers: Array = target_unlocks.keys()
	lesson_numbers.sort()
	for lesson_number: int in lesson_numbers:
		steps.append({"lesson": lesson_number, "slot": LOOK_AND_LEARN_SLOT})
		var games: Array = target_unlocks[lesson_number]["games"]
		for game_index: int in range(games.size()):
			steps.append({"lesson": lesson_number, "slot": game_index})
	return steps


static func _find_step_position(steps: Array[Dictionary], lesson_number: int, slot: int) -> int:
	for index: int in range(steps.size()):
		if steps[index]["lesson"] == lesson_number and steps[index]["slot"] == slot:
			return index
	return -1


static func _write_step_status(target_unlocks: Dictionary, step: Dictionary, status: Status) -> void:
	var lesson_number: int = step["lesson"]
	var slot: int = step["slot"]
	if slot == LOOK_AND_LEARN_SLOT:
		target_unlocks[lesson_number]["look_and_learn"] = status
	else:
		var games: Array = target_unlocks[lesson_number]["games"]
		if slot < games.size():
			games[slot] = status


static func _build_default_lesson_unlock(lesson_number: int) -> Dictionary:
	var minigame_count: int = get_minigame_count_for_lesson(lesson_number)
	return {
		"look_and_learn": Status.LOCKED,
		"games": _make_locked_games_array(minigame_count),
		"last_duration": _make_zero_durations(minigame_count),
		"total_duration": _make_zero_durations(minigame_count),
	}


static func _make_locked_games_array(minigame_count: int) -> Array:
	var games: Array = []
	for _index: int in range(minigame_count):
		games.append(Status.LOCKED)
	return games


static func _make_zero_durations(minigame_count: int) -> PackedInt32Array:
	var durations: PackedInt32Array = PackedInt32Array()
	durations.resize(minigame_count)
	return durations


# Resizes a games status array to target_size, keeping the existing statuses for
# the slots that remain (trim surplus / pad new slots with LOCKED). Used when a
# lesson's minigame count changes so old saves don't lose progress on resize.
static func _resize_games_array(games: Array, target_size: int) -> Array:
	var resized: Array = []
	for index: int in range(target_size):
		resized.append(games[index] if index < games.size() else Status.LOCKED)
	return resized


# Same idea for the duration metrics: keep recorded times for remaining slots.
static func _resize_durations(durations: PackedInt32Array, target_size: int) -> PackedInt32Array:
	var resized: PackedInt32Array = PackedInt32Array()
	resized.resize(target_size)
	for index: int in range(mini(target_size, durations.size())):
		resized[index] = durations[index]
	return resized


# Make sure the unlocks are correct
func init_unlocks() -> void:
	if not unlocks:
		unlocks = {} # Triggers ensure_data_integrity(), that will fill the default values
	else:
		unlocks = unlocks # Force ensure_data_integrity()
	_sanitize_boss_progression()

	# Verify the lessons
	var number_of_lessons: int = Database.get_lessons_count()
	if unlocks.size() != number_of_lessons:
		for index: int in range(number_of_lessons):
			if not unlocks.has(index+1):
				unlocks[index + 1] = _build_default_lesson_unlock(index + 1)
		
	# Make sure that the first garden is always accessible
	if unlocks.has(1):
		if unlocks[1]["look_and_learn"] == Status.LOCKED:
			unlocks[1]["look_and_learn"] = Status.UNLOCKED
	_sanitize_boss_progression()


func ensure_data_integrity(data: Dictionary[int, Dictionary]) -> Dictionary:
	var is_init: bool = data.is_empty()
	var result: Dictionary[int, Dictionary] = data.duplicate(true)
	var number_of_lessons: int = Database.get_lessons_count()
	# Check for extra keys
	for key: int in result.keys():
		if key > number_of_lessons:
			result.erase(key)
	# Check missing keys
	var min_key: int = 1
	var max_key: int = number_of_lessons
	for index: int in range(min_key, max_key + 1):
		if not result.has(index):
			if not is_init:
				Log.warn("StudentProgression: Garden %d missing → added with default values." % index)
			result[index] = _build_default_lesson_unlock(index)
	# Check internal structure
	for index: int in result.keys():
		var garden: Dictionary = result[index]
		var minigame_count: int = get_minigame_count_for_lesson(index)
		# Check missing keys
		if not garden.has("games"):
			if not is_init:
				Log.warn("StudentProgression: Garden %d: Add missing key 'games'." % index)
			garden["games"] = _make_locked_games_array(minigame_count)
		if not garden.has("look_and_learn"):
			if not is_init:
				Log.warn("StudentProgression: Garden %d: Add missing key 'look_and_learn'." % index)
			garden["look_and_learn"] = Status.LOCKED
		if not garden.has("last_duration"):
			garden["last_duration"] = _make_zero_durations(minigame_count)
		if not garden.has("total_duration"):
			garden["total_duration"] = _make_zero_durations(minigame_count)

		# Check array "games": a corrupt (non-array) value is reset, but a size
		# mismatch (the lesson's minigame count changed) is resized in place so we
		# keep existing progress for the slots that remain instead of wiping it.
		if typeof(garden["games"]) != TYPE_ARRAY:
			if not is_init:
				Log.warn("StudentProgression: Garden %d: invalid format for 'games' → reset." % index)
			garden["games"] = _make_locked_games_array(minigame_count)
		elif (garden["games"] as Array).size() != minigame_count:
			if not is_init:
				Log.info("StudentProgression: Garden %d: 'games' resized from %d to %d, progress preserved." % [index, (garden["games"] as Array).size(), minigame_count])
			garden["games"] = _resize_games_array(garden["games"] as Array, minigame_count)

		# Keep duration metrics aligned with the minigame count, preserving the
		# recorded times for the slots that remain.
		if (garden["last_duration"] as PackedInt32Array).size() != minigame_count:
			garden["last_duration"] = _resize_durations(garden["last_duration"] as PackedInt32Array, minigame_count)
		if (garden["total_duration"] as PackedInt32Array).size() != minigame_count:
			garden["total_duration"] = _resize_durations(garden["total_duration"] as PackedInt32Array, minigame_count)

		# Check value outside of possible enum values
		for game_index: int in range((garden["games"] as Array).size()):
			if garden["games"][game_index] not in [Status.LOCKED, Status.UNLOCKED, Status.COMPLETED]:
				garden["games"][game_index] = Status.LOCKED
		if garden["look_and_learn"] not in [Status.LOCKED, Status.UNLOCKED, Status.COMPLETED]:
			garden["look_and_learn"] = Status.LOCKED

	# Check progression rules
	for index: int in range(min_key, max_key + 1):
		var garden: Dictionary = result[index]
		var prev_completed: bool = false

		# Check previous garden is completed
		if result.has(index - 1):
			var prev: Dictionary = result[index - 1]
			prev_completed = (
				prev["look_and_learn"] == Status.COMPLETED and
				(prev["games"] as Array).all(func(x: int) -> bool: return x == Status.COMPLETED)
			)
		else:
			# First garden (key 1) is always unlocked
			prev_completed = true

		var minigame_count: int = (garden["games"] as Array).size()

		# Case: previous garden not completed
		if not prev_completed:
			var needs_reset: bool = garden["look_and_learn"] != Status.LOCKED
			if not needs_reset:
				for game_index: int in range(minigame_count):
					if garden["games"][game_index] != Status.LOCKED:
						needs_reset = true
						break
			if needs_reset:
				if not is_init:
					Log.warn("StudentProgression: Garden %d: invalid progression (previous not finished) → reset." % index)
				garden["games"] = _make_locked_games_array(minigame_count)
				garden["look_and_learn"] = Status.LOCKED
			continue

		# Enforce sequential unlock: first non-COMPLETED game → UNLOCKED, everything
		# after it → LOCKED (including out-of-order COMPLETED in old saves).
		if garden["look_and_learn"] == Status.COMPLETED:
			var next_to_play: int = -1
			for game_index: int in range(minigame_count):
				if garden["games"][game_index] != Status.COMPLETED:
					next_to_play = game_index
					break
			if next_to_play >= 0:
				if garden["games"][next_to_play] == Status.LOCKED:
					garden["games"][next_to_play] = Status.UNLOCKED
					if not is_init:
						Log.warn("StudentProgression: Garden %d: minigame %d unlocked because it is next to play" % [index, next_to_play])
				for game_index: int in range(next_to_play + 1, minigame_count):
					if garden["games"][game_index] != Status.LOCKED:
						var was_completed: bool = garden["games"][game_index] == Status.COMPLETED
						garden["games"][game_index] = Status.LOCKED
						if not is_init:
							if was_completed:
								Log.warn("StudentProgression: Garden %d: minigame %d demoted from COMPLETED to LOCKED (out of play order — minigame %d not yet completed)" % [index, game_index, next_to_play])
							else:
								Log.info("StudentProgression: Garden %d: minigame %d re-locked (waits for minigame %d to be completed)" % [index, game_index, game_index - 1])
		else:
			# L&L not completed → no game may be UNLOCKED (COMPLETED preserved).
			for game_index: int in range(minigame_count):
				if garden["games"][game_index] == Status.UNLOCKED:
					garden["games"][game_index] = Status.LOCKED
					if not is_init:
						Log.warn("StudentProgression: Garden %d: minigame %d re-locked (look-and-learn not completed)" % [index, game_index])
			# Case: previous garden completed → unlock lesson if needed
			if garden["look_and_learn"] == Status.LOCKED:
				garden["look_and_learn"] = Status.UNLOCKED
				if not is_init:
					Log.warn("StudentProgression: Garden %d: lesson unlocked because previous garden is completed" % index)

	_sanitize_boss_progression()
	return result


static func get_boss_gate_lessons() -> Array[int]:
	var total_lessons: int = Database.get_lessons_count()
	if cached_boss_gate_lessons_total == total_lessons:
		return cached_boss_gate_lessons.duplicate()
	var gates: Array[int] = []
	if total_lessons <= 0:
		return gates
	var boundary_lessons: Array[int] = _get_garden_boundary_lessons(total_lessons)
	var last_boss_pseudowords: int = 0
	for lesson_number: int in range(1, total_lessons + 1):
		var total_pseudowords: int = Database.get_pseudowords_for_lesson(lesson_number).size()
		var new_pseudowords: int = total_pseudowords - last_boss_pseudowords
		if new_pseudowords >= 30 and boundary_lessons.has(lesson_number):
			gates.append(lesson_number)
			last_boss_pseudowords = total_pseudowords
	cached_boss_gate_lessons_total = total_lessons
	cached_boss_gate_lessons = gates.duplicate()
	return gates


static func _get_garden_boundary_lessons(total_lessons: int) -> Array[int]:
	var boundaries: Array[int] = []
	var distribution: Array[int] = Gardens.compute_lessons_distribution(total_lessons)
	var lesson_index: int = 0
	for count: int in distribution:
		if count <= 0:
			continue
		lesson_index += count
		if lesson_index < total_lessons:
			boundaries.append(lesson_index)
	return boundaries


func _sanitize_boss_progression() -> void:
	highest_boss_defeated = _sanitize_highest_boss(highest_boss_defeated)


func _sanitize_highest_boss(value: int) -> int:
	# The final boss is not a gate lesson; beating it is recorded as (lessons count + 1).
	# Allow that marker through instead of clamping it down to the last gate.
	var final_boss_value: int = Database.get_lessons_count() + 1
	if value >= final_boss_value:
		return final_boss_value
	var gate_lessons: Array[int] = get_boss_gate_lessons()
	if gate_lessons.is_empty():
		return 0
	gate_lessons.sort()
	var sanitized: int = 0
	for gate_lesson: int in gate_lessons:
		if gate_lesson <= value:
			sanitized = gate_lesson
		else:
			break
	return sanitized


func is_boss_completed(gate_lesson: int) -> bool:
	if not get_boss_gate_lessons().has(gate_lesson):
		return false
	return gate_lesson <= highest_boss_defeated


# True once the final boss has been beaten — recorded by pushing highest_boss_defeated
# one past the last lesson (see final_boss_completed()).
func is_final_boss_completed() -> bool:
	return highest_boss_defeated >= Database.get_lessons_count() + 1


func is_lesson_blocked_by_boss(lesson_number: int) -> bool:
	var gate_lessons: Array[int] = get_boss_gate_lessons()
	gate_lessons.sort()
	for gate: int in gate_lessons:
		if gate >= lesson_number:
			break
		if gate > highest_boss_defeated:
			return true
	return false


func get_max_unlocked_lesson_index() -> int:
	var max_unlocked_level: int = 1
	for index: int in range(unlocks.size()):
		if is_lesson_blocked_by_boss(index + 1):
			break
		if unlocks[index + 1]["look_and_learn"] >= Status.UNLOCKED:
			max_unlocked_level = index
		else:
			break
	
	return max_unlocked_level


func is_lesson_completed(lesson_number: int) -> bool:
	if unlocks[lesson_number]["look_and_learn"] != Status.COMPLETED:
		return false
	for game_status: int in unlocks[lesson_number]["games"]:
		if game_status != Status.COMPLETED:
			return false
	return true


# Return true if the progression is saved or false if the look and learn was already completed
func look_and_learn_completed(lesson_number: int) -> bool:
	if unlocks[lesson_number]["look_and_learn"] == Status.COMPLETED:
		return false

	unlocks[lesson_number]["look_and_learn"] = Status.COMPLETED

	var games: Array = unlocks[lesson_number]["games"]
	if games.size() > 0 and games[0] == Status.LOCKED:
		games[0] = Status.UNLOCKED

	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


# Return true if the progression is saved or false if the game was already completed
func game_completed(lesson_number: int, game_number: int) -> bool:
	var games: Array = unlocks[lesson_number]["games"]

	if games[game_number] == Status.COMPLETED:
		return false

	games[game_number] = Status.COMPLETED

	var next_game_index: int = game_number + 1
	if next_game_index < games.size() and games[next_game_index] == Status.LOCKED:
		games[next_game_index] = Status.UNLOCKED

	var all_completed: bool = true
	for game_status: int in games:
		if game_status != Status.COMPLETED:
			all_completed = false
			break

	if all_completed:
		if unlocks.has(lesson_number + 1):
			unlocks[lesson_number + 1]["look_and_learn"] = Status.UNLOCKED

	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


func boss_completed(lesson_number: int) -> bool:
	if not get_boss_gate_lessons().has(lesson_number):
		return false
	if lesson_number <= highest_boss_defeated:
		return false
	highest_boss_defeated = lesson_number
	if boss_failure_streak != 0:
		boss_failure_streak = 0
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


# Records the final-boss victory by pushing highest_boss_defeated one past the last
# lesson (the final boss is not a gate lesson), reusing the existing field instead of a
# dedicated flag.
func final_boss_completed() -> bool:
	var final_boss_value: int = Database.get_lessons_count() + 1
	if highest_boss_defeated >= final_boss_value:
		return false
	highest_boss_defeated = final_boss_value
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return true


func register_boss_failure() -> bool:
	if boss_blocked:
		return true
	boss_failure_streak = max(0, boss_failure_streak) + 1
	if boss_failure_streak >= 2:
		boss_blocked = true
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()
	return boss_blocked


func reset_boss_failure_streak() -> void:
	if boss_failure_streak == 0:
		return
	boss_failure_streak = 0
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()


func clear_boss_block() -> void:
	if not boss_blocked and boss_failure_streak == 0:
		return
	boss_blocked = false
	boss_failure_streak = 0
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()


func add_level_time(lesson_number: int, game_number: int, time_spent: int) -> void:
	Log.trace("StudentProgression: Add time to level %d, minigame %d. Time added: %s" % [lesson_number, game_number, time_spent])
	if not unlocks.has(lesson_number):
		Log.error("StudentProgression: Cannot log a level time for lesson %d because it does not exists in progression data" % lesson_number)
		return

	var minigame_count: int = (unlocks[lesson_number]["games"] as Array).size()
	if game_number < 0 or game_number >= minigame_count:
		Log.error("StudentProgression: Cannot log a level time for minigame %d in lesson %d (lesson has %d minigame(s))" % [game_number, lesson_number, minigame_count])
		return
	
	if not (unlocks[lesson_number] as Dictionary).has("last_duration") or not (unlocks[lesson_number]["last_duration"] as PackedInt32Array).size() > game_number:
		Log.error("StudentProgression: Cannot log a last_duration for lesson %d, game %d, because it does not exists" % [lesson_number, game_number])
	else:
		unlocks[lesson_number]["last_duration"][game_number] = time_spent
	
	if not (unlocks[lesson_number] as Dictionary).has("total_duration") or not (unlocks[lesson_number]["total_duration"] as PackedInt32Array).size() > game_number:
		Log.error("StudentProgression: Cannot log a total_duration for lesson %d, game %d, because it does not exists" % [lesson_number, game_number])
	else:
		unlocks[lesson_number]["total_duration"][game_number] += time_spent
	
	last_modified = Time.get_datetime_string_from_system(true)
	progression_changed.emit()

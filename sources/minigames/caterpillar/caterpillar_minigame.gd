@tool
extends HearAndSequentialsStepsMinigame
class_name CaterpillarMinigame


const branch_scene: = preload("res://sources/minigames/caterpillar/branch.tscn")


class DifficultySettings:
	var branches: = 2
	var stimuli_ratio: = 0.75
	var velocity: = 400.
	var spawn_rate: = 3.
	
	func _init(p_branches: int, p_stimuli_ratio: float, p_velocity: float, p_spawn_rate: float) -> void:
		branches = p_branches
		stimuli_ratio = p_stimuli_ratio
		velocity = p_velocity
		spawn_rate = p_spawn_rate


var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(2, 0.75, 400., 3.),
	DifficultySettings.new(2, 0.66, 450., 2.5),
	DifficultySettings.new(3, 0.33, 500., 2.),
	DifficultySettings.new(3, 0.25, 550., 1.),
	DifficultySettings.new(4, 0.25, 600., 1.)
]


@onready var branches_zone: Control = $GameRoot/BranchesZone
@onready var caterpillar: Caterpillar = $GameRoot/Caterpillar
@onready var berry_timer: Timer = $GameRoot/BerryTimer


var branches: Array[Branch] = []
var branches_spawn_indexes: Array[int] = []

func _setup_minigame() -> void:
	super._setup_minigame()
	
	# Gets the difficulty settings
	var settings: DifficultySettings = difficulty_settings[difficulty]
	if not settings:
		return
	
	# Spawn the right amount of branches
	var branch_size: float = branches_zone.size.y / (settings.branches + 1)
	for i: int in settings.branches:
		var branch: Branch = branch_scene.instantiate()
		branch.velocity = settings.velocity
		branches_zone.add_child(branch)
		# branch.set_size(Vector2(branch.size.x, branch_size))
		branch.set_position(Vector2(0, branch_size * (i+1)))
		
		if not Engine.is_editor_hint():
			branch.branch_pressed.connect(_on_branch_pressed.bind(branch))
			
		
		branches.append(branch)
		branches_spawn_indexes.append(i)
	
		# Move the caterpillar to the right branch
		@warning_ignore("integer_division")
		if i == int(settings.branches/2):
			_on_branch_pressed(branch)
	
	# Setups the timer
	berry_timer.wait_time = settings.spawn_rate
	
	# Connects the caterpillar signals
	caterpillar.berry_eaten.connect(_on_berry_eaten)


func _start() -> void:
	super._start()
	berry_timer.start()


func _get_difficulty_settings() -> DifficultySettings:
	return difficulty_settings[difficulty]


# -------------- CONNECTIONS -------------- #


func _on_branch_pressed(branch: Branch) -> void:
	caterpillar.move(branch.global_position.y)


func _on_berry_timer_timeout() -> void:
	# Pick a random branch to spawn a berry but not the same one twice
	var index: int = branches_spawn_indexes[randi() % (branches_spawn_indexes.size() -1)]
	branches_spawn_indexes.erase(index)
	branches_spawn_indexes.push_back(index)
	var branch: Branch = branches[index]
	
	# Define if the berry is a stimulus or a distraction
	var gp: Dictionary
	var is_stimulus: = randf() < _get_difficulty_settings().stimuli_ratio
	if is_stimulus:
		gp = _get_GP()
	else:
		gp = _get_distractor()
	
	# Spawn the berry
	branch.spawn_berry(gp)


func _on_berry_eaten(berry: Berry) -> void:
	if _is_GP_right(berry.gp):
		await caterpillar.eat_berry(berry)
		current_word_progression += 1
	else:
		await caterpillar.spit_berry(berry)
		current_lives -= 1


func _on_current_word_progression_changed() -> void:
	# Clean old berries
	for branch: Branch in branches:
		branch.clear_berries()


func _on_current_progression_changed() -> void:
		# Reset the caterpillar
	await caterpillar.reset()
	# Play the new stimulus
	super()


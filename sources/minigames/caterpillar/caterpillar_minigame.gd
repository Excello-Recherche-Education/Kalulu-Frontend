@tool
extends HearAndSequentialsStepsMinigame
class_name CaterpillarMinigame

const branch_scene: = preload("res://sources/minigames/caterpillar/branch.tscn")

class DifficultySettings:
	var rows: = 2
	var stimuli_ratio: = 0.75
	var velocity: = 150
	
	func _init(p_rows: int, p_stimuli_ratio: float, p_velocity: int) -> void:
		rows = p_rows
		stimuli_ratio = p_stimuli_ratio
		velocity = p_velocity

var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(1, 0.75, 150),
	DifficultySettings.new(2, 0.66, 175),
	DifficultySettings.new(3, 0.33, 200),
	DifficultySettings.new(4, 0.25, 250),
	DifficultySettings.new(5, 0.25, 300)
]

@onready var branches_zone: Control = $GameRoot/BranchesZone
@onready var caterpillar: Caterpillar = $GameRoot/Caterpillar


var branches: Array[Branch] = []
var current_branch_index: int

func _setup_minigame() -> void:
	super._setup_minigame()
	
	# Gets the difficulty settings
	var settings: DifficultySettings = difficulty_settings[difficulty]
	if not settings:
		return
	
	current_branch_index = int(settings.rows/2)
	
	# Spawn the right amount of branches
	var branch_size: float = branches_zone.size.y / (settings.rows + 1)
	for i: int in settings.rows:
		var branch: Branch = branch_scene.instantiate()
		branches_zone.add_child(branch)
		# branch.set_size(Vector2(branch.size.x, branch_size))
		branch.set_position(Vector2(0, branch_size * (i+1)))
		
		if not Engine.is_editor_hint():
			branch.branch_pressed.connect(_on_branch_pressed.bind(branch))
		
		branches.append(branch)
	
		# Move the caterpillar to the right branch
		if i == current_branch_index:
			_on_branch_pressed(branch)


# -------------- CONNECTIONS -------------- #


func _on_branch_pressed(branch: Branch):
	caterpillar.move(branch.global_position.y)

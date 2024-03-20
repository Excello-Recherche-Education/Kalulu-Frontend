@tool
extends HearAndSequentialsStepsMinigame
class_name CaterpillarMinigame

class DifficultySettings:
	var rows: = 2
	var stimuli_ratio: = 0.75
	var velocity: = 150
	
	func _init(p_rows: int, p_stimuli_ratio: float, p_velocity: int) -> void:
		rows = p_rows
		stimuli_ratio = p_stimuli_ratio
		velocity = p_velocity

var difficulty_settings: Array[DifficultySettings] = [
	DifficultySettings.new(2, 0.75, 150),
	DifficultySettings.new(3, 0.66, 175),
	DifficultySettings.new(3, 0.33, 200),
	DifficultySettings.new(4, 0.25, 250),
	DifficultySettings.new(4, 0.25, 300)
]


func _setup_minigame() -> void:
	super._setup_minigame()

extends Node2D
class_name LetterSegment

signal finished()

@onready var tracing_path: = $TracingPath
@onready var tracing_effects: = $TracingEffects
@onready var complete_particles: = $CompleteParticles
@onready var complete_sound: = $CompleteAudioStreamPlayer


func _ready() -> void:
	complete_sound.stop()
	complete_particles.emitting = false


func setup(points: Array) -> void:
	tracing_path.setup(points)


func start() -> void:
	tracing_path.start()


func stop() -> void:
	finished.emit()

func demo() -> void:
	tracing_path.demo()


func _process(_delta: float) -> void:
	tracing_path.global_position = global_position
	tracing_effects.global_position = tracing_path.guide.global_position
	tracing_effects.set_pitch_scale(1.0 + tracing_path.guide.progress_ratio)
	
	if tracing_path.should_play_effects:
		tracing_effects.play()
	else:
		tracing_effects.stop()


func _on_CompleteAudioStreamPlayer_finished() -> void:
	tracing_effects.stop()
	complete_particles.emitting = false
	finished.emit()


func _on_tracing_path_finished() -> void:
	tracing_effects.stop()
	complete_sound.play()
	complete_particles.emitting = true


func _on_tracing_path_demo_finished() -> void:
	stop()

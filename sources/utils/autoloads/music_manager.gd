extends Node

@onready var music_player : AudioStreamPlayer = $MusicPlayer

const tracks: Array = [
	preload("res://assets/music/title.mp3"),
	preload("res://assets/music/garden.mp3")
]

enum Track {
	Title,
	Garden
}

func _ready() -> void:
	play(Track.Title)

func _on_music_player_finished() -> void:
	music_player.stream_paused = false
	music_player.play()

func play(track : Track) -> void:
	music_player.stream = tracks[track]
	music_player.play()

func stop() -> void:
	music_player.stop()

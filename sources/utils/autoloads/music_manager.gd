class_name MusicManagerClass
extends Node

enum Track {
	Title,
	Garden
}

const TRACKS: Array = [
	preload("res://assets/music/title.mp3"),
	preload("res://assets/music/garden.mp3")
]

@onready var music_player: AudioStreamPlayer = $MusicPlayer


func _ready() -> void:
	Log.trace("MusicManager: Ready - starting title track")
	play(Track.Title)


func _on_music_player_finished() -> void:
	Log.trace("MusicManager: Track finished - restarting current stream")
	music_player.stream_paused = false
	music_player.play()


func play(track: Track) -> void:
	Log.trace("MusicManager: Requested play for track \"%s\"" % str(Track.keys()[track]))
	music_player.stream = TRACKS[track]
	music_player.play()


func stop() -> void:
	music_player.stop()

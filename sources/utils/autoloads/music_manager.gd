class_name MusicManagerClass
extends Node

enum Track {
	TITLE,
	GARDEN
}

## Paths rather than preloads: an autoload's preloads are read before the first
## frame, so preloading the garden track put it on every cold start although it
## is only heard once a child reaches the gardens. Each track is loaded the first
## time it is played and kept from then on.
const TRACKS: Array[String] = [
	"res://assets/music/title.mp3",
	"res://assets/music/garden.mp3"
]

var _loaded_streams: Dictionary[Track, AudioStream] = {}
## Set by play() and stop(), so the title track started after the first frame does
## not override a scene that has already decided what should be heard.
var _has_been_told_what_to_play: bool = false

@onready var music_player: AudioStreamPlayer = $MusicPlayer


func _ready() -> void:
	# Every autoload's _ready runs before the first frame, which Android counts in
	# the cold start, and starting the title track loads it from disk. Nothing on
	# the first frame needs it, so it starts once that frame is on screen.
	await RenderingServer.frame_post_draw
	if _has_been_told_what_to_play:
		Log.trace("MusicManager: Ready - title track skipped, a scene already chose the music")
		return
	Log.trace("MusicManager: Ready - starting title track")
	play(Track.TITLE)


func _on_music_player_finished() -> void:
	Log.trace("MusicManager: Track finished - restarting current stream")
	music_player.stream_paused = false
	music_player.play()


func play(track: Track) -> void:
	_has_been_told_what_to_play = true
	if track < 0 or track >= Track.size():
		Log.warn("MusicManager: Cannot play %d because this key is out of Track range" % track)
		return
	Log.trace("MusicManager: Requested play for track \"%s\"" % str(Track.keys()[track]))
	if track >= TRACKS.size():
		Log.warn("MusicManager: Cannot play %d because this key is out of TRACKS range" % track)
		return
	var stream: AudioStream = _get_stream(track)
	if stream == null:
		Log.warn("MusicManager: Cannot play %d because its stream could not be loaded" % track)
		return
	music_player.stream = stream
	music_player.play()


func stop() -> void:
	_has_been_told_what_to_play = true
	music_player.stop()


func _get_stream(track: Track) -> AudioStream:
	if not _loaded_streams.has(track):
		var stream: AudioStream = load(TRACKS[track]) as AudioStream
		if stream == null:
			return null
		_loaded_streams[track] = stream
	return _loaded_streams[track]

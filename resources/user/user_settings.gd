extends Resource
class_name UserSettings

@export var version: = 1.0

@export var master_volume: = 0.0 :
	set(volume):
		master_volume = volume
		var ind: = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(ind, volume)

@export var music_volume: = 0.0 :
	set(volume):
		music_volume = volume
		var ind: = AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(ind, volume)

@export var voice_volume: = 0.0 :
	set(volume):
		voice_volume = volume
		var ind: = AudioServer.get_bus_index("Voice")
		AudioServer.set_bus_volume_db(ind, volume)

@export var effects_volume: = 0.0 :
	set(volume):
		effects_volume = volume
		var ind: = AudioServer.get_bus_index("Effects")
		AudioServer.set_bus_volume_db(ind, volume)

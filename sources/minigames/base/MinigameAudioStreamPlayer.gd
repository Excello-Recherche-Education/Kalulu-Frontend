extends AudioStreamPlayer
class_name MinigameAudioStreamPlayer

func play_gp(gp: Dictionary) -> void:
	if not gp or gp.is_empty():
		return
	
	var phoneme_audiostream: AudioStream = Database.load_external_sound(Database.get_gp_sound_path(gp)) as AudioStream
	#var phoneme_audiostream = Database.get_gp_look_and_learn_sound(phoneme)
	if not phoneme_audiostream:
		Logger.warn("MinigameAudioStreamPlayer: AudioStream not found for gp %s " % gp)
		return
	
	stream = phoneme_audiostream
	play()
	
	if playing:
		await finished


func play_word(word: String) -> void:
	if not word:
		return
	
	stream = Database.load_external_sound(Database.get_word_sound_path({Word = word}))
	play()
	if playing:
		await finished

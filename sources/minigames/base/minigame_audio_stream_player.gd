class_name MinigameAudioStreamPlayer
extends AudioStreamPlayer


func play_gp(gp: Dictionary) -> void:
	Logger.trace("Minigame Audio Stream Player: Playing GP " + str(gp))
	if not gp or gp.is_empty():
		return
	
	var phoneme_audiostream: AudioStreamMP3 = Database.load_external_sound(Database.get_gp_sound_path(gp)) as AudioStream
	if not phoneme_audiostream:
		Logger.warn("MinigameAudioStreamPlayer: AudioStream not found for gp %s " % gp)
		return
	
	await play_audio_stream(phoneme_audiostream)


func play_syllable(syllable: Dictionary) -> void:
	Logger.trace("Minigame Audio Stream Player: Playing Syllable " + str(syllable))
	if not syllable or syllable.is_empty():
		return
	
	var syllable_audiostream: AudioStreamMP3 = Database.load_external_sound(Database.get_syllable_sound_path(syllable))
	if not syllable_audiostream:
		Logger.warn("MinigameAudioStreamPlayer: AudioStream not found for syllable %s " % syllable)
		return
	await play_audio_stream(syllable_audiostream)


func play_word(word: String) -> void:
	Logger.trace("Minigame Audio Stream Player: Playing Word " + str(word))
	if not word or word.is_empty():
		return
	
	var word_audiostream: AudioStreamMP3 = Database.load_external_sound(Database.get_word_sound_path({Word = word}))
	if not word_audiostream:
		Logger.warn("MinigameAudioStreamPlayer: AudioStream not found for word %s " % word)
		return
	
	await play_audio_stream(word_audiostream)


func play_audio_stream(audio: AudioStreamMP3) -> void:
	stream = audio
	play()
	if not audio.loop:
		await get_tree().create_timer(audio.get_length() + 0.25).timeout

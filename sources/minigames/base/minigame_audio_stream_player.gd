class_name MinigameAudioStreamPlayer
extends AudioStreamPlayer


func play_gp(gp: Dictionary) -> void:
	Log.trace("MinigameAudioStreamPlayer: Playing GP " + str(gp))
	if not gp or gp.is_empty():
		return
	
	# Through the resolver, not get_gp_sound_path: a pack downloaded before the
	# file names were encoded still holds the old ones. See Database.resolve_gp_asset_path.
	var path: String = Database.resolve_gp_asset_path(gp, Database.LANGUAGE_SOUNDS, Database.SOUND_EXTENSION)
	if path.is_empty():
		Log.warn("MinigameAudioStreamPlayer: AudioStream not found for gp %s " % gp)
		return
	
	var phoneme_audiostream: AudioStreamMP3 = Database.load_external_sound(path)
	if not phoneme_audiostream:
		Log.warn("MinigameAudioStreamPlayer: AudioStream not found for gp %s " % gp)
		return
	
	await play_audio_stream(phoneme_audiostream)


func play_syllable(syllable: Dictionary) -> void:
	Log.trace("MinigameAudioStreamPlayer: Playing Syllable " + str(syllable))
	if not syllable or syllable.is_empty():
		return
	
	# Through the ladder: a pack installed before the file names were encoded still
	# holds the raw name. See Database.resolve_sound_path.
	var syllable_audiostream: AudioStreamMP3 = Database.load_external_sound(
			Database.resolve_syllable_sound_path(syllable))
	if not syllable_audiostream:
		Log.warn("MinigameAudioStreamPlayer: AudioStream not found for syllable %s " % syllable)
		return
	await play_audio_stream(syllable_audiostream)


func play_word(word: String) -> void:
	Log.trace("MinigameAudioStreamPlayer: Playing Word " + str(word))
	if not word or word.is_empty():
		return
	
	# Through the ladder, for the reason in play_syllable.
	var word_audiostream: AudioStreamMP3 = Database.load_external_sound(
			Database.resolve_word_sound_path({Word = word}))
	if not word_audiostream:
		Log.warn("MinigameAudioStreamPlayer: AudioStream not found for word %s " % word)
		return
	
	await play_audio_stream(word_audiostream)


func play_audio_stream(audio: AudioStreamMP3) -> void:
	stream = audio
	play()
	if not audio.loop:
		await get_tree().create_timer(audio.get_length() + 0.25, false).timeout

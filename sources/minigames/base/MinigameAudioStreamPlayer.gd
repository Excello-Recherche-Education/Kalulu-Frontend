extends AudioStreamPlayer
class_name MinigameAudioStreamPlayer

func play_phoneme(phoneme: String) -> void:
	if not phoneme:
		return
	
	var phoneme_audiostream = Database.get_audio_stream_for_phoneme(phoneme) as AudioStream
	if not phoneme_audiostream:
		push_warning("AudioStream not found for phoneme " + phoneme)
		return
	
	stream = phoneme_audiostream
	play()
	
	if playing:
		await finished


func play_word(word: String) -> void:
	if not word:
		return
	
	stream = Database.get_audio_stream_for_word(word)
	play()
	if playing:
		await finished

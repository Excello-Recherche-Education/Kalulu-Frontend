extends GPImageAndSoundDescriptions


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(Database.BASE_PATH + Database.language + Database.LANGUAGE_SOUNDS)
	
	Database.db.query("SELECT * FROM GPs WHERE GPs.Exception=0")
	for res: Dictionary in Database.db.query_result:
		var description_line: ImageAndSoundGPDescription = DESCRIPTION_LINE_SCENE.instantiate()
		description_line.get_sound_path = Database.get_gp_sound_path
		description_line.find_sound_files = Database.find_gp_asset_files.bind(
				Database.LANGUAGE_SOUNDS, Database.SOUND_EXTENSION)
		description_line.get_image_path = get_empty_string
		description_line.find_image_files = get_no_files
		description_line.hide_image_part()
		description_container.add_child(description_line)
		description_line.set_gp(res)
		description_line.image_preview.hide()
		description_line.image_upload_button.hide()
	
	Database.db.query("SELECT * FROM Syllables WHERE Syllables.Exception=0")
	for res: Dictionary in Database.db.query_result:
		var description_line: ImageAndSoundGPDescription = DESCRIPTION_LINE_SCENE.instantiate()
		description_line.get_sound_path = Database.get_syllable_sound_path
		description_line.find_sound_files = Database.find_syllable_sound_files
		description_line.get_image_path = get_empty_string
		description_line.find_image_files = get_no_files
		description_line.hide_image_part()
		description_container.add_child(description_line)
		res.Grapheme = res.Syllable
		description_line.set_gp(res)
		description_line.image_preview.hide()
		description_line.image_upload_button.hide()
	
	Database.db.query("SELECT * FROM Words WHERE Words.Exception=0")
	for res: Dictionary in Database.db.query_result:
		var description_line: ImageAndSoundGPDescription = DESCRIPTION_LINE_SCENE.instantiate()
		description_line.get_sound_path = Database.get_word_sound_path
		description_line.find_sound_files = Database.find_word_sound_files
		description_line.get_image_path = get_empty_string
		description_line.find_image_files = get_no_files
		description_line.hide_image_part()
		description_container.add_child(description_line)
		res.Grapheme = res.Word
		description_line.set_gp(res)
		description_line.image_preview.hide()
		description_line.image_upload_button.hide()


func get_empty_string(_a: Variant) -> String:
	return ""


func get_no_files(_a: Variant) -> PackedStringArray:
	return []

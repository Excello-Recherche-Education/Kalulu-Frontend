extends GPImageAndSoundDescriptions

	 

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(Database.base_path + Database.language + Database.language_sounds)
	
	Database.db.query("SELECT * FROM GPs WHERE GPs.Exception=0")
	for res in Database.db.query_result:
		var description_line: ImageAndSoundGPDescription = description_line_scene.instantiate()
		description_line.get_sound_path = Database.get_gp_sound_path
		description_line.get_image_path = get_empty_string
		description_line.hide_image_part()
		description_container.add_child(description_line)
		description_line.set_gp(res)
		description_line.image_preview.hide()
		description_line.image_upload_button.hide()
	
	Database.db.query("SELECT * FROM Syllables WHERE Syllables.Exception=0")
	for res in Database.db.query_result:
		var description_line: = description_line_scene.instantiate()
		description_line.get_sound_path = Database.get_syllable_sound_path
		description_line.get_image_path = get_empty_string
		description_line.hide_image_part()
		description_container.add_child(description_line)
		res.Grapheme = res.Syllable
		description_line.set_gp(res)
		description_line.image_preview.hide()
		description_line.image_upload_button.hide()
	
	Database.db.query("SELECT * FROM Words WHERE Words.Exception=0")
	for res in Database.db.query_result:
		var description_line: = description_line_scene.instantiate()
		description_line.get_sound_path = Database.get_word_sound_path
		description_line.get_image_path = get_empty_string
		description_line.hide_image_part()
		description_container.add_child(description_line)
		res.Grapheme = res.Word
		description_line.set_gp(res)
		description_line.image_preview.hide()
		description_line.image_upload_button.hide()


func get_empty_string(_a: Variant) -> String:
	return ""

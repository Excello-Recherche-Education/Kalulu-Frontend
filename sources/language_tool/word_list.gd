extends Control

var word_scene: = preload("res://sources/language_tool/word_list_element.tscn")

@onready var elements_container: = $%ElementsContainer
@onready var save_button: = $%SaveButton

var undo_redo: = UndoRedo.new()


func _ready() -> void:
	Database.db.query("SELECT Word, group_concat(Grapheme, ' ') as Graphemes, group_concat(Phoneme, ' ') as Phonemes
		FROM Words 
		INNER JOIN ( SELECT * FROM GPsInWords ORDER BY GPsInWords.Position ) GPsInWords ON Words.ID = GPsInWords.WordID 
		INNER JOIN GPs WHERE GPS.ID = GPsInWords.GPID 
		GROUP BY Words.ID")
	var results: = Database.db.query_result
	for e in results:
		var element: = word_scene.instantiate()
		element.word = e.Word
		element.graphemes = e.Graphemes
		element.phonemes = e.Phonemes
		elements_container.add_child(element)
		element.undo_redo = undo_redo
		element.delete_pressed.connect(_on_element_delete_pressed.bind(element))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		undo_redo.undo()
	elif event.is_action_pressed("ui_redo"):
		undo_redo.redo()


func _on_element_delete_pressed(element: Control) -> void:
	undo_redo.create_action("delete")
	undo_redo.add_do_method(elements_container.remove_child.bind(element))
	undo_redo.add_undo_method(elements_container.add_child.bind(element))
	undo_redo.add_undo_method(elements_container.move_child.bind(element, element.get_index()))
	undo_redo.commit_action()


func _on_plus_button_pressed() -> void:
	undo_redo.create_action("add")
	var element: = word_scene.instantiate()
	element.word = ""
	element.graphemes = ""
	element.undo_redo = undo_redo
	element.delete_pressed.connect(_on_element_delete_pressed.bind(element))
	undo_redo.add_do_method(elements_container.add_child.bind(element))
	undo_redo.add_do_method(elements_container.move_child.bind(element, 0))
	undo_redo.add_undo_method(elements_container.remove_child.bind(element))
	undo_redo.commit_action()
	element.edit_mode()


func _process(_delta: float) -> void:
	save_button.visible = undo_redo.has_undo()

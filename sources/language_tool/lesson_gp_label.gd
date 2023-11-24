extends Label


var grapheme: = "":
	set = set_grapheme
var phoneme: = "":
	set = set_phoneme


func set_grapheme(p_grapheme: String) -> void:
	grapheme = p_grapheme
	text = "%s-%s" % [grapheme, phoneme]


func set_phoneme(p_phoneme: String) -> void:
	phoneme = p_phoneme
	text = "%s-%s" % [grapheme, phoneme]

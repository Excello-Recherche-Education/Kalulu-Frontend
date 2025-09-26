extends Node
## NFC = Normalization Form Composed (composed form)
## -> compose whenever possible: é is stored as a single code point U+00E9.
##
## NFD = Normalization Form Decomposed (decomposed form)
## -> decompose: é becomes two code points U+0065 (e) + U+0301 (combining acute accent).
## List of well-covered languages: French, Spanish, Portuguese, Italian, German, Swedish, Finnish, Estonian, Czech, Slovak, Slovene/Slovenian, Polish, Croatian, Bosnian, Serbian Latin, Romanian, Hungarian, Lithuanian, Latvian, Albanian, Catalan, Basque, Irish / Scottish Gaelic, Welsh, Maltese, Esperanto, Norwegian, Danish, Icelandic, Faroese, Dutch
## List of OK-covered languages: Turkish => ı (dotless i) has no decomposition
## List of partially covered : Vietnamese => not all tone/diacritic combinations are listed

const _grave_accent: String			= "\u0300" #  ̀
const _acute_accent: String			= "\u0301" #  ́
const _circumflex: String			= "\u0302" #  ̂
const _tilde: String					= "\u0303" #  ̃
const _diaresis: String				= "\u0308" #  ̈
const cedilla: String				= "\u0327" # ¸
const caron: String					= "\u030C" # ˇ
const breve: String					= "\u0306" # ˘
const ring_above: String				= "\u030A" # ˚
const dot_above: String				= "\u0307" # ˙
const macron: String					= "\u0304" # ˉ
const comma_below: String			= "\u0326" #  ̦
const ogonek: String					= "\u0328" #  ̨
const double_acute: String			= "\u030B" # ˝
const dot_below: String				= "\u0323" # ̣
const hook_above: String				= "\u0309" # ̉
const horn: String					= "\u031B" # ̛
const short_stroke_overlay: String	= "\u0335" # ̵ (ø/ł/đ en NFKD)
const long_solidus_overlay: String	= "\u0338" # ̸ (Ø en NFKD)

# List is incomplete and should be updated as needed
const _MAP: Dictionary = {
	"à": "a" + _grave_accent, "á": "a" + _acute_accent, "â": "a" + _circumflex, "ã": "a" + _tilde, "ä": "a" + _diaresis, "å": "a" + ring_above, "ą": "a" + ogonek, "ā": "a" + macron, "ă": "a" + breve, "ạ": "a" + dot_below, "ả": "a" + hook_above,
	"À": "A" + _grave_accent, "Á": "A" + _acute_accent, "Â": "A" + _circumflex, "Ã": "A" + _tilde, "Ä": "A" + _diaresis, "Å": "A" + ring_above, "Ą": "A" + ogonek, "Ā": "A" + macron, "Ă": "A" + breve, "Ạ": "A" + dot_below, "Ả": "A" + hook_above,
	
	"ç": "c" + cedilla, "č": "c" + caron, "ć": "c" + _acute_accent, "ĉ": "c" + _circumflex, "ċ": "c" + dot_above, 
	"Ç": "C" + cedilla, "Č": "C" + caron, "Ć": "C" + _acute_accent, "Ĉ": "C" + _circumflex, "Ċ": "C" + dot_above,
	
	"ď": "d" + caron,
	"Ď": "D" + caron,
	
	"è": "e" + _grave_accent, "é": "e" + _acute_accent, "ê": "e" + _circumflex, "ẽ": "e" + _tilde, "ë": "e" + _diaresis, "ě": "e" + caron, "ę": "e" + ogonek, "ē": "e" + macron, "ẹ": "e" + dot_below, "ẻ": "e" + hook_above, "ė": "e" + dot_above,
	"È": "E" + _grave_accent, "É": "E" + _acute_accent, "Ê": "E" + _circumflex, "Ẽ": "E" + _tilde, "Ë": "E" + _diaresis, "Ě": "E" + caron, "Ę": "E" + ogonek, "Ē": "E" + macron, "Ẹ": "E" + dot_below, "Ẻ": "E" + hook_above, "Ė": "E" + dot_above,
	
	"ğ": "g" + breve, "ģ": "g" + cedilla, "ĝ": "g" + _circumflex, "ġ": "g" + dot_above,
	"Ğ": "G" + breve, "Ģ": "G" + cedilla, "Ĝ": "G" + _circumflex, "Ġ": "G" + dot_above,
	
	"ĥ": "h" + _circumflex,
	"Ĥ": "H" + _circumflex,
	
	"ì": "i" + _grave_accent, "í": "i" + _acute_accent, "î": "i" + _circumflex, "ĩ": "i" + _tilde, "ï": "i" + _diaresis, "ī": "i" + macron, "ị": "i" + dot_below, "ỉ": "i" + hook_above, "į": "i" + ogonek,
	"Ì": "I" + _grave_accent, "Í": "I" + _acute_accent, "Î": "I" + _circumflex, "Ĩ": "I" + _tilde, "Ï": "I" + _diaresis, "Ī": "I" + macron, "Ị": "I" + dot_below, "Ỉ": "I" + hook_above, "Į": "I" + ogonek, "İ": "I" + dot_above,
	
	"ĵ": "j" + _circumflex,
	"Ĵ": "J" + _circumflex,
	
	"ķ": "k" + cedilla,
	"Ķ": "K" + cedilla,
	
	"ļ": "l" + cedilla, "ĺ": "l" + _acute_accent, "ľ": "l" + caron,
	"Ļ": "L" + cedilla, "Ĺ": "L" + _acute_accent, "Ľ": "L" + caron,
	
	"ñ": "n" + _tilde, "ň": "n" + caron, "ń": "n" + _acute_accent, "ņ": "n" + cedilla,
	"Ñ": "N" + _tilde, "Ň": "N" + caron, "Ń": "N" + _acute_accent, "Ņ": "N" + cedilla,
	
	"ò": "o" + _grave_accent, "ó": "o" + _acute_accent, "ô": "o" + _circumflex, "õ": "o" + _tilde, "ö": "o" + _diaresis, "ō": "o" + macron, "ő": "o" + double_acute, "ọ": "o" + dot_below, "ỏ": "o" + hook_above, "ơ": "o" + horn, "ộ": "o" + dot_below + _circumflex, "ớ": "o" + horn + _acute_accent, "ở": "o" + horn + hook_above, "ỡ": "o" + horn + _tilde, "ợ": "o" + horn + dot_below,
	"Ò": "O" + _grave_accent, "Ó": "O" + _acute_accent, "Ô": "O" + _circumflex, "Õ": "O" + _tilde, "Ö": "O" + _diaresis, "Ō": "O" + macron, "Ő": "O" + double_acute, "Ọ": "O" + dot_below, "Ỏ": "O" + hook_above, "Ơ": "O" + horn, "Ộ": "O" + dot_below + _circumflex, "Ờ": "O" + horn + _grave_accent, "Ở": "O" + horn + hook_above, "Ỡ": "O" + horn + _tilde, "Ợ": "O" + horn + dot_below,
	
	"ř": "r" + caron, "ŗ": "r" + cedilla, "ŕ": "r" + _acute_accent,
	"Ř": "R" + caron, "Ŗ": "R" + cedilla, "Ŕ": "R" + _acute_accent,
	
	"š": "s" + caron, "ş": "s" + cedilla, "ș": "s" + comma_below, "ś": "s" + _acute_accent, "ŝ": "s" + _circumflex,
	"Š": "S" + caron, "Ş": "S" + cedilla, "Ș": "S" + comma_below, "Ś": "S" + _acute_accent, "Ŝ": "S" + _circumflex,
	
	"ť": "t" + caron, "ț": "t" + comma_below,
	"Ť": "T" + caron, "Ț": "T" + comma_below,
	
	"ù": "u" + _grave_accent, "ú": "u" + _acute_accent, "û": "u" + _circumflex, "ũ": "u" + _tilde, "ü": "u" + _diaresis, "ů": "u" + ring_above, "ū": "u" + macron, "ű": "u" + double_acute, "ŭ": "u" + breve, "ụ": "u" + dot_below, "ủ": "u" + hook_above, "ư": "u" + horn, "ứ": "u" + horn + _acute_accent, "ừ": "u" + horn + _grave_accent, "ử": "u" + horn + hook_above, "ữ": "u" + horn + _tilde, "ự": "u" + horn + dot_below, "ų": "u" + ogonek,
	"Ù": "U" + _grave_accent, "Ú": "U" + _acute_accent, "Û": "U" + _circumflex, "Ũ": "U" + _tilde, "Ü": "U" + _diaresis, "Ů": "U" + ring_above, "Ū": "U" + macron, "Ű": "U" + double_acute, "Ŭ": "U" + breve, "Ụ": "U" + dot_below, "Ủ": "U" + hook_above, "Ư": "U" + horn, "Ứ": "U" + horn + _acute_accent, "Ừ": "U" + horn + _grave_accent, "Ử": "U" + horn + hook_above, "Ữ": "U" + horn + _tilde, "Ự": "U" + horn + dot_below, "Ų": "U" + ogonek,
	
	"ŵ": "w" + _circumflex,
	"Ŵ": "W" + _circumflex,
	
	"ỳ": "y" + _grave_accent, "ý": "y" + _acute_accent, "ŷ": "y" + _circumflex, "ỹ": "y" + _tilde, "ÿ": "y" + _diaresis, "ỵ": "y" + dot_below, "ỷ": "y" + hook_above,
	"Ỳ": "Y" + _grave_accent, "Ý": "Y" + _acute_accent, "Ŷ": "Y" + _circumflex, "Ỹ": "Y" + _tilde, "Ÿ": "Y" + _diaresis, "Ỵ": "Y" + dot_below, "Ỷ": "Y" + hook_above,
	
	"ž": "z" + caron, "ź": "z" + _acute_accent, "ż": "z" + dot_above,
	"Ž": "Z" + caron, "Ź": "Z" + _acute_accent, "Ż": "Z" + dot_above,
}
# Not canonical, cannot be decomposed in NFD strict, but can be useful to check anyway
const _MAP_NOT_CANONICAL: Dictionary = {
	"æ": "a" + "e",
	"Æ": "A" + "E",
	"œ": "o" + "e",
	"Œ": "O" + "E",
	"ß": "s" + "s", "ẞ": "S" + "S",
	"ø": "o" + long_solidus_overlay, "Ø": "O" + long_solidus_overlay,
	"ł": "l" + short_stroke_overlay, "Ł": "L" + short_stroke_overlay,
	"đ": "d" + short_stroke_overlay, "Đ": "D" + short_stroke_overlay,
	"ð": "d", "Ð": "D",
	"þ": "th", "Þ": "Th",
	"ĳ": "i" + "j", "Ĳ": "I" + "J",
	"ħ": "h" + short_stroke_overlay, "Ħ": "H" + short_stroke_overlay,
}

# Replace NFC -> NFD
func to_nfd_basic(input: String) -> String:
	var output: String = ""
	for ch: String in input:
		output += _MAP.get(ch, ch)
	return output

func to_nfd_extended(input: String) -> String:
	var output_temp: String = to_nfd_basic(input)
	var output: String = ""
	for ch: String in output_temp:
		output += _MAP_NOT_CANONICAL.get(ch, ch)
	return output

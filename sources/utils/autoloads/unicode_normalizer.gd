extends Node
## NFC = Normalization Form Composed (composed form)
## -> compose whenever possible: é is stored as a single code point U+00E9.
##
## NFD = Normalization Form Decomposed (decomposed form)
## -> decompose: é becomes two code points U+0065 (e) + U+0301 (combining acute accent).
## List of well-covered languages: French, Spanish, Portuguese, Italian, German, Swedish, Finnish, Estonian, Czech, Slovak, Slovene/Slovenian, Polish, Croatian, Bosnian, Serbian Latin, Romanian, Hungarian, Lithuanian, Latvian, Albanian, Catalan, Basque, Irish / Scottish Gaelic, Welsh, Maltese, Esperanto, Norwegian, Danish, Icelandic, Faroese, Dutch
## List of OK-covered languages: Turkish => ı (dotless i) has no decomposition
## List of partially covered : Vietnamese => not all tone/diacritic combinations are listed

const _GRAVE_ACCENT: String			= "\u0300" #  ̀
const _ACUTE_ACCENT: String			= "\u0301" #  ́
const _CIRCUMFLEX: String			= "\u0302" #  ̂
const _TILDE: String					= "\u0303" #  ̃
const _DIARESIS: String				= "\u0308" #  ̈
const _CEDILLA: String				= "\u0327" # ¸
const _CARON: String					= "\u030C" # ˇ
const _BREVE: String					= "\u0306" # ˘
const _RING_ABOVE: String			= "\u030A" # ˚
const _DOT_ABOVE: String				= "\u0307" # ˙
const _MACRON: String				= "\u0304" # ˉ
const _COMMA_BELOW: String			= "\u0326" #  ̦
const _OGONEK: String				= "\u0328" #  ̨
const _DOUBLE_ACUTE: String			= "\u030B" # ˝
const _DOT_BELOW: String				= "\u0323" # ̣
const _HOOK_ABOVE: String			= "\u0309" # ̉
const _HORN: String					= "\u031B" # ̛
const _SHORT_STROKE_OVERLAY: String	= "\u0335" # ̵ (ø/ł/đ en NFKD)
const _LONG_SOLIDUS_OVERLAY: String	= "\u0338" # ̸ (Ø en NFKD)
# List is incomplete and should be updated as needed
const _MAP: Dictionary = {
	"à": "a" + _GRAVE_ACCENT, "á": "a" + _ACUTE_ACCENT, "â": "a" + _CIRCUMFLEX, "ã": "a" + _TILDE, "ä": "a" + _DIARESIS, "å": "a" + _RING_ABOVE, "ą": "a" + _OGONEK, "ā": "a" + _MACRON, "ă": "a" + _BREVE, "ạ": "a" + _DOT_BELOW, "ả": "a" + _HOOK_ABOVE,
	"À": "A" + _GRAVE_ACCENT, "Á": "A" + _ACUTE_ACCENT, "Â": "A" + _CIRCUMFLEX, "Ã": "A" + _TILDE, "Ä": "A" + _DIARESIS, "Å": "A" + _RING_ABOVE, "Ą": "A" + _OGONEK, "Ā": "A" + _MACRON, "Ă": "A" + _BREVE, "Ạ": "A" + _DOT_BELOW, "Ả": "A" + _HOOK_ABOVE,
	
	"ç": "c" + _CEDILLA, "č": "c" + _CARON, "ć": "c" + _ACUTE_ACCENT, "ĉ": "c" + _CIRCUMFLEX, "ċ": "c" + _DOT_ABOVE, 
	"Ç": "C" + _CEDILLA, "Č": "C" + _CARON, "Ć": "C" + _ACUTE_ACCENT, "Ĉ": "C" + _CIRCUMFLEX, "Ċ": "C" + _DOT_ABOVE,
	
	"ď": "d" + _CARON,
	"Ď": "D" + _CARON,
	
	"è": "e" + _GRAVE_ACCENT, "é": "e" + _ACUTE_ACCENT, "ê": "e" + _CIRCUMFLEX, "ẽ": "e" + _TILDE, "ë": "e" + _DIARESIS, "ě": "e" + _CARON, "ę": "e" + _OGONEK, "ē": "e" + _MACRON, "ẹ": "e" + _DOT_BELOW, "ẻ": "e" + _HOOK_ABOVE, "ė": "e" + _DOT_ABOVE,
	"È": "E" + _GRAVE_ACCENT, "É": "E" + _ACUTE_ACCENT, "Ê": "E" + _CIRCUMFLEX, "Ẽ": "E" + _TILDE, "Ë": "E" + _DIARESIS, "Ě": "E" + _CARON, "Ę": "E" + _OGONEK, "Ē": "E" + _MACRON, "Ẹ": "E" + _DOT_BELOW, "Ẻ": "E" + _HOOK_ABOVE, "Ė": "E" + _DOT_ABOVE,
	
	"ğ": "g" + _BREVE, "ģ": "g" + _CEDILLA, "ĝ": "g" + _CIRCUMFLEX, "ġ": "g" + _DOT_ABOVE,
	"Ğ": "G" + _BREVE, "Ģ": "G" + _CEDILLA, "Ĝ": "G" + _CIRCUMFLEX, "Ġ": "G" + _DOT_ABOVE,
	
	"ĥ": "h" + _CIRCUMFLEX,
	"Ĥ": "H" + _CIRCUMFLEX,
	
	"ì": "i" + _GRAVE_ACCENT, "í": "i" + _ACUTE_ACCENT, "î": "i" + _CIRCUMFLEX, "ĩ": "i" + _TILDE, "ï": "i" + _DIARESIS, "ī": "i" + _MACRON, "ị": "i" + _DOT_BELOW, "ỉ": "i" + _HOOK_ABOVE, "į": "i" + _OGONEK,
	"Ì": "I" + _GRAVE_ACCENT, "Í": "I" + _ACUTE_ACCENT, "Î": "I" + _CIRCUMFLEX, "Ĩ": "I" + _TILDE, "Ï": "I" + _DIARESIS, "Ī": "I" + _MACRON, "Ị": "I" + _DOT_BELOW, "Ỉ": "I" + _HOOK_ABOVE, "Į": "I" + _OGONEK, "İ": "I" + _DOT_ABOVE,
	
	"ĵ": "j" + _CIRCUMFLEX,
	"Ĵ": "J" + _CIRCUMFLEX,
	
	"ķ": "k" + _CEDILLA,
	"Ķ": "K" + _CEDILLA,
	
	"ļ": "l" + _CEDILLA, "ĺ": "l" + _ACUTE_ACCENT, "ľ": "l" + _CARON,
	"Ļ": "L" + _CEDILLA, "Ĺ": "L" + _ACUTE_ACCENT, "Ľ": "L" + _CARON,
	
	"ñ": "n" + _TILDE, "ň": "n" + _CARON, "ń": "n" + _ACUTE_ACCENT, "ņ": "n" + _CEDILLA,
	"Ñ": "N" + _TILDE, "Ň": "N" + _CARON, "Ń": "N" + _ACUTE_ACCENT, "Ņ": "N" + _CEDILLA,
	
	"ò": "o" + _GRAVE_ACCENT, "ó": "o" + _ACUTE_ACCENT, "ô": "o" + _CIRCUMFLEX, "õ": "o" + _TILDE, "ö": "o" + _DIARESIS, "ō": "o" + _MACRON, "ő": "o" + _DOUBLE_ACUTE, "ọ": "o" + _DOT_BELOW, "ỏ": "o" + _HOOK_ABOVE, "ơ": "o" + _HORN, "ộ": "o" + _DOT_BELOW + _CIRCUMFLEX, "ớ": "o" + _HORN + _ACUTE_ACCENT, "ở": "o" + _HORN + _HOOK_ABOVE, "ỡ": "o" + _HORN + _TILDE, "ợ": "o" + _HORN + _DOT_BELOW,
	"Ò": "O" + _GRAVE_ACCENT, "Ó": "O" + _ACUTE_ACCENT, "Ô": "O" + _CIRCUMFLEX, "Õ": "O" + _TILDE, "Ö": "O" + _DIARESIS, "Ō": "O" + _MACRON, "Ő": "O" + _DOUBLE_ACUTE, "Ọ": "O" + _DOT_BELOW, "Ỏ": "O" + _HOOK_ABOVE, "Ơ": "O" + _HORN, "Ộ": "O" + _DOT_BELOW + _CIRCUMFLEX, "Ờ": "O" + _HORN + _GRAVE_ACCENT, "Ở": "O" + _HORN + _HOOK_ABOVE, "Ỡ": "O" + _HORN + _TILDE, "Ợ": "O" + _HORN + _DOT_BELOW,
	
	"ř": "r" + _CARON, "ŗ": "r" + _CEDILLA, "ŕ": "r" + _ACUTE_ACCENT,
	"Ř": "R" + _CARON, "Ŗ": "R" + _CEDILLA, "Ŕ": "R" + _ACUTE_ACCENT,
	
	"š": "s" + _CARON, "ş": "s" + _CEDILLA, "ș": "s" + _COMMA_BELOW, "ś": "s" + _ACUTE_ACCENT, "ŝ": "s" + _CIRCUMFLEX,
	"Š": "S" + _CARON, "Ş": "S" + _CEDILLA, "Ș": "S" + _COMMA_BELOW, "Ś": "S" + _ACUTE_ACCENT, "Ŝ": "S" + _CIRCUMFLEX,
	
	"ť": "t" + _CARON, "ț": "t" + _COMMA_BELOW,
	"Ť": "T" + _CARON, "Ț": "T" + _COMMA_BELOW,
	
	"ù": "u" + _GRAVE_ACCENT, "ú": "u" + _ACUTE_ACCENT, "û": "u" + _CIRCUMFLEX, "ũ": "u" + _TILDE, "ü": "u" + _DIARESIS, "ů": "u" + _RING_ABOVE, "ū": "u" + _MACRON, "ű": "u" + _DOUBLE_ACUTE, "ŭ": "u" + _BREVE, "ụ": "u" + _DOT_BELOW, "ủ": "u" + _HOOK_ABOVE, "ư": "u" + _HORN, "ứ": "u" + _HORN + _ACUTE_ACCENT, "ừ": "u" + _HORN + _GRAVE_ACCENT, "ử": "u" + _HORN + _HOOK_ABOVE, "ữ": "u" + _HORN + _TILDE, "ự": "u" + _HORN + _DOT_BELOW, "ų": "u" + _OGONEK,
	"Ù": "U" + _GRAVE_ACCENT, "Ú": "U" + _ACUTE_ACCENT, "Û": "U" + _CIRCUMFLEX, "Ũ": "U" + _TILDE, "Ü": "U" + _DIARESIS, "Ů": "U" + _RING_ABOVE, "Ū": "U" + _MACRON, "Ű": "U" + _DOUBLE_ACUTE, "Ŭ": "U" + _BREVE, "Ụ": "U" + _DOT_BELOW, "Ủ": "U" + _HOOK_ABOVE, "Ư": "U" + _HORN, "Ứ": "U" + _HORN + _ACUTE_ACCENT, "Ừ": "U" + _HORN + _GRAVE_ACCENT, "Ử": "U" + _HORN + _HOOK_ABOVE, "Ữ": "U" + _HORN + _TILDE, "Ự": "U" + _HORN + _DOT_BELOW, "Ų": "U" + _OGONEK,
	
	"ŵ": "w" + _CIRCUMFLEX,
	"Ŵ": "W" + _CIRCUMFLEX,
	
	"ỳ": "y" + _GRAVE_ACCENT, "ý": "y" + _ACUTE_ACCENT, "ŷ": "y" + _CIRCUMFLEX, "ỹ": "y" + _TILDE, "ÿ": "y" + _DIARESIS, "ỵ": "y" + _DOT_BELOW, "ỷ": "y" + _HOOK_ABOVE,
	"Ỳ": "Y" + _GRAVE_ACCENT, "Ý": "Y" + _ACUTE_ACCENT, "Ŷ": "Y" + _CIRCUMFLEX, "Ỹ": "Y" + _TILDE, "Ÿ": "Y" + _DIARESIS, "Ỵ": "Y" + _DOT_BELOW, "Ỷ": "Y" + _HOOK_ABOVE,
	
	"ž": "z" + _CARON, "ź": "z" + _ACUTE_ACCENT, "ż": "z" + _DOT_ABOVE,
	"Ž": "Z" + _CARON, "Ź": "Z" + _ACUTE_ACCENT, "Ż": "Z" + _DOT_ABOVE,
}
# Not canonical, cannot be decomposed in NFD strict, but can be useful to check anyway
const _MAP_NOT_CANONICAL: Dictionary = {
	"æ": "a" + "e",
	"Æ": "A" + "E",
	"œ": "o" + "e",
	"Œ": "O" + "E",
	"ß": "s" + "s", "ẞ": "S" + "S",
	"ø": "o" + _LONG_SOLIDUS_OVERLAY, "Ø": "O" + _LONG_SOLIDUS_OVERLAY,
	"ł": "l" + _SHORT_STROKE_OVERLAY, "Ł": "L" + _SHORT_STROKE_OVERLAY,
	"đ": "d" + _SHORT_STROKE_OVERLAY, "Đ": "D" + _SHORT_STROKE_OVERLAY,
	"ð": "d", "Ð": "D",
	"þ": "th", "Þ": "Th",
	"ĳ": "i" + "j", "Ĳ": "I" + "J",
	"ħ": "h" + _SHORT_STROKE_OVERLAY, "Ħ": "H" + _SHORT_STROKE_OVERLAY,
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

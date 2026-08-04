class_name AdultChallenge
extends RefCounted
## The "prove you are an adult" test: three named symbols, entered in order.
##
## A child young enough to be using Kalulu cannot read the instruction, which is
## what makes it a gate rather than a password -- so there is nothing to memorise
## and nothing to type in secret.
##
## The logic lives here because three screens ask it: the boss minigame's block,
## the Sign Up tab, and the way into the teacher settings. They each draw it
## differently, but a second copy of "which symbols, and did they match" is a
## second place for the symbol names to drift out of step.

## The answer currently being asked for.
var code: String = ""


func _init() -> void:
	renew()


## Picks a new set of symbols to ask for.
##
## Drawn from the student codes, which is exactly the set of three-symbol
## combinations the keypad can express.
func renew() -> void:
	code = str(TeacherSettings.AVAILABLE_CODES.pick_random())


## The instruction to show, built from `translation_key` and the symbol names.
##
## The key's message takes {1}, {2} and {3} -- the symbols to tap, in order.
func prompt(translation_key: String) -> String:
	var digits: PackedStringArray = code.split("", false)
	if digits.size() < 3:
		Log.error("AdultChallenge: '%s' is not three symbols" % code)
		return TranslationServer.translate(translation_key)
	return TranslationServer.translate(translation_key).format({
		"1": TranslationServer.translate(Design.code_symbol_name(digits[0])),
		"2": TranslationServer.translate(Design.code_symbol_name(digits[1])),
		"3": TranslationServer.translate(Design.code_symbol_name(digits[2])),
	})


## Whether `entered` is the answer being asked for.
func accepts(entered: String) -> bool:
	return entered == code

class_name Design
extends Object
## Design tokens for the redesigned menus (welcome, login, registration, settings).
##
## Single source of truth for the palette, type scale and component metrics of
## the main-menu redesign. Every value here was sampled or measured from the
## hand-off mockups rather than transcribed by eye, so components built from
## these tokens match the design without per-scene tweaking.
##
## All lengths are in pixels of the project's reference viewport (2560x1800),
## which is exactly the size the mockups were drawn at: they map 1:1.
##
## Note: the style guide labels the fourth accent swatch "#E0E0E0" while the
## swatch itself is #812A80. The sampled value is the one used here.

# --- Brand -------------------------------------------------------------------
const PURPLE: Color = Color("812a80")
const NAVY: Color = Color("2a367d")
# --- Neutrals (text, dividers, icons, UI details) ----------------------------
const GREY_DARK: Color = Color("474747")
const GREY: Color = Color("707070")
const GREY_LIGHT: Color = Color("cccccc")
const GREY_LIGHTER: Color = Color("e0e0e0")
const LAVENDER: Color = Color("f2ebf5")
# --- System feedback ---------------------------------------------------------
const ERROR: Color = Color("ff3334")
const SUCCESS: Color = Color("22c55e")
const WARNING: Color = Color("ffaf17")
# --- Access-code colours, keyed by code digit --------------------------------
# The digit is the identity of a symbol everywhere in the codebase
# (see PasswordVisualizer.ICONS_TEXTURES and the CODE_SYMBOL_NAMES below).
const CODE_COLORS: Dictionary[String, Color] = {
	"1": Color("2e7d32"), # star - green
	"2": Color("1976d2"), # bar - blue
	"3": Color("c78a00"), # circle - amber
	"4": Color("d32f2f"), # plus - red
	"5": Color("db4fc3"), # square - pink
	"6": Color("812a80"), # triangle - purple
}
# Translation keys for each code digit, used to spell a code out in prompts.
const CODE_SYMBOL_NAMES: Dictionary[String, String] = {
	"1": "STAR",
	"2": "BAR",
	"3": "CIRCLE",
	"4": "PLUS",
	"5": "SQUARE",
	"6": "TRIANGLE",
}
# Reading order of the 3x2 code keypad in the mockups: star, plus, circle /
# square, triangle, bar. Deliberately not 1..6 -- the design groups the
# symbols by shape family rather than by digit.
const CODE_KEYPAD_ORDER: Array[String] = ["1", "4", "3", "5", "6", "2"]
# --- Type scale (Mulish) -----------------------------------------------------
# Sizes confirmed by matching rendered glyph widths in the mockups against the
# project's own Mulish faces, so they are exact rather than approximated.
const FONT_SIZE_TITLE: int = 60 # bold - screen title
const FONT_SIZE_HEADING: int = 48 # bold - section heading
const FONT_SIZE_INPUT: int = 50 # regular - field text, placeholders, buttons
const FONT_SIZE_BODY: int = 44 # regular - help notes, subtitles
const FONT_SIZE_LABEL: int = 32 # regular - small field labels
const FONT_SIZE_CAPTION: int = 28 # regular - version strings, captions
const FONT_REGULAR_PATH: String = "res://assets/fonts/kalulu_mulish_regular.otf"
const FONT_BOLD_PATH: String = "res://assets/fonts/kalulu_mulish_bold.otf"
# --- Layout ------------------------------------------------------------------
const SCREEN_MARGIN: int = 64
const CONTENT_WIDTH: int = 940
const FIELD_GAP: int = 104
# --- Surfaces ----------------------------------------------------------------
const CARD_RADIUS: int = 14
const CARD_PADDING: int = 88
# --- Text fields -------------------------------------------------------------
const FIELD_HEIGHT: int = 128
const FIELD_RADIUS: int = 14
const FIELD_PADDING: int = 56
# On-screen size of a trailing field icon. The icons import at twice this for
# crispness, so they are drawn scaled down rather than at texture size.
const FIELD_ICON_SIZE: int = 48
# --- Wide buttons (Next / Previous / Cancel) ---------------------------------
const BUTTON_SIZE: Vector2i = Vector2i(332, 164)
const BUTTON_RADIUS: int = 8
const BUTTON_BORDER: int = 3
# --- Segmented toggle (Login | Sign Up) --------------------------------------
const TOGGLE_HEIGHT: int = 116
const TOGGLE_INSET: int = 12
# --- Tab pills (Device 1 | Device 2 ...) -------------------------------------
const PILL_HEIGHT: int = 74
const PILL_PADDING: int = 48
# --- Circular buttons --------------------------------------------------------
const ROUND_BUTTON_LARGE: int = 184 # back / Kalulu corner buttons
const ROUND_BUTTON_SMALL: int = 90 # icon buttons in headers and cards
# --- Access-code keypad ------------------------------------------------------
# Codes are three symbols long and never repeat a symbol: see
# TeacherSettings.AVAILABLE_CODES, which lists the distinct-digit permutations.
const CODE_LENGTH: int = 3
const CODE_SLOT_SIZE: int = 239
const CODE_SLOT_GAP: int = 102
const CODE_SLOT_RADIUS: int = 12
const CODE_KEY_SIZE: Vector2i = Vector2i(471, 259)
const CODE_KEY_RADIUS: int = 12
const CODE_KEY_GAP: Vector2i = Vector2i(110, 69)
const CODE_SYMBOL_SIZE: int = 110
const CODE_SYMBOL_PATH_FORMAT: String = "res://assets/menus/login/symbol_%02d.png"


## Colour of the access-code symbol `digit`, white for an unknown digit.
static func code_color(digit: String) -> Color:
	return CODE_COLORS.get(digit, Color.WHITE)


## Translation key naming the access-code symbol `digit`, empty if unknown.
static func code_symbol_name(digit: String) -> String:
	return CODE_SYMBOL_NAMES.get(digit, "")


## White glyph for the access-code symbol `digit`, null for an unknown digit.
static func code_symbol_texture(digit: String) -> Texture2D:
	if not CODE_COLORS.has(digit):
		return null
	return load(CODE_SYMBOL_PATH_FORMAT % int(digit)) as Texture2D

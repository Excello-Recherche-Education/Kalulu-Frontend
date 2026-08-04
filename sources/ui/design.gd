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
# Reading order of the 3x2 code keypad: numerical, 1-2-3 over 4-5-6. The
# mockups group the symbols by shape family instead, which puts the digits in a
# scrambled order on screen; codes are handed out and read back as numbers, so
# the keypad follows the numbers.
const CODE_KEYPAD_ORDER: Array[String] = ["1", "2", "3", "4", "5", "6"]
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
const SCREEN_MARGIN: int = 64 # corner buttons
const CONTENT_WIDTH: int = 940 # the column of fields down the middle
const FIELD_GAP: int = 104
# The wizard screens inset their footer buttons by this much, and the settings
# and conditions cards are exactly the resulting width.
const PAGE_MARGIN: int = 340
const PAGE_MARGIN_BOTTOM: int = 196
# --- Sign-up wizard steps -----------------------------------------------------
# Every step mockup puts the field column at the same height and grows the
# question upwards from there, so the field top is the anchor and the question
# block hangs above it rather than the two being centred together.
const STEP_FORM_TOP: int = 772
const STEP_QUESTION_GAP: int = 80 # question block bottom to field top
const STEP_INFO_GAP: int = 48 # title to the note under it
const STEP_QUESTION_WIDTH: int = 1500 # wider than the fields, so titles fit on one line
# The conditions and recap steps drop the field column for a full-width card
# under a heading, rather than a question hanging over a form.
const STEP_TITLE_TOP: int = 146
const STEP_CARD_TOP: int = 268
const STEP_CARD_BOTTOM: int = 1355
const STEP_CARD_PADDING: Vector2i = Vector2i(80, 56)
# --- Check box ----------------------------------------------------------------
# Filled green with a white tick once ticked, off-white before.
const CHECKBOX_SIZE: int = 90
const CHECKBOX_GAP: int = 29
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
const PILL_WIDTH: int = 272
const PILL_GAP: int = 46
# --- Settings -----------------------------------------------------------------
# Settings' dropdowns are shorter than the fields on the sign-up screens.
const COMPACT_FIELD_HEIGHT: int = 88
const SETTINGS_CARD_PADDING: Vector2i = Vector2i(80, 42)
const ICON_BUTTON_GAP: int = 36
# --- Student progress panel ---------------------------------------------------
# Fields on a white card are a shade off white rather than white, so they read as
# fields at all.
const SUBTLE_FIELD_FILL: Color = Color("fafafa")
const PROGRESS_CARD_SIZE: Vector2i = Vector2i(2205, 1580)
const PROGRESS_NAME_FIELD: Vector2i = Vector2i(900, 160)
const PROGRESS_CHIP_SIZE: int = 151
const TABLE_HEADER_HEIGHT: int = 136
# --- Student cards and their code chips ---------------------------------------
const STUDENT_CARD_SIZE: Vector2i = Vector2i(510, 184)
const STUDENT_CARD_GAP: int = 58
const STUDENT_CARD_COLUMNS: int = 3
const STUDENT_CARD_RADIUS: int = 12
const CODE_CHIP_SIZE: int = 68
const CODE_CHIP_GAP: int = 21
const CODE_CHIP_RADIUS: int = 10
const CODE_CHIP_GLYPH_SIZE: int = 30
# --- Device cards ------------------------------------------------------------
const DEVICE_CARD_SIZE: Vector2i = Vector2i(183, 222)
const DEVICE_CARD_GAP: Vector2i = Vector2i(104, 126)
const DEVICE_CARD_COLUMNS: int = 6
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
# The glyph alone, white on transparent. symbol_0N.png is the older artwork: an
# old-palette rounded tile with the glyph already on it, which cannot sit on the
# redesign's flat colours.
const CODE_SYMBOL_PATH_FORMAT: String = "res://assets/menus/login/symbol_glyph_%02d.png"


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

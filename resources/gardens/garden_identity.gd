class_name GardenIdentity
extends RefCounted
## What a garden looks like, for the screens that name a garden without showing one.
##
## The teacher's progress table marks every lesson with the garden it belongs to.
## Loading the garden scenes for that would be the wrong way round: each one carries
## a dozen full-size textures, and gardens.gd loads them one at a time on purpose --
## keeping all twelve in memory "OOM-crashes low-memory devices", as it puts it. So
## the three fields a table row needs are written out here instead, and
## test_garden_identity.gd holds them to what the garden scenes actually say: it
## walks Gardens.GARDEN_SCENE_PATHS, so a garden that is recoloured or given a new
## animal fails there rather than quietly disagreeing with the table.

## One entry per garden, in the order the gardens are walked. Each holds:
##
##   animal      the garden's creature, already drawn in the garden's colours
##   badge       the fill the garden gives a finished lesson
##   badge_text  what that garden writes on the fill
##
## The badge pair is taken from the lesson buttons rather than picked here, so a
## number in the table is the same colour as the lesson the child sees.
const GARDENS: Array[Dictionary] = [
	{
		"animal": "res://assets/gardens/victory_assets/animals/jellyfish.png",
		"badge": Color("9be3ea"), "badge_text": Color("0a555b"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/turtle.png",
		"badge": Color("e4d3ef"), "badge_text": Color("58447d"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/ant.png",
		"badge": Color("ebc0de"), "badge_text": Color("850867"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/crab.png",
		"badge": Color("ffcab0"), "badge_text": Color("bf4700"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/yellow_parakeet.png",
		"badge": Color("fff0c7"), "badge_text": Color("b37100"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/caterpillar.png",
		"badge": Color("f7ffc0"), "badge_text": Color("4e6109"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/frog.png",
		"badge": Color("b3ffde"), "badge_text": Color("007542"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/monkey.png",
		"badge": Color("ffe0c2"), "badge_text": Color("5c3208"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/red_parakeet.png",
		"badge": Color("ffb9b3"), "badge_text": Color("990000"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/pink_jellyfish.png",
		"badge": Color("ffd1ec"), "badge_text": Color("a64a80"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/khaki_turtle.png",
		"badge": Color("f2e3b8"), "badge_text": Color("564c2a"),
	},
	{
		"animal": "res://assets/gardens/victory_assets/animals/penguin.png",
		"badge": Color("c8e6f3"), "badge_text": Color("008dc4"),
	},
]


## The garden's creature, or null for an index no garden answers to.
##
## Loaded rather than preloaded, for the reason in the note above: a screen that
## never opens the teacher's table should not be holding twelve animals.
static func animal_texture(garden_index: int) -> Texture2D:
	if not _knows(garden_index):
		return null
	var path: String = GARDENS[garden_index]["animal"]
	return load(path) as Texture2D


## The fill behind a lesson number or grapheme from this garden.
static func badge_color(garden_index: int) -> Color:
	if not _knows(garden_index):
		return Design.GREY_LIGHTER
	var badge: Color = GARDENS[garden_index]["badge"]
	return badge


## What to write on that fill.
static func badge_text_color(garden_index: int) -> Color:
	if not _knows(garden_index):
		return Design.NAVY
	var badge_text: Color = GARDENS[garden_index]["badge_text"]
	return badge_text


static func _knows(garden_index: int) -> bool:
	return garden_index >= 0 and garden_index < GARDENS.size()

class_name MinigameTypes
extends RefCounted
## The name of every minigame, in Minigame.Type order.
##
## Used for file paths, database keys and speech lookups, and as the content of
## a language pack's ExerciseTypes table: the row at ID n holds NAMES[n - 1], and
## LessonsExercises stores that ID. So this list is part of the pack format,
## shared by the game and the Prof Tool, and depends on nothing else. Reorder or
## rename an entry only together with Minigame.Type and every pack.

const NAMES: Array[String] = [
	"jellyfish",
	"crabs",
	"parakeets",
	"monkey",
	"caterpillar",
	"frog",
	"turtles",
	"ants",
	"penguin",
	"boss",
]

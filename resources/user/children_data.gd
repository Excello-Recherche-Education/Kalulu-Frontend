extends Resource
class_name StudentData


enum Level {
	Beginner,
	Reviewer,
	Adult
}

@export var code : String
@export var name : String
@export var level : Level
@export var age : int


func _to_string():
	return "{Code: %s, Name: %s, Level: %s, Age: %d}" % [code, name, Level.keys()[level], age]

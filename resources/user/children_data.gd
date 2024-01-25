extends Resource
class_name StudentData


enum Level {
	Beginner,
	Reviewer,
	Adult
}

@export var name : String
@export var age : int
@export var level : Level
@export var device : int
@export var code : String


func _to_string():
	return "{Device: %s, Code: %s}" % [device, code]

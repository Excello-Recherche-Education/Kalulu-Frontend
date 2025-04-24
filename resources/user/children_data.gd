extends Resource
class_name StudentData


enum Level {
	Beginner,
	Reviewer,
	Adult
}

@export var code: int
@export var name: String
@export var level: Level
@export var age: int

func to_dict() -> Dictionary:
	return {
		"code": code,
		"name": name,
		"level": level,
		"age": age
	}

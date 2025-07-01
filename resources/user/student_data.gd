extends Resource
class_name StudentData


enum Level {
	Beginner,
	Reviewer,
	Adult
}

@export var code: int = 0
@export var name: String = ""
@export var level: Level = Level.Beginner
@export var age: int = 0
@export var last_modified: String = ""

func to_dict() -> Dictionary:
	return {
		"code": code,
		"name": name,
		"level": level,
		"age": age,
		"last_modified": last_modified,
	}

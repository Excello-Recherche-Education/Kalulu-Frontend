class_name StudentData
extends Resource

enum Level {
	BEGINNER,
	REVIEWER,
	ADULT
}

@export var code: int = 0
@export var name: String = ""
@export var level: Level = Level.BEGINNER
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

extends Step

@onready var students_count_field := %StudentsCountField

func _ready():
	super._ready()	
	if data and "devices_count" in data:
		students_count_field.min_value = data.devices_count

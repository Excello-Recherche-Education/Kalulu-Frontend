extends Resource
class_name TeacherSettings

enum Type {
	Teacher,
	Parent
}

@export var type : Type
@export var devices_number : int
@export var students_number : int
# Faire une ressource Student ici plutot
@export var students_passwords : Array

func _init(t : Type, devices : int, students: int):
	
	type = t
	devices_number = devices
	students_number = students
	
	var leftovers := students_number%devices_number
	
	for i in devices:
		
		var nb = students_number/devices_number
		if leftovers > 0:
			nb+= 1
			leftovers -=1
		
		var passwords := []
		for j in nb:
			# TODO Fetch an unique password here
			passwords.append(str(j))
		
		students_passwords.append(passwords)
	
	print(students_passwords)

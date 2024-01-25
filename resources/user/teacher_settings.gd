extends Resource
class_name TeacherSettings


const available_codes: = ["123", "124", "125", "126", "132", "134", "135", "136", "142", "143", "145", "146", "152", "153", "154", "213", "214", "215", "216", "231", "234", "235", "236", "241", "243", "245", "246", "251", "253", "254", "321", "324", "325", "326", "312", "314", "315", "316", "342", "341", "345", "346", "352", "351", "354", "423", "421", "425", "426", "432", "431", "435", "436", "412", "413", "415", "416", "452", "453", "451", "523", "524", "521", "526", "532", "534", "531", "536", "542", "543", "541", "546", "512", "513", "514", "623", "624", "625", "621", "632", "634", "635", "631", "642", "643", "645", "641", "652", "653", "654"]

enum Type {
	Teacher,
	Parent
}

@export var type : Type
@export var students : Array[StudentData] = []


func setup_students(devices : int, students_count: int):
	
	if students_count > available_codes.size():
		students_count = available_codes.size()
	
	var leftovers := students_count%devices
	
	@warning_ignore("integer_division")
	var nb = students_count/devices
	for i in devices:
		
		var current_device_count: int = nb
		if leftovers > 0:
			current_device_count+= 1
			leftovers -=1
		
		for j in current_device_count:
			var student := StudentData.new()
			student.device = i+1
			student.code = get_new_code()
			students.append(student)
	
	print(students)


func _randomize_code() -> String :
	return available_codes[randi() % available_codes.size()]


func get_new_code() -> String :
	
	var used_codes = []
	for student in students:
		used_codes.append(student.code)
	
	var code : String = _randomize_code()
	while code in used_codes:
		code = _randomize_code()
	return code

extends Resource
class_name TeacherSettings

const available_codes: = ["123", "124", "125", "126", "132", "134", "135", "136", "142", "143", "145", "146", "152", "153", "154", "213", "214", "215", "216", "231", "234", "235", "236", "241", "243", "245", "246", "251", "253", "254", "321", "324", "325", "326", "312", "314", "315", "316", "342", "341", "345", "346", "352", "351", "354", "423", "421", "425", "426", "432", "431", "435", "436", "412", "413", "415", "416", "452", "453", "451", "523", "524", "521", "526", "532", "534", "531", "536", "542", "543", "541", "546", "512", "513", "514", "623", "624", "625", "621", "632", "634", "635", "631", "642", "643", "645", "641", "652", "653", "654"]

enum AccountType {
	Teacher,
	Parent
}

enum EducationMethod {
	AppOnly,
	Complete
}

@export var account_type : AccountType
@export var education_method : EducationMethod
@export var devices_count : int
@export var students : Dictionary # int : Array[StudentData]
@export var email : String
@export var password : String # Temporary


func get_new_code() -> String :
	var used_codes = []
	for student_array in students.values():
		for student in student_array:
			used_codes.append(student.code)
	
	if used_codes.size() == available_codes.size():
		return ""
	
	var code : String = available_codes.pick_random()
	while code in used_codes:
		code = available_codes.pick_random()
	return code


func get_students_count() -> int :
	if not students:
		return 0
	
	var count = 0
	for device in students.keys():
		var students_array = students[device] as Array
		if students_array:
			count += students[device].size()
	
	return count

func _to_string():
	return "{Account Type: %s, Education Method: %s, Devices count: %d, Students: %s, Email: %s, Password: %s}" % [AccountType.keys()[account_type], EducationMethod.keys()[education_method], devices_count, str(students), email, password]

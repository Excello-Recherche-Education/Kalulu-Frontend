extends Resource
class_name TeacherSettings

const available_codes: Array[int] = [123, 124, 125, 126, 132, 134, 135, 136, 142, 143, 145, 146, 152, 153, 154, 213, 214, 215, 216, 231, 234, 235, 236, 241, 243, 245, 246, 251, 253, 254, 321, 324, 325, 326, 312, 314, 315, 316, 342, 341, 345, 346, 352, 351, 354, 423, 421, 425, 426, 432, 431, 435, 436, 412, 413, 415, 416, 452, 453, 451, 523, 524, 521, 526, 532, 534, 531, 536, 542, 543, 541, 546, 512, 513, 514, 623, 624, 625, 621, 632, 634, 635, 631, 642, 643, 645, 641, 652, 653, 654]


enum AccountType {
	Teacher,
	Parent
}

enum EducationMethod {
	AppOnly,
	Complete
}

@export var account_type: AccountType
@export var education_method: EducationMethod
var devices_count: int
@export var students: Dictionary # int : Array[StudentData]
@export var email: String
var password: String
@export var token: String
@export var last_modified: String

func update_from_dict(dict: Dictionary) -> void:
	if dict.has("account_type"):
		account_type = dict.account_type
	if dict.has("education_method"):
		education_method = dict.education_method
	if dict.has("email"):
		email = dict.email
	if dict.has("token"):
		token = dict.token
	
	last_modified = dict.last_modified
	
	students.clear()
	var d_students: Dictionary = dict.students
	for device: String in d_students.keys():
		var device_students: Array[StudentData] = []
		for student_dico: Dictionary in dict.students[device]: 
			var student: StudentData = StudentData.new()
			student.code = student_dico.code
			student.name = student_dico.name
			student.age = student_dico.age
			student.level = student_dico.level
			device_students.append(student)
		
		students[int(device)] = device_students

func get_new_code() -> int :
	var used_codes: Array[int]
	for student_array: Array[StudentData] in students.values():
		for student: StudentData in student_array:
			used_codes.append(student.code)
	
	if used_codes.size() == available_codes.size():
		return -1
	
	var codes: Array[int] = available_codes.duplicate()
	for code: int in used_codes:
		codes.erase(code)
	
	var code: int = codes.pick_random()
	return code


func get_students_count() -> int :
	if not students:
		return 0
	
	var count: int = 0
	for device: int in students.keys():
		var students_array: Array = students[device] as Array
		if students_array:
			count += students_array.size()
	
	return count

func to_dict() -> Dictionary:
	var dict: Dictionary = {
		"account_type": account_type,
		"email": email,
		"password": password,
		"education_method": education_method,
	}
	
	dict["students"] = {}
	for device: int in students.keys():
		dict["students"][device] = []
		var device_students: Array = dict["students"][device]
		for s: StudentData in students[device]: 
			device_students.append(s.to_dict())
	
	return dict

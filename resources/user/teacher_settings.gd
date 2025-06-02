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
@export var students: Dictionary[int, Array] = {} # int (device) : Array[StudentData]
@export var email: String
var password: String
@export var token: String
@export var last_modified: String = ""

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


func update_student_name(student_code: int, student_name: String) -> void:
	for device_students: Array[StudentData] in students.values():
		for student_data: StudentData in device_students:
			if student_data.code == student_code:
				student_data.name = student_name
				Logger.trace("TeacherSettings: Updated student code " + str(student_code) + ": new name is " + student_name)
				student_data.last_modified = Time.get_datetime_string_from_system(true)
				UserDataManager.save_all()
				return
	Logger.warn("TeacherSettings: update_student_name: student not found with code " + str(student_code))


func update_student_device(student_code: int, new_student_device: int) -> void:
	for current_student_device: int in students.keys():
		var studentsData: Array[StudentData] = students[current_student_device]
		for student_data: StudentData in studentsData:
			if student_data.code == student_code:
				if current_student_device == new_student_device:
					Logger.trace("TeacherSettings: update_student_device: student %d new device is already current student device, no update necessary" % student_code)
					return
				studentsData.erase(student_data)
				if not students.has(new_student_device):
					Logger.warn("TeacherSettings: update_student_device: student %d new device does not exists, it should not be possible. Update will still work anyway." % student_code)
					students[new_student_device] = []
				students[new_student_device].append(student_data)
				UserDataManager.move_user_device_folder(str(current_student_device), str(new_student_device), student_code)
				student_data.last_modified = Time.get_datetime_string_from_system(true)
				UserDataManager.save_all()
				return
	Logger.warn("TeacherSettings: update_student_device: student not found with code " + str(student_code))


func get_new_code() -> int :
	var used_codes: Array[int] = []
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

func to_dict() -> Dictionary:
	var dict: Dictionary = {
		"account_type": account_type,
		"email": email,
		"password": password,
		"education_method": education_method,
		"last_modified": last_modified,
	}
	
	dict["students"] = {}
	for device: int in students.keys():
		dict["students"][device] = []
		var device_students: Array = dict["students"][device]
		for s: StudentData in students[device]: 
			device_students.append(s.to_dict())
	
	return dict

func get_number_of_students() -> int:
	if not students:
		return 0
	var result: int = 0
	for datas: Array[StudentData] in students.values():
		result += datas.size()
	return result

func get_all_students_data() -> Array[StudentData]:
	var result: Array[StudentData]
	for datas: Array[StudentData] in students.values():
		result.append_array(datas)
	return result

func delete_student(student_code: int) -> void:
	for device: int in students.keys():
		for index: int in students[device].size():
			if students[device][index].code == student_code:
				students[device].remove_at(index)
				if students[device].is_empty():
					students.erase(device)
				return
	Logger.warn("TeacherSettings: Trying to delete student, but code %d not found" % student_code)

func get_student_with_code(student_code: int) -> StudentData:
	for student_data: StudentData in get_all_students_data():
		if student_data.code == student_code:
			return student_data
	return null

func get_student_device(student_code: int) -> int:
	for device: int in students.keys():
		for index: int in students[device].size():
			if students[device][index].code == student_code:
				return device
	return -1

func set_data_student_with_code(student_code: int, new_device_id: int, new_name: String, new_age: int, new_last_modified: String) -> void:
	update_student_device(student_code, new_device_id)
	for student_data: StudentData in students[new_device_id]:
		if student_data.code == student_code:
			student_data.name = new_name
			student_data.age = new_age
			student_data.last_modified = new_last_modified
			return
	Logger.error("TeacherSettings: Student %d not found to set data on it" % student_code)

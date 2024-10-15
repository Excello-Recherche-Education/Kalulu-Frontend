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
var devices_count : int
@export var students : Dictionary # int : Array[StudentData]
@export var email : String
var password : String
@export var token: String
@export var last_modified: String

@export var master_volume: = 0.0 :
	set(volume):
		master_volume = volume
		var ind: = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(ind, volume)

@export var music_volume: = 0.0 :
	set(volume):
		music_volume = volume
		var ind: = AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(ind, volume)

@export var voice_volume: = 0.0 :
	set(volume):
		voice_volume = volume
		var ind: = AudioServer.get_bus_index("Voice")
		AudioServer.set_bus_volume_db(ind, volume)

@export var effects_volume: = 0.0 :
	set(volume):
		effects_volume = volume
		var ind: = AudioServer.get_bus_index("Effects")
		AudioServer.set_bus_volume_db(ind, volume)

func update_from_dict(dict: Dictionary) -> void:
	account_type = dict.account_type
	education_method = dict.education_method
	email = dict.email
	token = dict.token
	last_modified = dict.last_modified
	
	students.clear()
	for device: String in dict.students.keys():
		var device_students: Array[StudentData] = []
		for s: Dictionary in dict.students[device]: 
			var student = StudentData.new()
			student.code = str(s.code)
			student.name = s.name
			student.age = s.age
			student.level = s.level
			device_students.append(student)
		
		students[int(device)] = device_students

func get_new_code() -> String :
	var used_codes = []
	for student_array in students.values():
		for student in student_array:
			used_codes.append(student.code)
	
	if used_codes.size() == available_codes.size():
		return ""
	
	var codes = available_codes.duplicate()
	for c in used_codes:
		codes.erase(c)
	
	var code : String = codes.pick_random()
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

func to_dict() -> Dictionary:
	var dict = {
		"account_type": account_type,
		"email": email,
		"password": password,
		"education_method": education_method,
	}
	
	dict["students"] = {}
	for device in students.keys():
		dict["students"][device] = []
		for s: StudentData in students[device]: 
			dict["students"][device].append(s.to_dict())
	
	return dict

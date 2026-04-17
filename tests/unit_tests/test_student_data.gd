extends GutTest

var default_student_data_dict: Dictionary = {
	"code": 0,
	"name": "",
	"level": StudentData.Level.BEGINNER,
	"age": 0,
	"last_modified": ""
}
var modified_student_data_dict: Dictionary = {
	"code": 123,
	"name": "Alice",
	"level": StudentData.Level.ADULT,
	"age": 7,
	"last_modified": Time.get_datetime_string_from_unix_time(12345)
}


func test_to_dict() -> void:
	var default_student: StudentData = StudentData.new()
	assert_eq_deep(default_student.to_dict(), default_student_data_dict)
	default_student.code = 123
	default_student.name = "Alice"
	default_student.level = StudentData.Level.ADULT
	default_student.age = 7
	default_student.last_modified = Time.get_datetime_string_from_unix_time(12345)
	assert_eq_deep(default_student.to_dict(), modified_student_data_dict)
	
	

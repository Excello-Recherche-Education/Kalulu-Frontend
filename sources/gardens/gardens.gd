extends Control

const garden_scene: = preload("res://resources/gardens/garden.tscn")
const garden_size: = 2400

@export var gardens_layout: GardensLayout:
	set = set_gardens_layout

@onready var garden_parent: = %GardenParent
@onready var locked_line: = $ScrollContainer/LockedLine
@onready var unlocked_line: = $ScrollContainer/UnlockedLine
@onready var scroll_container: = $ScrollContainer
@onready var parallax_background: = %ParallaxBackground

var lessons: = {}
var points: = []
var is_scrolling: = false
var scroll_beginning_garden: = 0
var tween: Tween


func _ready() -> void:
	if not gardens_layout:
		gardens_layout = load("res://resources/gardens/gardens_layout.tres")
	else:
		set_gardens_layout(gardens_layout)
	get_gardens_db_data()
	set_up_lessons()
	
	await get_tree().process_frame
	UserDataManager.student_progression.unlocks_changed.connect(_on_progression_unlocks_changed)
	_on_progression_unlocks_changed()


func _process(_delta: float) -> void:
	locked_line.position.x = - scroll_container.scroll_horizontal
	unlocked_line.position.x = - scroll_container.scroll_horizontal
	parallax_background.scroll_offset.x = - scroll_container.scroll_horizontal


func get_gardens_db_data() -> void:
	Database.db.query("Select Grapheme, Phoneme, LessonNb, GPID FROM Lessons
		INNER JOIN GPsInLessons ON GPsInLessons.LessonID = Lessons.ID
		INNER JOIN GPs ON GPsInLessons.GPID = GPs.ID
		ORDER BY LessonNb")
	for e in Database.db.query_result:
		if not lessons.has(e.LessonNb):
			lessons[e.LessonNb] = []
		lessons[e.LessonNb].append({grapheme = e.Grapheme, phoneme = e.Phoneme, gp_id = e.GPID})


func set_up_lessons() -> void:
	var lesson_ind: = 1
	for garden_control in garden_parent.get_children():
		for i in garden_control.lesson_button_controls.size():
			if not lesson_ind in lessons:
				break
			garden_control.set_lesson_label(i, lessons[lesson_ind][0].grapheme)
			garden_control.lesson_button_controls.pressed.connect(_on_garden_lesson_button_pressed.bind(lesson_ind))
			lesson_ind += 1


func set_gardens_layout(p_gardens_layout: GardensLayout) -> void:
	gardens_layout = p_gardens_layout
	add_gardens()
	if garden_parent:
		await get_tree().process_frame
	set_up_path()


func add_gardens() -> void:
	if not garden_parent:
		return
	for child in garden_parent.get_children():
		child.free()
	for garden_layout in gardens_layout.gardens:
		var garden: = garden_scene.instantiate()
		garden_parent.add_child(garden)
		garden.garden_layout = garden_layout


func set_up_path() -> void:
	if not garden_parent:
		return
	points = []
	var curve: = Curve2D.new()
	for i in gardens_layout.gardens.size():
		var garden_layout: = gardens_layout.gardens[i]
		var garden_control: = garden_parent.get_child(i)
		for lesson_button in garden_layout.lesson_buttons:
			var point_position: Vector2 = garden_parent.position + garden_control.position + Vector2(lesson_button.position)
			point_position += garden_control.get_button_size() / 2
			var point_in_position: = Vector2.ZERO
			if curve.point_count > 1:
				point_in_position = curve.get_point_position(curve.point_count - 1) + curve.get_point_out(curve.point_count - 1) - point_position
			curve.add_point(point_position, point_in_position, lesson_button.path_out_position)
			points.append([point_position, point_in_position, lesson_button.path_out_position])
	locked_line.points = curve.get_baked_points()


func _on_garden_lesson_button_pressed(_lesson_ind: int) -> void:
	pass


func _on_progression_unlocks_changed() -> void:
	if not garden_parent:
		return
	
	var lesson_ind: = 1
	for garden_control in garden_parent.get_children():
		if not lesson_ind in lessons:
			break
		var garden_unlocks: = 0.0
		var garden_total_unlocks: = 0.0
		for i in garden_control.lesson_button_controls.size():
			if not lesson_ind in lessons:
				break
			
			if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] >= UserProgression.Status.Unlocked:
				if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] == UserProgression.Status.Unlocked:
					garden_unlocks += 1.0
				if UserDataManager.student_progression.unlocks[lesson_ind]["look_and_learn"] == UserProgression.Status.Completed:
					garden_unlocks += 2.0
				garden_control.lesson_button_controls[i].disabled = false
			else:
				if ProjectSettings.get_setting_with_override("application/custom/unlock_everything"):
					garden_control.lesson_button_controls[i].disabled = false
				else:
					garden_control.lesson_button_controls[i].disabled = true
			
			garden_total_unlocks += 2.0
			
			for k in range(3):
				garden_total_unlocks += 2.0
				match UserDataManager.student_progression.unlocks[lesson_ind]["games"][k]:
					UserProgression.Status.Unlocked:
						garden_unlocks += 1.0
					UserProgression.Status.Completed:
						garden_unlocks += 2.0
			
			lesson_ind += 1
		
		var unlocks_ratio: = garden_unlocks / garden_total_unlocks
		var total_flowers: float = unlocks_ratio * garden_control.flower_controls.size() * 4.0
		var flower_ind: = 0
		while total_flowers > 0 and flower_ind < garden_control.flower_controls.size():
			if total_flowers >= 3.0:
				garden_control.flowers_sizes[flower_ind] = Garden.FlowerSizes.Large
				total_flowers -= 3.0
			elif total_flowers >= 2.0:
				garden_control.flowers_sizes[flower_ind] = Garden.FlowerSizes.Medium
				total_flowers -= 2.0
			elif total_flowers >= 1.0:
				garden_control.flowers_sizes[flower_ind] = Garden.FlowerSizes.Small
				total_flowers -= 1.0
			flower_ind += 1
		
		garden_control.update_flowers()
	
	lesson_ind = 1
	var curve: = Curve2D.new()
	for i in range(UserDataManager.student_progression.get_max_unlocked_lesson() + 1):
		curve.add_point(points[i][0], points[i][1], points[i][2])
	unlocked_line.points = curve.get_baked_points()


func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		is_scrolling = true
		scroll_beginning_garden = scroll_container.scroll_horizontal / garden_size
		if tween:
			tween.stop()
			tween = null
	elif event.is_action_released("left_click"):
		is_scrolling = false
		var shift_value: int = scroll_container.scroll_horizontal - scroll_beginning_garden * garden_size
		var target_scroll: int = scroll_beginning_garden * garden_size
		var is_garden_changed: = false
		if shift_value < - 400:
			target_scroll -= garden_size
			is_garden_changed = true
		elif shift_value > 400:
			target_scroll += garden_size
			is_garden_changed = true
		tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_SPRING)
		tween.tween_property(scroll_container, "scroll_horizontal", target_scroll, 1)
		if is_garden_changed:
			var garden_ind: int = target_scroll / garden_size
			garden_parent.get_child(garden_ind).pop_animation()
		
		
	if is_scrolling and event is InputEventMouseMotion:
		scroll_container.scroll_horizontal -= event.relative.x


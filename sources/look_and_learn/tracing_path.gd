extends Path2D

@onready var line: = $Line2D
@onready var guide_path_follow: = $GuidePathFollow

var color: = Color(1.0, 0.5, 0.5)
var width: = 50.0


func _process(_delta: float) -> void:
	var points: PackedVector2Array = []
	for i in range(0, int(guide_path_follow.progress), 10):
		var i_f: = float(i)
		var point: = curve.sample_baked(i_f)
		points.append(point)
	
	line.points = points
	line.default_color = color
	line.width = width

extends ProgressBar
class_name RegisterProgressBar

func set_value_with_tween(v : float) -> void:
	create_tween().tween_property(self, "value", v, 0.15).set_trans(Tween.TRANS_LINEAR)

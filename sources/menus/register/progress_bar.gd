extends ProgressBar
class_name RegisterProgressBar

func set_value_with_tween(new_value : float) -> void:
	create_tween().tween_property(self, "value", new_value, 0.15).set_trans(Tween.TRANS_LINEAR)

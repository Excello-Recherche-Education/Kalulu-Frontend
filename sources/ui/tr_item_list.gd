extends ItemList

func _ready() -> void:
	for index: int in self.item_count:
		self.set_item_text(index, tr(self.get_item_text(index)))

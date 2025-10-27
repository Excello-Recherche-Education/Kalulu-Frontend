extends ItemList


func _ready() -> void:
	for index: int in range(self.item_count):
		self.set_item_text(index, tr(self.get_item_text(index)))

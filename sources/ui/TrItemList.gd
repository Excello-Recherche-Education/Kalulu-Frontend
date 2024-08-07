extends ItemList
class_name TrItemLisst

func _ready():
	for i in self.item_count:
		self.set_item_text(i, tr(self.get_item_text(i)))

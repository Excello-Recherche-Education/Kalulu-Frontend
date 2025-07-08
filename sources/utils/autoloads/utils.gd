extends Node

func reorder_children_by_property(container: Node, property_name: String) -> void:
	var children: Array[Node] = container.get_children()
	children.sort_custom(Utils.sort_by_property.bind(property_name))
	for element: Node in container.get_children():
		container.remove_child(element)
	for element: Node in children:
		container.add_child(element)

func sort_by_property(node_a: Node, node_b: Node, property_name: String) -> bool:
	return node_a.get(property_name) < node_b.get(property_name)

func disconnect_all(signals: Signal) -> void:
	for connection: Dictionary in signals.get_connections():
		(connection["signal"] as Signal).disconnect(connection["callable"] as Callable)

func delete_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	var error: Error = DirAccess.get_open_error()
	if error != OK:
		Logger.warn("Utils: delete_dir error while opening path %s: %s" % [path, error_string(error)])
		return
	if dir == null:
		Logger.warn("Utils: delete_dir called on missing path %s" % path)
		return
	for file: String in dir.get_files():
		dir.remove(file)
	for subfolder: String in dir.get_directories():
		delete_dir(path.path_join(subfolder))
		dir.remove(subfolder)

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

func clean_dir(path: String) -> Error:
	var dir: DirAccess = DirAccess.open(path)
	var error: Error = DirAccess.get_open_error()
	if error != OK:
		return error
	if dir == null:
		return ERR_FILE_BAD_PATH
	for file: String in dir.get_files():
		dir.remove(file)
	for subfolder: String in dir.get_directories():
		error = clean_dir(path.path_join(subfolder))
		if error != OK:
			return error
		dir.remove(subfolder)
	return OK

func delete_directory_recursive(path: String) -> void:
	var err: Error = clean_dir(path)
	if err != OK:
		Logger.error("Utils: Error " + error_string(err) + " while cleaning folder: %s" % path)
		return
	err = DirAccess.remove_absolute(path)
	if err != OK:
		Logger.error("Utils: Error " + error_string(err) + " while deleting folder: %s" % path)
	else:
		Logger.info("Utils: Folder deleted: %s" % path)

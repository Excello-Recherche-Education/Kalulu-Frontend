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

class_name ProfToolUtils
extends RefCounted
## Small helpers that used to sit in the game's Utils autoload, which only the
## Prof Tool ever called. Keeping them there tied every Prof Tool screen to an
## autoload it will not have once it is its own project.


static func disconnect_all(disconnecting_signal: Signal) -> void:
	for connection: Dictionary in disconnecting_signal.get_connections():
		disconnecting_signal.disconnect(connection["callable"] as Callable)


## Re-adds the container's children sorted by one of their properties, so the
## tree order (and so the display order) follows it.
static func reorder_children_by_property(container: Node, property_name: String) -> void:
	var children: Array[Node] = container.get_children()
	children.sort_custom(func(node_a: Node, node_b: Node) -> bool:
		return node_a.get(property_name) < node_b.get(property_name))
	for element: Node in children:
		container.remove_child(element)
	for element: Node in children:
		container.add_child(element)

@tool
extends Control
class_name FormBinder

@export var data : Resource

var _control_binder_map: Dictionary = {}

func _ready():
	_find_binders(self)


func _find_binders(node: Node) -> void:
	for child in node.get_children():
		var control_binder = child as ControlBinder
		if control_binder:
			var parent = control_binder.get_parent()
			if parent:
				_control_binder_map[parent] = control_binder
		_find_binders(child)


func read(resource : Resource) -> void:
	if resource:
		data = resource
	
	if not data:
		return
	
	for control in _control_binder_map.keys():
		var binder = _control_binder_map[control]
		
		if binder.property_name in data:
			var property_value = data.get(binder.property_name)
			binder.set_value(property_value)
			#push_warning("Property typing and control doesn't match for property '" + binder.property_name + "' (" + str(property_value) + ") and " + str(binder.control))
		else:
			push_warning("Property " + binder.property_name + " not found in " + data.get_class())


func write() -> bool:
	if not data:
		return false
	
	for control in _control_binder_map.keys():
		var binder = _control_binder_map[control]
		if binder.property_name in data:
			data.set(binder.property_name, binder.get_value())
		else:
			push_warning("Property " + binder.property_name + " not found in " + data.get_class())
	
	return true

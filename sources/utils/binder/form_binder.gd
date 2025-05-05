@tool
extends Control
class_name FormBinder

@export var data : Resource

var _control_binder_map: Dictionary[Control, ControlBinder] = {}

func _ready() -> void:
	_find_binders(self)


func _find_binders(node: Node) -> void:
	for child: Node in node.get_children():
		var control_binder: ControlBinder = child as ControlBinder
		if control_binder:
			var parent: Control = control_binder.get_parent() as Control
			if parent:
				_control_binder_map[parent] = control_binder
		_find_binders(child)


func read(resource: Resource) -> void:
	if resource:
		data = resource
	
	if not data:
		return
	
	for control: Control in _control_binder_map.keys():
		var binder: ControlBinder = _control_binder_map[control]
		
		if binder.property_name in data:
			var property_value: Variant = data.get(binder.property_name)
			binder.set_value(property_value)
		else:
			Logger.warn("FormBinder: Property " + binder.property_name + " not found in " + data.get_class())


func write() -> bool:
	if not data:
		return false
	
	for control: Control in _control_binder_map.keys():
		var binder: ControlBinder = _control_binder_map[control]
		if binder.property_name in data:
			data.set(binder.property_name as StringName, binder.get_value())
		else:
			Logger.warn("FormBinder: Property " + str(binder.property_name) + " not found in " + data.get_class())
	
	return true

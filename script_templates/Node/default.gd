# meta-name: Default template
# meta-description: Base template for Node with default Godot cycle methods and GDScript conventions
# meta-default: true
# meta-space-indent: 4

#This is consistent with how C++ files are named in Godot's source code. This also avoids case sensitivity issues that can crop up when exporting a project from Windows to other platforms.
#File name     snake_case
#Functions     snake_case
#Variables     snake_case
#Signals       snake_case     Use the past tense to name signals (door_opened)
#Constants     CONSTANT_CASE
#Enum names    PascalCase     Write enums with each item on its own line. This allows better documentation comments and cleaner diffs in version control
#Enum members  CONSTANT_CASE  Keep them singular, as they represent a type

#01. @tool, @icon, @static_unload
#02. class_name PascalCase
extends _BASE_
#04. ## doc comment
## A brief description of the class's role and functionality.
##
## The description of the script, what it can do,
## and any further detail.

#05. signals
#06. enums
#07. constants
#08. static variables
#09. @export variables
#10. remaning regular variables
#11. @onready variables

#12. static_init
# Called automatically when the class is loaded, after the static variables have been initialized
static func _static_init():
	# my_static_var = 2
	# A static constructor cannot take arguments and must not return any value.
	pass


#13. remaining static methods
#14-1. overridden built-in virtual methods:
# Called upon creating the object in memory.
func _init():
	pass


# Called before _ready(). Called when the node enters the scene tree, likewise _exit_tree() is called when it exits the scene tree. 
func _enter_tree():
	pass


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# Called at a fixed interval, independent of the game's frame rate, to ensure stable and consistent physics calculations
func _physics_process(float) -> void:
	pass


#14-2. remaining virtual methods

#15. overridden custom methods
#16. remaining methods
#17. subclasses

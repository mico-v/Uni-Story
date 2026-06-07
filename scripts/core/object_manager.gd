class_name ObjectManager extends RefCounted

## Holds the named objects (`o`) and constants (`c`) that presentation scripts
## reference, e.g. `o.bg`, `o.fg`, `o.anim`, `c.resource_root`.
##
## Front-end controllers register their display nodes here via bind_object().

var objects: Dictionary = {}
var constants: Dictionary = {}


func bind_object(name: String, value: Variant) -> void:
	objects[name] = value


func set_constant(name: String, value: Variant) -> void:
	constants[name] = value

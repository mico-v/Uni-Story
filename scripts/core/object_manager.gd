class_name ObjectManager extends RefCounted

## Holds the named objects (`o`) and constants (`c`) that presentation scripts
## reference, e.g. `o.bg`, `o.fg`, `o.anim`, `c.resource_root`.
##
## Front-end controllers register their display nodes here via bind_object().

var objects: Dictionary = {}
var constants: Dictionary = {}


var _frozen_objects: bool = false
var _frozen_constants: bool = false


func bind_object(name: String, value: Variant) -> void:
	if _frozen_objects:
		push_warning("ObjectManager: write to objects is frozen, reject bind_object('%s')" % name)
		return
	objects[name] = value


## Internal registration entrypoint used by systems that must attach runtime objects
## (such as character composites) after freeze. It intentionally bypasses freeze
## checks because those objects are infrastructure-managed.
func bind_object_runtime(name: String, value: Variant) -> void:
	objects[name] = value


func set_constant(name: String, value: Variant) -> void:
	if _frozen_constants:
		push_warning("ObjectManager: write to constants is frozen, reject set_constant('%s')" % name)
		return
	constants[name] = value


func freeze_objects() -> void:
	_frozen_objects = true


func freeze_constants() -> void:
	_frozen_constants = true

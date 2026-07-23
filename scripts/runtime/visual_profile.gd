class_name VisualProfile extends Resource

## Project-owned visual aliases and conventions.
##
## Keep story-specific image aliases out of runtime engine code.

@export var image_aliases: Dictionary = {}


func resolve_image_alias(obj_name: String, image_name: String) -> String:
	var object_key: String = obj_name.strip_edges().to_lower()
	var image_key: String = image_name.strip_edges()
	var scoped_key: String = "%s:%s" % [object_key, image_key]
	if image_aliases.has(scoped_key):
		return str(image_aliases[scoped_key])
	if image_aliases.has(image_key):
		return str(image_aliases[image_key])
	return image_key

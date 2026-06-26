class_name StandingProfile extends Resource

## Data-driven standing-sprite configuration.
##
## Engine code should not know project character names, pose names, or imported
## sidecar data. A game project provides those through this Resource.

@export var character_root: String = "characters/"
@export var default_layer_order: Array[String] = ["body", "face", "eye", "eyebrow", "mouth", "hair", "blush", "sweat", "effect"]
@export var offset_sidecar_extension: String = ".asset"
@export var offset_pixels_per_unit: float = 100.0
@export var invert_sidecar_y: bool = true
@export var characters: Dictionary = {}


func has_character(character_name: String) -> bool:
	return characters.has(_key(character_name))


func character_directory(character_name: String) -> String:
	var cfg: Dictionary = _character_config(character_name)
	var directory: String = str(cfg.get("directory", ""))
	if directory.is_empty():
		directory = character_root.path_join(character_name)
	if not directory.ends_with("/"):
		directory += "/"
	return directory


func layer_order(character_name: String) -> Array[String]:
	var cfg: Dictionary = _character_config(character_name)
	var order = cfg.get("layer_order", default_layer_order)
	if order is Array:
		var result: Array[String] = []
		for item in order:
			result.append(str(item))
		return result
	return default_layer_order.duplicate()


func normalize_layers(character_name: String, raw_layers: Array) -> Array[String]:
	var layers: Array[String] = []
	for item in raw_layers:
		var layer: String = str(item).strip_edges()
		if not layer.is_empty():
			layers.append(layer)
	var order: Array[String] = layer_order(character_name)
	layers.sort_custom(func(a: String, b: String) -> bool:
		var a_idx: int = layer_order_index(order, a)
		var b_idx: int = layer_order_index(order, b)
		if a_idx == b_idx:
			return a < b
		return a_idx < b_idx
	)
	return layers


func resolve_pose_layers(character_name: String, pose: String) -> Array[String]:
	var value: String = pose.strip_edges()
	if value.is_empty():
		return []
	if value.find("+") != -1:
		return normalize_layers(character_name, value.split("+", false))
	var poses: Dictionary = _poses(character_name)
	if poses.has(value):
		var pose_value = poses[value]
		if pose_value is Array:
			return normalize_layers(character_name, pose_value)
		return normalize_layers(character_name, str(pose_value).split("+", false))
	return normalize_layers(character_name, [value])


func layer_group(character_name: String, layer_name: String) -> String:
	var layer: String = layer_name.strip_edges()
	if layer.is_empty():
		return ""
	var order: Array[String] = layer_order(character_name)
	for group in order:
		var group_name: String = str(group)
		if layer == group_name or layer.begins_with(group_name + "_"):
			return group_name
	var sep: int = layer.find("_")
	if sep > 0:
		return layer.substr(0, sep)
	return layer


func layer_order_index(order: Array[String], layer_name: String) -> int:
	var exact: int = order.find(layer_name)
	if exact != -1:
		return exact
	for i in range(order.size()):
		var group_name: String = order[i]
		if not group_name.is_empty() and layer_name.begins_with(group_name + "_"):
			return i
	return order.size()


func layer_offset(resource_root: String, character_name: String, layer_name: String) -> Vector2:
	var sidecar: Variant = _load_sidecar_offset(resource_root, character_name, layer_name)
	if sidecar is Vector2:
		return sidecar
	var cfg: Dictionary = _character_config(character_name)
	var offsets = cfg.get("offsets", {})
	if offsets is Dictionary:
		if offsets.has(layer_name):
			return _to_vector2(offsets[layer_name])
		var group_name: String = layer_group(character_name, layer_name)
		if offsets.has(group_name):
			return _to_vector2(offsets[group_name])
	return Vector2.ZERO


func _load_sidecar_offset(resource_root: String, character_name: String, layer_name: String) -> Variant:
	if offset_sidecar_extension.strip_edges().is_empty():
		return null
	var path: String = resource_root.path_join(character_directory(character_name)).path_join(layer_name + offset_sidecar_extension)
	var absolute: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	var text: String = FileAccess.get_file_as_string(absolute)
	if text.is_empty():
		return null
	var rx: RegEx = RegEx.new()
	if rx.compile(r"offset:\s*\{x:\s*([-0-9.]+),\s*y:\s*([-0-9.]+),\s*z:\s*([-0-9.]+)\}") != OK:
		return null
	var match: RegExMatch = rx.search(text)
	if match == null:
		return null
	var y: float = float(match.get_string(2)) * offset_pixels_per_unit
	if invert_sidecar_y:
		y = -y
	return Vector2(float(match.get_string(1)) * offset_pixels_per_unit, y)


func _character_config(character_name: String) -> Dictionary:
	var cfg = characters.get(_key(character_name), {})
	if cfg is Dictionary:
		return cfg
	return {}


func _poses(character_name: String) -> Dictionary:
	var cfg: Dictionary = _character_config(character_name)
	var poses = cfg.get("poses", {})
	if poses is Dictionary:
		return poses
	return {}


func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var arr: Array = value
		var x: float = float(arr[0]) if arr.size() > 0 else 0.0
		var y: float = float(arr[1]) if arr.size() > 1 else 0.0
		return Vector2(x, y)
	return Vector2.ZERO


func _key(character_name: String) -> String:
	return character_name.strip_edges().to_lower()

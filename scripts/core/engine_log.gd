class_name EngineLog extends RefCounted

## Small logging facade for engine subsystems.
##
## It keeps categories consistent while still using Godot's native console
## reporting, so headless tests and editor output continue to behave normally.

enum Category { PARSE, RUNTIME, SAVE, ASSET, CONFIG, RESTORE, UI }


static func info(category: int, source: String, message: String) -> void:
	print(_format(category, source, message))


static func warn(category: int, source: String, message: String) -> void:
	push_warning(_format(category, source, message))


static func error(category: int, source: String, message: String) -> void:
	push_error(_format(category, source, message))


static func _format(category: int, source: String, message: String) -> String:
	return "[%s][%s] %s" % [_category_name(category), source, message]


static func _category_name(category: int) -> String:
	match category:
		Category.PARSE:
			return "parse"
		Category.RUNTIME:
			return "runtime"
		Category.SAVE:
			return "save"
		Category.ASSET:
			return "asset"
		Category.CONFIG:
			return "config"
		Category.RESTORE:
			return "restore"
		Category.UI:
			return "ui"
		_:
			return "general"

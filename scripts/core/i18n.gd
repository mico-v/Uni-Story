class_name I18n

## Small locale lookup utility for ui text.
##
## - locale: requested locale name, e.g. "zh", "en"
## - supported_locales: allowed locale list
## - localized_resources_path: folder containing <locale>.json files.
##
## Dictionaries are loaded lazily and cached.

var supported_locales: Array = ["zh", "en"]
var localized_resources_path: String = "res://resources/localized_resources/localized_strings/"
var localized_asset_root: String = "res://resources/LocalizedResources/"
var fallback_locale: String = "en"
var locale: String = "zh"

var _tables: Dictionary = {}


func _normalize_locale(value: String) -> String:
	var normalized := value.to_lower().strip_edges()
	if normalized.is_empty():
		normalized = fallback_locale
	return normalized


func setup(supported: Array, resources_path: String, default_locale: String, fallback: String = "en") -> void:
	supported_locales = supported.duplicate()
	localized_resources_path = resources_path
	fallback_locale = fallback
	locale = _normalize_locale(default_locale)
	if locale not in supported_locales:
		locale = supported_locales[0] if supported_locales.size() > 0 else fallback_locale
	_load_locale(locale)
	if _normalize_locale(fallback) != locale:
		_load_locale(fallback)


func set_locale(requested_locale: String) -> void:
	var resolved := _resolve_locale(requested_locale)
	locale = resolved
	_load_locale(resolved)


func _resolve_locale(requested_locale: String) -> String:
	var candidate := _normalize_locale(requested_locale)
	if candidate in supported_locales:
		return candidate
	if fallback_locale in supported_locales:
		return fallback_locale
	if supported_locales.size() > 0:
		return str(supported_locales[0])
	return "en"


func _load_locale(locale_name: String) -> void:
	var locale_key := str(locale_name)
	if _tables.has(locale_key):
		return

	var normalized_path := localized_resources_path.rstrip("/")
	var path := normalized_path + "/" + locale_key + ".json"
	if not FileAccess.file_exists(path):
		_tables[locale_key] = {}
		return

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_tables[locale_key] = parsed
	else:
		push_warning("I18n: invalid dictionary in %s" % path)
		_tables[locale_key] = {}


func t(key: String, default_value: String = "") -> String:
	var lookup := [locale, fallback_locale]
	if locale != fallback_locale:
		# Ensure fallback chain only applies once.
		lookup = [locale, fallback_locale]

	for loc in lookup:
		if not _tables.has(loc):
			_load_locale(loc)
		var data = _tables.get(loc, {})
		if data.has(key):
			return str(data[key])

	if not default_value.is_empty():
		return default_value
	return key


## Return a scenario path that is locale-specific when exists.
## Lookup order:
##   1. Nova-style asset localization: res://resources/LocalizedResources/{Locale}/{relative_path}
##      (e.g. res://resources/scenarios/ch1.txt + "en" =>
##       res://resources/LocalizedResources/English/scenarios/ch1.txt)
##   2. Suffix form in the same directory: ch1_en.txt
##   3. Fallback locale suffix, then the original path.
func load_scenario(locale_name: String, source_path: String) -> String:
	var loc := _resolve_locale(locale_name)
	if loc.is_empty() or source_path.is_empty():
		return source_path

	# 1. Nova-style LocalizedResources/{display_name}/{relative_path}.
	var asset_localized := _try_localized_asset_path(loc, source_path)
	if not asset_localized.is_empty():
		return asset_localized

	# 2. Suffix form: basename_locale.ext in the same directory.
	var ext := source_path.get_extension()
	if ext.is_empty():
		return source_path

	var base := source_path.get_basename()
	var suffix := "_%s.%s" % [loc, ext]
	var localized := base + suffix
	if FileAccess.file_exists(localized):
		return localized

	# 3. Fall back to default-locale suffix if present.
	var fallbacked := base + "_%s.%s" % [fallback_locale, ext]
	if loc != fallback_locale and FileAccess.file_exists(fallbacked):
		return fallbacked

	return source_path


## Resolve a locale-specific asset path under the LocalizedResources root.
## Returns an empty string when no localized override exists.
func _try_localized_asset_path(loc: String, source_path: String) -> String:
	# The default locale ships assets in-place; no LocalizedResources override.
	if loc == locale and loc == supported_locales[0]:
		return ""
	var display_name := _locale_display_name(loc)
	if display_name.is_empty():
		return ""
	var prefix := "res://resources/"
	if not source_path.begins_with(prefix):
		return ""
	var rel_path := source_path.substr(prefix.length())
	var candidate := localized_asset_root.trim_suffix("/") + "/" + display_name + "/" + rel_path
	if FileAccess.file_exists(candidate):
		return candidate
	return ""


## Map a locale code to the LocalizedResources sub-directory name used by Nova.
func _locale_display_name(loc: String) -> String:
	match loc.to_lower():
		"en":
			return "English"
		"zh", "chinesesimplified":
			return "Chinese"
		_:
			return loc.capitalize()

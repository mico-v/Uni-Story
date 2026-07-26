@tool
extends EditorInspectorPlugin

## Inspector plugin that scans resources for UI transition properties.
##
## When a UI scene (.tscn) or script resource is inspected,
## this plugin scans for common transition/tween/animation properties
## and displays them in a summary section.


## Known transition property name patterns
const TRANSITION_PROPS := [
	"transition_",
	"tween_",
	"anim_",
	"fade_",
	"slide_",
	"ease_",
	"duration",
	"delay",
]

## Known transition method name patterns
const TRANSITION_METHODS := [
	"play_animation",
	"start_tween",
	"fade_in",
	"fade_out",
	"slide_in",
	"slide_out",
	"tween_property",
]


func _can_handle(object: Object) -> bool:
	# Handle Resource types that may have transition properties
	if object is Resource:
		return true
	return false


func _parse_begin(object: Object) -> void:
	if not (object is Resource):
		return

	var found_props: Array[String] = []
	var found_methods: Array[String] = []

	# Scan properties
	for prop in object.get_property_list():
		var prop_name: String = prop["name"]
		for pattern in TRANSITION_PROPS:
			if prop_name.to_lower().contains(pattern):
				found_props.append(prop_name)
				break

	# Scan methods
	for method in object.get_method_list():
		var method_name: String = method["name"]
		for pattern in TRANSITION_METHODS:
			if method_name.to_lower().contains(pattern):
				found_methods.append(method_name)
				break

	if found_props.is_empty() and found_methods.is_empty():
		return

	# Summary label
	var summary := Label.new()
	summary.text = "UI Transition Properties: %d props, %d methods" % [found_props.size(), found_methods.size()]
	add_custom_control(summary)

	# Props section if any
	if not found_props.is_empty():
		var props_label := Label.new()
		props_label.text = "  Properties: " + ", ".join(found_props.slice(0, 5))
		props_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_custom_control(props_label)

	# Methods section if any
	if not found_methods.is_empty():
		var methods_label := Label.new()
		methods_label.text = "  Methods: " + ", ".join(found_methods.slice(0, 5))
		methods_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_custom_control(methods_label)

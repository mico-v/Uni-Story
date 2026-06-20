class_name FlowChartGraph extends RefCounted

## Collection of FlowChartNode keyed by name, plus the start/unlocked sets.

var nodes: Dictionary = {}            # StringName -> FlowChartNode
var start_nodes: Array = []           # Array[StringName]
var unlocked_start_nodes: Array = []  # Array[StringName]


func clear() -> void:
	nodes.clear()
	start_nodes.clear()
	unlocked_start_nodes.clear()


func add_node(node) -> void:
	nodes[node.name] = node


func has_node_named(name: StringName) -> bool:
	return nodes.has(name)


func get_node_named(name: StringName):
	return nodes.get(name)


## Resolve start/unlocked sets and verify graph integrity.
## Returns: array of error strings.
func sanity_check() -> Array:
	var errors: Array = []
	start_nodes.clear()
	unlocked_start_nodes.clear()
	if nodes.is_empty():
		errors.append("FlowChart: graph has no nodes")

	for n in nodes.values():
		if n.is_start:
			start_nodes.append(n.name)
		if n.is_unlocked_start:
			unlocked_start_nodes.append(n.name)

	if unlocked_start_nodes.is_empty():
		unlocked_start_nodes = start_nodes.duplicate()

	if start_nodes.is_empty() and unlocked_start_nodes.is_empty():
		errors.append("FlowChart: no start node found")

	for n in nodes.values():
		if n.jump_target != &"" and not nodes.has(n.jump_target):
			errors.append("FlowChart: unknown jump_to target '%s' in node '%s'" % [n.jump_target, n.name])
		for b in n.branches:
			var raw_dest = b.get("dest", "")
			if typeof(raw_dest) == TYPE_STRING || typeof(raw_dest) == TYPE_STRING_NAME:
				var bdest = StringName(raw_dest)
				if not nodes.has(bdest):
					errors.append("FlowChart: unknown branch dest '%s' in node '%s'" % [str(bdest), n.name])
			else:
				errors.append("FlowChart: invalid branch dest '%s' in node '%s'" % [str(raw_dest), n.name])

	return errors

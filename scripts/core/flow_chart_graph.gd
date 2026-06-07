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


## Resolve start/unlocked sets and verify every jump/branch target exists.
func sanity_check() -> void:
	start_nodes.clear()
	unlocked_start_nodes.clear()
	for n in nodes.values():
		if n.is_start:
			start_nodes.append(n.name)
		if n.is_unlocked_start:
			unlocked_start_nodes.append(n.name)

	if unlocked_start_nodes.is_empty():
		unlocked_start_nodes = start_nodes.duplicate()

	for n in nodes.values():
		if n.jump_target != &"" and not nodes.has(n.jump_target):
			push_error("FlowChart: unknown jump_to target '%s' in node '%s'" % [n.jump_target, n.name])
		for b in n.branches:
			if not nodes.has(b["dest"]):
				push_error("FlowChart: unknown branch dest '%s' in node '%s'" % [b["dest"], n.name])

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

	# Detect cycles via DFS.
	var cycle_errors := _detect_cycles()
	errors.append_array(cycle_errors)

	return errors


## DFS-based cycle detection. Returns array of error strings describing
## each unique cycle found in the graph.
func _detect_cycles() -> Array:
	var errors: Array = []
	# 0 = white (unvisited), 1 = gray (in stack), 2 = black (done)
	var color: Dictionary = {}
	var parent: Dictionary = {}
	for n in nodes.values():
		color[n.name] = 0
		parent[n.name] = &""

	for n in nodes.values():
		if color[n.name] == 0:
			_dfs_visit(n.name, color, parent, errors)

	return errors


func _dfs_visit(node_name: StringName, color: Dictionary, parent: Dictionary, errors: Array) -> void:
	color[node_name] = 1  # gray

	var node = nodes.get(node_name)
	if node == null:
		color[node_name] = 2
		return

	var neighbors: Array = []
	if node.jump_target != &"":
		neighbors.append(node.jump_target)
	for b in node.branches:
		if b is Dictionary:
			var dest := StringName(str(b.get("dest", "")))
			if dest != &"":
				neighbors.append(dest)

	for next_node in neighbors:
		if not color.has(next_node):
			continue
		if color[next_node] == 1:
			# Back edge found — reconstruct the cycle path.
			var cycle: Array = [str(next_node)]
			var cur := node_name
			while cur != next_node:
				cycle.append(str(cur))
				cur = parent.get(cur, &"")
				if cur == &"":
					break
			cycle.append(str(next_node))
			cycle.reverse()
			errors.append("FlowChart: cycle detected: %s" % " -> ".join(cycle))
		elif color[next_node] == 0:
			parent[next_node] = node_name
			_dfs_visit(next_node, color, parent, errors)

	color[node_name] = 2  # black

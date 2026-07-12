class_name ScenarioStatistics extends RefCounted

## Aggregates a ScenarioAnalysis IR into a stable dialogue statistics report.

const NORMALIZATION_VERSION := "visible_v1"
const LENGTH_UNIT := "unicode_codepoints"


func build(analysis: Dictionary, top: int = 10) -> Dictionary:
	var entries: Array = analysis.get("entries", [])
	var silent_entries: Array = analysis.get("silent_entries", [])
	var nodes: Array = analysis.get("nodes", [])
	var files: Array = analysis.get("files", [])
	var blocks: Array = analysis.get("blocks", [])
	var edges: Array = analysis.get("edges", [])
	var lengths: Array[int] = []
	var spoken := 0
	var total_characters := 0
	var empty := 0
	var canonical_speakers: Dictionary = {}
	var display_speakers: Dictionary = {}
	var dynamic_speaker_entries := 0
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		var length := int(entry.get("length", 0))
		lengths.append(length)
		total_characters += length
		if length == 0:
			empty += 1
		if bool(entry.get("has_speaker", false)):
			spoken += 1
			canonical_speakers[str(entry.get("canonical_speaker", ""))] = true
			display_speakers[str(entry.get("display_speaker", ""))] = true
			if bool(entry.get("dynamic_speaker", false)):
				dynamic_speaker_entries += 1
	lengths.sort()

	var eager_blocks := 0
	var lazy_blocks := 0
	for raw_block in blocks:
		var block: Dictionary = raw_block
		if str(block.get("type", "")) == "eager":
			eager_blocks += 1
		elif str(block.get("type", "")) == "lazy":
			lazy_blocks += 1
	var local_nodes := 0
	var node_types := {"normal": 0, "chapter": 0, "end": 0}
	var starts := 0
	var unlocked_starts := 0
	var debug_nodes := 0
	for raw_node in nodes:
		var node: Dictionary = raw_node
		if bool(node.get("local", false)):
			local_nodes += 1
		var node_type := str(node.get("type", "normal"))
		node_types[node_type] = int(node_types.get(node_type, 0)) + 1
		if bool(node.get("is_start", false)):
			starts += 1
		if bool(node.get("is_unlocked_start", false)):
			unlocked_starts += 1
		if bool(node.get("is_debug", false)):
			debug_nodes += 1
	var jumps := 0
	var branch_options := 0
	for raw_edge in edges:
		var edge: Dictionary = raw_edge
		if str(edge.get("kind", "")) == "branch":
			branch_options += 1
		else:
			jumps += 1

	var summary := _metrics(lengths)
	summary.merge({
		"files": files.size(),
		"blocks": blocks.size(),
		"eager_blocks": eager_blocks,
		"lazy_blocks": lazy_blocks,
		"nodes": nodes.size(),
		"local_nodes": local_nodes,
		"node_types": node_types,
		"dialogues": entries.size(),
		"silent_entries": silent_entries.size(),
		"runtime_entries": entries.size() + silent_entries.size(),
		"spoken": spoken,
		"narration": entries.size() - spoken,
		"speakers": canonical_speakers.size(),
		"display_speakers": display_speakers.size(),
		"dynamic_speaker_entries": dynamic_speaker_entries,
		"total_characters": total_characters,
		"empty": empty,
		"starts": starts,
		"unlocked_starts": unlocked_starts,
		"debug_nodes": debug_nodes,
		"jumps": jumps,
		"branch_options": branch_options,
		"transitions": jumps + branch_options,
	}, true)

	return {
		"schema_version": 1,
		"normalization": NORMALIZATION_VERSION,
		"length_unit": LENGTH_UNIT,
		"summary": summary,
		"length_histogram": _length_histogram(lengths),
		"by_file": _by_file(files, nodes, entries),
		"by_node": _by_node(nodes, entries),
		"by_speaker": _by_speaker(entries),
		"longest": _longest(entries, maxi(top, 0)),
	}


func _metrics(sorted_lengths: Array[int]) -> Dictionary:
	var count := sorted_lengths.size()
	var total := 0
	for length in sorted_lengths:
		total += length
	return {
		"min": sorted_lengths.front() if count > 0 else 0,
		"max": sorted_lengths.back() if count > 0 else 0,
		"mean": float(total) / float(count) if count > 0 else 0.0,
		"median": _nearest_rank(sorted_lengths, 0.5),
		"p50": _nearest_rank(sorted_lengths, 0.5),
		"p90": _nearest_rank(sorted_lengths, 0.9),
		"p95": _nearest_rank(sorted_lengths, 0.95),
	}


func _nearest_rank(sorted_lengths: Array[int], percentile: float) -> int:
	if sorted_lengths.is_empty():
		return 0
	var rank := ceili(percentile * sorted_lengths.size())
	return sorted_lengths[clampi(rank - 1, 0, sorted_lengths.size() - 1)]


func _length_histogram(lengths: Array[int]) -> Array[Dictionary]:
	var counts: Dictionary = {}
	for length in lengths:
		counts[length] = int(counts.get(length, 0)) + 1
	var keys: Array[int] = []
	for key in counts.keys():
		keys.append(int(key))
	keys.sort()
	var out: Array[Dictionary] = []
	for length in keys:
		out.append({"length": length, "count": int(counts[length])})
	return out


func _by_file(files: Array, nodes: Array, entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw_file in files:
		var file: Dictionary = raw_file
		var path := str(file.get("path", ""))
		var selected_entries: Array[Dictionary] = []
		for raw_entry in entries:
			var entry: Dictionary = raw_entry
			if str(entry.get("path", "")) == path:
				selected_entries.append(entry)
		var node_count := 0
		for raw_node in nodes:
			if str((raw_node as Dictionary).get("path", "")) == path:
				node_count += 1
		var item := _group_metrics(selected_entries)
		item["path"] = path
		item["nodes"] = node_count
		out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("path", "")) < str(b.get("path", "")))
	return out


func _by_node(nodes: Array, entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw_node in nodes:
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		var selected_entries: Array[Dictionary] = []
		for raw_entry in entries:
			var entry: Dictionary = raw_entry
			if str(entry.get("node", "")) == node_id:
				selected_entries.append(entry)
		var item := _group_metrics(selected_entries)
		item.merge({
			"node": node_id,
			"raw_node": str(node.get("raw_name", "")),
			"display_name": str(node.get("display_name", "")),
			"path": str(node.get("path", "")),
			"line": int(node.get("line", 0)),
			"local": bool(node.get("local", false)),
			"type": str(node.get("type", "normal")),
		}, true)
		out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_path := str(a.get("path", ""))
		var b_path := str(b.get("path", ""))
		if a_path != b_path:
			return a_path < b_path
		var a_line := int(a.get("line", 0))
		var b_line := int(b.get("line", 0))
		return a_line < b_line if a_line != b_line else str(a.get("node", "")) < str(b.get("node", ""))
	)
	return out


func _by_speaker(entries: Array) -> Array[Dictionary]:
	var groups: Dictionary = {}
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if not bool(entry.get("has_speaker", false)):
			continue
		var canonical := str(entry.get("canonical_speaker", ""))
		if not groups.has(canonical):
			groups[canonical] = {"entries": [], "displays": {}}
		var group: Dictionary = groups[canonical]
		var group_entries: Array = group.get("entries", [])
		group_entries.append(entry)
		var displays: Dictionary = group.get("displays", {})
		displays[str(entry.get("display_speaker", ""))] = true
	var names: Array[String] = []
	for name in groups.keys():
		names.append(str(name))
	names.sort()
	var out: Array[Dictionary] = []
	for canonical in names:
		var group: Dictionary = groups[canonical]
		var selected: Array[Dictionary] = []
		for raw_entry in group.get("entries", []):
			selected.append(raw_entry as Dictionary)
		var display_names: Array[String] = []
		for display in (group.get("displays", {}) as Dictionary).keys():
			display_names.append(str(display))
		display_names.sort()
		var item := _group_metrics(selected)
		item["canonical_speaker"] = canonical
		item["display_speakers"] = display_names
		item["display_names"] = display_names.duplicate()
		item["dynamic"] = selected.any(func(entry: Dictionary) -> bool: return bool(entry.get("dynamic_speaker", false)))
		out.append(item)
	return out


func _group_metrics(entries: Array[Dictionary]) -> Dictionary:
	var lengths: Array[int] = []
	var spoken := 0
	var speakers: Dictionary = {}
	var characters := 0
	for entry in entries:
		var length := int(entry.get("length", 0))
		lengths.append(length)
		characters += length
		if bool(entry.get("has_speaker", false)):
			spoken += 1
			speakers[str(entry.get("canonical_speaker", ""))] = true
	lengths.sort()
	var result := _metrics(lengths)
	result.merge({
		"dialogues": entries.size(),
		"spoken": spoken,
		"narration": entries.size() - spoken,
		"speakers": speakers.size(),
		"characters": characters,
	}, true)
	return result


func _longest(entries: Array, top: int) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for raw_entry in entries:
		sorted.append(raw_entry as Dictionary)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_length := int(a.get("length", 0))
		var b_length := int(b.get("length", 0))
		if a_length != b_length:
			return a_length > b_length
		var a_path := str(a.get("path", ""))
		var b_path := str(b.get("path", ""))
		if a_path != b_path:
			return a_path < b_path
		var a_line := int(a.get("line", 0))
		var b_line := int(b.get("line", 0))
		return a_line < b_line if a_line != b_line else str(a.get("node", "")) < str(b.get("node", ""))
	)
	var out: Array[Dictionary] = []
	for i in range(mini(top, sorted.size())):
		var entry := sorted[i]
		out.append({
			"path": str(entry.get("path", "")),
			"line": int(entry.get("line", 0)),
			"node": str(entry.get("node", "")),
			"display_speaker": str(entry.get("display_speaker", "")),
			"canonical_speaker": str(entry.get("canonical_speaker", "")),
			"text": str(entry.get("raw_text", "")),
			"normalized_text": str(entry.get("normalized_text", "")),
			"length": int(entry.get("length", 0)),
		})
	return out

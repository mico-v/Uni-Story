class_name ScenarioVisualization extends RefCounted

## Builds deterministic flow/branch graph reports from ScenarioAnalysis IR.
##
## The builder never executes scenario code. Text, JSON, Graphviz DOT, and
## Mermaid renderers all consume the same schema-versioned report.

const GRAPH_SCHEMA_VERSION := 1
const KIND := "scenario_flow"
const ANALYSIS_MODE := "execution_free_static"

const FLAG_ORDER := [
	"start", "unlocked_start", "debug", "save_point", "chapter", "end", "local",
]
const CLASS_ORDER := [
	"root", "source", "sink", "isolated", "merge", "branch_point",
	"choice_point", "auto_branch", "reachable", "unreachable",
	"explicit_end", "implicit_terminal", "cycle", "self_loop",
]
const PLACEHOLDER_ORDER := {
	"external": 0,
	"missing": 1,
	"dynamic": 2,
	"filtered": 3,
}
const EDGE_KIND_ORDER := {
	"jump_to": 0,
	"jump_if": 1,
	"branch": 2,
}


func build(analysis: Dictionary, raw_options: Dictionary = {}) -> Dictionary:
	var options := _normalize_options(raw_options)
	var diagnostics: Array[Dictionary] = []
	if not bool(analysis.get("ok", false)):
		for raw_error in analysis.get("errors", []):
			if raw_error is Dictionary:
				var error: Dictionary = raw_error
				diagnostics.append({
					"severity": "error",
					"code": "analysis.failed",
					"message": str(error.get("message", "scenario analysis failed")),
					"location": _location(error),
				})
		return _empty_report(analysis, options, diagnostics)

	var source_nodes: Array = analysis.get("nodes", [])
	var source_edges: Array = analysis.get("edges", [])
	var node_rank: Dictionary = {}
	var source_node_by_id: Dictionary = {}
	for i in range(source_nodes.size()):
		var raw_node = source_nodes[i]
		if not (raw_node is Dictionary):
			continue
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		if node_id.is_empty() or source_node_by_id.has(node_id):
			continue
		node_rank[node_id] = i
		source_node_by_id[node_id] = node

	var context_by_id := _context_catalog(analysis)
	var normalized_edges := _normalize_edges(source_edges, source_node_by_id, context_by_id)
	var full_degrees := _degrees(source_node_by_id.keys(), normalized_edges, source_node_by_id)
	var resolved_roots := _resolve_roots(options, source_node_by_id, full_degrees, diagnostics)
	if _has_error(diagnostics):
		return _empty_report(analysis, options, diagnostics)
	var full_adjacency := _defined_adjacency(source_node_by_id.keys(), normalized_edges, source_node_by_id)
	var full_reachable := _reachable_ids(resolved_roots.get("ids", []), full_adjacency)

	var visible: Dictionary = {}
	for node_id in source_node_by_id.keys():
		visible[str(node_id)] = true
	_apply_node_filters(visible, source_node_by_id, normalized_edges, full_reachable, options)
	for root_id in resolved_roots.get("ids", []):
		if source_node_by_id.has(str(root_id)):
			visible[str(root_id)] = true

	var selected_edges: Array[Dictionary] = []
	var placeholder_specs: Dictionary = {}
	for raw_edge in normalized_edges:
		var edge: Dictionary = raw_edge.duplicate(true)
		var source := str(edge.get("source", ""))
		if not visible.has(source) or not _edge_matches(edge, options):
			continue
		var target_kind := str(edge.get("target_kind", "missing"))
		var target := str(edge.get("target", ""))
		if target_kind == "defined" and not visible.has(target):
			if str(options.get("boundary", "include")) == "drop":
				continue
			var filtered_id := "filtered:%s" % target
			placeholder_specs[filtered_id] = {
				"id": filtered_id,
				"placeholder_kind": "filtered",
				"display_name": str((source_node_by_id.get(target, {}) as Dictionary).get("display_name", target)),
				"original_id": target,
				"location": _location(source_node_by_id.get(target, {})),
			}
			edge["target"] = filtered_id
			edge["target_kind"] = "filtered"
		elif target_kind != "defined":
			if str(options.get("boundary", "include")) == "drop":
				continue
			placeholder_specs[target] = _placeholder_spec(edge, context_by_id)
		selected_edges.append(edge)

	var visible_ids: Array[String] = []
	for node_id in visible.keys():
		visible_ids.append(str(node_id))
	visible_ids.sort_custom(func(a: String, b: String) -> bool: return int(node_rank.get(a, 1 << 30)) < int(node_rank.get(b, 1 << 30)))
	var selected_node_by_id: Dictionary = {}
	for node_id in visible_ids:
		selected_node_by_id[node_id] = source_node_by_id[node_id]

	var selected_degrees := _degrees(visible_ids, selected_edges, selected_node_by_id)
	var selected_adjacency := _defined_adjacency(visible_ids, selected_edges, selected_node_by_id)
	var selected_roots: Array[String] = []
	var root_reasons: Dictionary = resolved_roots.get("reasons", {})
	for root_id in resolved_roots.get("ids", []):
		if selected_node_by_id.has(str(root_id)):
			selected_roots.append(str(root_id))
	var selected_reachable := _reachable_ids(selected_roots, selected_adjacency)
	var weak_data := _weak_components(visible_ids, selected_adjacency, node_rank)
	var scc_data := _strong_components(visible_ids, selected_adjacency, node_rank)
	var metrics := _node_metrics(analysis)

	var dot_id_by_node: Dictionary = {}
	var report_nodes: Array[Dictionary] = []
	for i in range(visible_ids.size()):
		var node_id := visible_ids[i]
		dot_id_by_node[node_id] = "n%06d" % (i + 1)
		report_nodes.append(_defined_node_report(
			node_id,
			source_node_by_id[node_id],
			str(dot_id_by_node[node_id]),
			selected_degrees,
			metrics,
			selected_roots,
			selected_reachable,
			weak_data,
			scc_data,
			selected_edges
		))

	var placeholder_ids: Array[String] = []
	for placeholder_id in placeholder_specs.keys():
		placeholder_ids.append(str(placeholder_id))
	placeholder_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_spec: Dictionary = placeholder_specs[a]
		var b_spec: Dictionary = placeholder_specs[b]
		var a_order := int(PLACEHOLDER_ORDER.get(str(a_spec.get("placeholder_kind", "missing")), 99))
		var b_order := int(PLACEHOLDER_ORDER.get(str(b_spec.get("placeholder_kind", "missing")), 99))
		return a < b if a_order == b_order else a_order < b_order
	)
	for placeholder_id in placeholder_ids:
		var dot_id := "n%06d" % (report_nodes.size() + 1)
		dot_id_by_node[placeholder_id] = dot_id
		report_nodes.append(_placeholder_node_report(placeholder_specs[placeholder_id], dot_id, selected_edges))

	var report_edges: Array[Dictionary] = []
	for edge in selected_edges:
		var out_edge: Dictionary = edge.duplicate(true)
		out_edge["source_dot_id"] = str(dot_id_by_node.get(str(edge.get("source", "")), ""))
		out_edge["target_dot_id"] = str(dot_id_by_node.get(str(edge.get("target", "")), ""))
		report_edges.append(out_edge)

	for edge in report_edges:
		var target_kind := str(edge.get("target_kind", "defined"))
		if target_kind in ["missing", "dynamic"]:
			diagnostics.append({
				"severity": "warning",
				"code": "flow.%s_target" % target_kind,
				"message": "transition target is %s" % target_kind,
				"edge": str(edge.get("id", "")),
				"location": (edge.get("location", {}) as Dictionary).duplicate(true),
			})

	var roots_out: Array[Dictionary] = []
	for root_id in selected_roots:
		roots_out.append({"node": root_id, "reason": str(root_reasons.get(root_id, "root"))})

	var summary := _summary(analysis, report_nodes, report_edges, selected_roots, selected_reachable, weak_data, scc_data)
	return {
		"schema_version": GRAPH_SCHEMA_VERSION,
		"kind": KIND,
		"analysis_mode": ANALYSIS_MODE,
		"source_ir": {
			"schema_version": int(analysis.get("schema_version", 0)),
			"normalization": str(analysis.get("normalization", "")),
		},
		"ok": not _has_error(diagnostics),
		"options": options.duplicate(true),
		"summary": summary,
		"roots": roots_out,
		"nodes": report_nodes,
		"edges": report_edges,
		"weak_components": weak_data.get("components", []),
		"sccs": scc_data.get("components", []),
		"diagnostics": diagnostics,
	}


func render_text(report: Dictionary) -> String:
	var summary: Dictionary = report.get("summary", {})
	var lines := PackedStringArray()
	lines.append("ScenarioVisualize: files=%d defined=%d placeholders=%d edges=%d branches=%d" % [
		int(summary.get("files", 0)),
		int(summary.get("defined_nodes", 0)),
		int(summary.get("placeholder_nodes", 0)),
		int(summary.get("edges", 0)),
		int(summary.get("branch_edges", 0)),
	])
	lines.append("Flow: roots=%d reachable=%d unreachable=%d components=%d sccs=%d cyclic=%d" % [
		int(summary.get("roots", 0)),
		int(summary.get("reachable_defined", 0)),
		int(summary.get("unreachable_defined", 0)),
		int(summary.get("weak_components", 0)),
		int(summary.get("sccs", 0)),
		int(summary.get("cyclic_sccs", 0)),
	])
	var roots: Array = report.get("roots", [])
	if not roots.is_empty():
		var rendered_roots := PackedStringArray()
		for raw_root in roots:
			var root: Dictionary = raw_root
			rendered_roots.append("%s (%s)" % [root.get("node", ""), root.get("reason", "")])
		lines.append("Roots: %s" % ", ".join(rendered_roots))
	var diagnostics: Array = report.get("diagnostics", [])
	if not diagnostics.is_empty():
		lines.append("Diagnostics:")
		for raw_diagnostic in diagnostics:
			var diagnostic: Dictionary = raw_diagnostic
			var location: Dictionary = diagnostic.get("location", {})
			lines.append("  %s:%d:%d: %s [%s] %s" % [
				location.get("path", ""), int(location.get("line", 0)), int(location.get("column", 1)),
				diagnostic.get("severity", "warning"), diagnostic.get("code", ""), diagnostic.get("message", ""),
			])
	lines.append("Nodes:")
	var outgoing: Dictionary = {}
	for raw_edge in report.get("edges", []):
		var edge: Dictionary = raw_edge
		var source := str(edge.get("source", ""))
		if not outgoing.has(source):
			outgoing[source] = []
		var source_edges: Array = outgoing[source]
		source_edges.append(edge)
	for raw_node in report.get("nodes", []):
		var node: Dictionary = raw_node
		var flags: Array = node.get("flags", [])
		var shown_flags: Array[String] = []
		if "root" in node.get("classes", []):
			shown_flags.append("root")
		for flag in flags:
			shown_flags.append(str(flag))
		var prefix := ""
		if not shown_flags.is_empty():
			prefix = "[%s] " % ",".join(PackedStringArray(shown_flags))
		var location: Dictionary = node.get("location", {})
		var metrics: Dictionary = node.get("metrics", {})
		var degree: Dictionary = node.get("degree", {})
		lines.append("  %s%s \"%s\" %s:%d dialogues=%d in=%d out=%d" % [
			prefix, node.get("id", ""), node.get("display_name", ""), location.get("path", ""),
			int(location.get("line", 0)), int(metrics.get("dialogues", 0)),
			int(degree.get("in_edges", 0)), int(degree.get("out_edges", 0)),
		])
		for raw_edge in outgoing.get(str(node.get("id", "")), []):
			var edge: Dictionary = raw_edge
			lines.append("    %s -> %s (%s)" % [_edge_text(edge), edge.get("target", ""), edge.get("target_kind", "")])
	return "\n".join(lines) + "\n"


func render_dot(report: Dictionary) -> String:
	var options: Dictionary = report.get("options", {})
	var lines := PackedStringArray([
		"digraph scenario_flow {",
		"  graph [rankdir=LR, charset=\"UTF-8\", labelloc=t, label=\"Scenario flow\"];",
		"  node [fontname=\"sans-serif\", fontsize=10];",
		"  edge [fontname=\"sans-serif\", fontsize=9];",
	])
	var nodes: Array = report.get("nodes", [])
	if str(options.get("cluster", "file")) == "file":
		var by_path: Dictionary = {}
		var placeholders: Array[Dictionary] = []
		for raw_node in nodes:
			var node: Dictionary = raw_node
			if not bool(node.get("defined", false)):
				placeholders.append(node)
				continue
			var path := str((node.get("location", {}) as Dictionary).get("path", ""))
			if not by_path.has(path):
				by_path[path] = []
			var path_nodes: Array = by_path[path]
			path_nodes.append(node)
		var paths: Array[String] = []
		for path in by_path.keys():
			paths.append(str(path))
		paths.sort()
		for i in range(paths.size()):
			var path := paths[i]
			lines.append("  subgraph cluster_%06d {" % (i + 1))
			lines.append("    label=\"%s\";" % _dot_escape(path))
			lines.append("    color=\"#d0d7de\";")
			for raw_node in by_path[path]:
				lines.append("    %s" % _dot_node(raw_node, options))
			lines.append("  }")
		for node in placeholders:
			lines.append("  %s" % _dot_node(node, options))
	else:
		for raw_node in nodes:
			lines.append("  %s" % _dot_node(raw_node, options))
	for raw_edge in report.get("edges", []):
		var edge: Dictionary = raw_edge
		lines.append("  %s -> %s%s;" % [edge.get("source_dot_id", ""), edge.get("target_dot_id", ""), _dot_edge_attributes(edge, options)])
	lines.append("}")
	return "\n".join(lines) + "\n"


func render_mermaid(report: Dictionary) -> String:
	var options: Dictionary = report.get("options", {})
	var lines := PackedStringArray(["flowchart LR"])
	for raw_node in report.get("nodes", []):
		var node: Dictionary = raw_node
		var node_id := str(node.get("dot_id", ""))
		var label := _mermaid_escape(_node_label(node, options))
		var kind := str(node.get("placeholder_kind", ""))
		if kind == "dynamic":
			lines.append("  %s{\"%s\"}" % [node_id, label])
		elif str(node.get("type", "")) == "end":
			lines.append("  %s((\"%s\"))" % [node_id, label])
		else:
			lines.append("  %s[\"%s\"]" % [node_id, label])
	for raw_edge in report.get("edges", []):
		var edge: Dictionary = raw_edge
		var label := _mermaid_escape(_truncate(_edge_text(edge), int(options.get("max_label_chars", 80))))
		var arrow := "-.->" if str(edge.get("kind", "")) == "jump_if" else "-->"
		lines.append("  %s %s|%s| %s" % [edge.get("source_dot_id", ""), arrow, label, edge.get("target_dot_id", "")])
	lines.append("  classDef start fill:#d1f7c4,stroke:#238636;")
	lines.append("  classDef end fill:#f6f8fa,stroke:#8250df,stroke-width:2px;")
	lines.append("  classDef external fill:#f6f8fa,stroke:#57606a,stroke-dasharray:5 5;")
	lines.append("  classDef missing fill:#ffebe9,stroke:#cf222e;")
	lines.append("  classDef dynamic fill:#fff8c5,stroke:#9a6700;")
	lines.append("  classDef unreachable fill:#ffebe9,stroke:#cf222e;")
	for raw_node in report.get("nodes", []):
		var node: Dictionary = raw_node
		var classes: Array[String] = []
		if "root" in node.get("classes", []):
			classes.append("start")
		if str(node.get("type", "")) == "end":
			classes.append("end")
		var placeholder_kind := str(node.get("placeholder_kind", ""))
		if placeholder_kind in ["external", "missing", "dynamic"]:
			classes.append(placeholder_kind)
		if "unreachable" in node.get("classes", []) and bool(node.get("defined", false)):
			classes.append("unreachable")
		if not classes.is_empty():
			lines.append("  class %s %s;" % [node.get("dot_id", ""), ",".join(PackedStringArray(classes))])
	return "\n".join(lines) + "\n"


func _normalize_options(raw: Dictionary) -> Dictionary:
	return {
		"view": _enum_value(str(raw.get("view", "flow")), ["flow", "branches"], "flow"),
		"root_policy": _enum_value(str(raw.get("root_policy", "auto")), ["auto", "start", "unlocked", "debug", "sources", "all"], "auto"),
		"roots": _sorted_unique_strings(raw.get("roots", [])),
		"reachable_only": bool(raw.get("reachable_only", false)),
		"exclude_debug": bool(raw.get("exclude_debug", false)),
		"node_globs": _sorted_unique_strings(raw.get("node_globs", [])),
		"edge_kinds": _sorted_unique_strings(raw.get("edge_kinds", [])),
		"phases": _sorted_unique_strings(raw.get("phases", [])),
		"boundary": _enum_value(str(raw.get("boundary", "include")), ["include", "drop"], "include"),
		"context_mode": str(raw.get("context_mode", "auto")),
		"cluster": _enum_value(str(raw.get("cluster", "file")), ["none", "file"], "file"),
		"label": _enum_value(str(raw.get("label", "both")), ["id", "display", "both"], "both"),
		"max_label_chars": maxi(int(raw.get("max_label_chars", 80)), 0),
	}


func _empty_report(analysis: Dictionary, options: Dictionary, diagnostics: Array[Dictionary]) -> Dictionary:
	return {
		"schema_version": GRAPH_SCHEMA_VERSION,
		"kind": KIND,
		"analysis_mode": ANALYSIS_MODE,
		"source_ir": {"schema_version": int(analysis.get("schema_version", 0)), "normalization": str(analysis.get("normalization", ""))},
		"ok": false,
		"options": options.duplicate(true),
		"summary": {
			"files": int((analysis.get("summary", {}) as Dictionary).get("files", 0)),
			"defined_nodes": 0, "placeholder_nodes": 0, "nodes": 0, "edges": 0,
			"roots": 0, "reachable_defined": 0, "unreachable_defined": 0,
			"weak_components": 0, "sccs": 0, "cyclic_sccs": 0,
			"jump_to_edges": 0, "jump_if_edges": 0, "branch_edges": 0,
			"missing_targets": 0, "external_targets": 0, "dynamic_targets": 0, "filtered_targets": 0,
		},
		"roots": [], "nodes": [], "edges": [], "weak_components": [], "sccs": [], "diagnostics": diagnostics,
	}


func _normalize_edges(source_edges: Array, node_by_id: Dictionary, context_by_id: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(source_edges.size()):
		if not (source_edges[i] is Dictionary):
			continue
		var raw: Dictionary = source_edges[i]
		var edge_id := "e%06d" % (out.size() + 1)
		var kind := str(raw.get("kind", "jump_to"))
		var raw_target := str(raw.get("raw_target", raw.get("target", "")))
		var resolved_target := str(raw.get("target", ""))
		var raw_target_kind := str(raw.get("target_kind", "literal"))
		var target_kind := "dynamic" if raw_target_kind == "dynamic" else ("defined" if node_by_id.has(resolved_target) else ("external" if context_by_id.has(resolved_target) else "missing"))
		var target := "dynamic:%s" % edge_id if target_kind == "dynamic" else resolved_target
		var condition_raw := str(raw.get("condition_raw", ""))
		var condition_normalized := str(raw.get("condition_normalized", condition_raw)).strip_edges()
		var branch = null
		if kind == "branch":
			branch = {
				"group_id": str(raw.get("group_id", "")),
				"option_index": int(raw.get("option_index", 0)),
				"text": str(raw.get("text", "")),
				"mode": str(raw.get("mode", "normal")),
				"condition_raw": condition_raw,
				"condition_normalized": condition_normalized,
				"image_raw": str(raw.get("image_raw", "")),
				"fallback": str(raw.get("mode", "normal")) == "jump" and condition_raw.strip_edges().is_empty(),
			}
		out.append({
			"id": edge_id,
			"source": str(raw.get("source", "")),
			"target": target,
			"original_target": resolved_target,
			"raw_target": raw_target,
			"target_kind": target_kind,
			"target_expression": str(raw.get("target_expression", "")),
			"kind": kind,
			"phase": str(raw.get("phase", "eager")),
			"stage": str(raw.get("stage", "")),
			"role": "transition",
			"location": _location(raw),
			"guard": {
				"kind": "conditional" if not condition_raw.strip_edges().is_empty() else "unconditional",
				"raw": condition_raw,
				"normalized": condition_normalized,
			},
			"branch": branch,
			"entry_id": str(raw.get("entry_id", "")),
			"classes": [],
		})
	return out


func _context_catalog(analysis: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_label in analysis.get("context_labels", []):
		if raw_label is Dictionary:
			var label: Dictionary = raw_label
			var label_id := str(label.get("id", ""))
			if not label_id.is_empty():
				out[label_id] = label
	return out


func _resolve_roots(options: Dictionary, node_by_id: Dictionary, degrees: Dictionary, diagnostics: Array[Dictionary]) -> Dictionary:
	var ids: Array[String] = []
	var reasons: Dictionary = {}
	var explicit: Array = options.get("roots", [])
	if not explicit.is_empty():
		for selector_raw in explicit:
			var selector := str(selector_raw)
			var matches := _match_root(selector, node_by_id)
			if matches.is_empty():
				diagnostics.append({"severity": "error", "code": "root.not_found", "message": "root selector '%s' did not match a node" % selector, "location": {"path": "", "line": 0, "column": 1}})
			elif matches.size() > 1:
				diagnostics.append({"severity": "error", "code": "root.ambiguous", "message": "root selector '%s' matched multiple nodes: %s" % [selector, ", ".join(PackedStringArray(matches))], "location": {"path": "", "line": 0, "column": 1}})
			else:
				var node_id := str(matches.front())
				if node_id not in ids:
					ids.append(node_id)
				reasons[node_id] = "explicit"
		return {"ids": ids, "reasons": reasons}
	var policy := str(options.get("root_policy", "auto"))
	var candidates: Array[String] = []
	var reason := policy
	for node_id in node_by_id.keys():
		var node: Dictionary = node_by_id[node_id]
		var include := false
		match policy:
			"start": include = bool(node.get("is_start", false))
			"unlocked": include = bool(node.get("is_unlocked_start", false))
			"debug": include = bool(node.get("is_debug", false))
			"sources": include = int(((degrees.get(node_id, {}) as Dictionary).get("in_edges", 0))) == 0
			"all": include = true
			_:
				include = bool(node.get("is_start", false)) or (bool(node.get("is_debug", false)) and int(((degrees.get(node_id, {}) as Dictionary).get("out_edges", 0))) > 0)
		if include and bool(options.get("exclude_debug", false)) and bool(node.get("is_debug", false)) and not bool(node.get("is_start", false)):
			include = false
		if include:
			candidates.append(str(node_id))
	if policy == "auto" and candidates.is_empty():
		reason = "sources"
		for node_id in node_by_id.keys():
			var node: Dictionary = node_by_id[node_id]
			if int(((degrees.get(node_id, {}) as Dictionary).get("in_edges", 0))) == 0 and not (bool(options.get("exclude_debug", false)) and bool(node.get("is_debug", false))):
				candidates.append(str(node_id))
	if policy == "auto" and candidates.is_empty():
		reason = "all"
		for node_id in node_by_id.keys():
			var node: Dictionary = node_by_id[node_id]
			if not (bool(options.get("exclude_debug", false)) and bool(node.get("is_debug", false))):
				candidates.append(str(node_id))
	for node_id in candidates:
		ids.append(node_id)
		if policy == "auto" and reason == "auto":
			var node: Dictionary = node_by_id[node_id]
			reasons[node_id] = "start" if bool(node.get("is_start", false)) else "debug"
		else:
			reasons[node_id] = reason
	return {"ids": ids, "reasons": reasons}


func _match_root(selector: String, node_by_id: Dictionary) -> Array[String]:
	if node_by_id.has(selector):
		return [selector]
	var matches: Array[String] = []
	for node_id in node_by_id.keys():
		var node: Dictionary = node_by_id[node_id]
		if str(node.get("raw_name", "")) == selector or str(node.get("display_name", "")) == selector:
			matches.append(str(node_id))
	matches.sort()
	return matches


func _apply_node_filters(visible: Dictionary, node_by_id: Dictionary, edges: Array[Dictionary], reachable: Dictionary, options: Dictionary) -> void:
	var branch_nodes: Dictionary = {}
	if str(options.get("view", "flow")) == "branches":
		for edge in edges:
			if str(edge.get("kind", "")) == "branch":
				branch_nodes[str(edge.get("source", ""))] = true
				if str(edge.get("target_kind", "")) == "defined":
					branch_nodes[str(edge.get("target", ""))] = true
	for node_id in visible.keys().duplicate():
		var node: Dictionary = node_by_id[node_id]
		var keep := true
		if bool(options.get("exclude_debug", false)) and bool(node.get("is_debug", false)) and not bool(node.get("is_start", false)):
			keep = false
		if keep and str(options.get("view", "flow")) == "branches" and not branch_nodes.has(str(node_id)):
			keep = false
		var globs: Array = options.get("node_globs", [])
		if keep and not globs.is_empty():
			keep = false
			for pattern in globs:
				if _glob_match(str(node_id), str(pattern)):
					keep = true
					break
		if keep and bool(options.get("reachable_only", false)) and not reachable.has(str(node_id)):
			keep = false
		if not keep:
			visible.erase(node_id)


func _edge_matches(edge: Dictionary, options: Dictionary) -> bool:
	if str(options.get("view", "flow")) == "branches" and str(edge.get("kind", "")) != "branch":
		return false
	var kinds: Array = options.get("edge_kinds", [])
	if not kinds.is_empty() and str(edge.get("kind", "")) not in kinds:
		return false
	var phases: Array = options.get("phases", [])
	return phases.is_empty() or str(edge.get("phase", "eager")) in phases


func _defined_node_report(node_id: String, source: Dictionary, dot_id: String, degrees: Dictionary, metrics: Dictionary, roots: Array[String], reachable: Dictionary, weak_data: Dictionary, scc_data: Dictionary, edges: Array[Dictionary]) -> Dictionary:
	var degree: Dictionary = degrees.get(node_id, {"in_edges": 0, "out_edges": 0, "in_neighbors": 0, "out_neighbors": 0})
	var flags := _node_flags(source)
	var classes: Array[String] = []
	if node_id in roots:
		classes.append("root")
	if int(degree.get("in_edges", 0)) == 0:
		classes.append("source")
	if int(degree.get("out_edges", 0)) == 0:
		classes.append("sink")
	if int(degree.get("in_edges", 0)) == 0 and int(degree.get("out_edges", 0)) == 0:
		classes.append("isolated")
	if int(degree.get("in_neighbors", 0)) > 1:
		classes.append("merge")
	if int(degree.get("out_neighbors", 0)) > 1:
		classes.append("branch_point")
	var has_choice := false
	var has_auto := false
	var self_loop := false
	for edge in edges:
		if str(edge.get("source", "")) != node_id:
			continue
		if str(edge.get("kind", "")) == "branch":
			var branch: Dictionary = edge.get("branch", {})
			if str(branch.get("mode", "normal")) == "jump":
				has_auto = true
			else:
				has_choice = true
		if str(edge.get("target", "")) == node_id:
			self_loop = true
	if has_choice:
		classes.append("choice_point")
	if has_auto:
		classes.append("auto_branch")
	classes.append("reachable" if reachable.has(node_id) else "unreachable")
	if str(source.get("type", "normal")) == "end":
		classes.append("explicit_end")
	elif int(degree.get("out_edges", 0)) == 0:
		classes.append("implicit_terminal")
	var scc_id := str((scc_data.get("by_node", {}) as Dictionary).get(node_id, ""))
	if bool((scc_data.get("cyclic", {}) as Dictionary).get(scc_id, false)):
		classes.append("cycle")
	if self_loop:
		classes.append("self_loop")
	classes = _ordered_values(classes, CLASS_ORDER)
	return {
		"id": node_id,
		"dot_id": dot_id,
		"defined": true,
		"placeholder_kind": "",
		"raw_name": str(source.get("raw_name", "")),
		"display_name": str(source.get("display_name", node_id)),
		"namespace": str(source.get("namespace", "")),
		"scope": "local" if bool(source.get("local", false)) else "global",
		"type": str(source.get("type", "normal")),
		"end_name": str(source.get("end_name", "")),
		"location": _location(source),
		"flags": flags,
		"classes": classes,
		"metrics": (metrics.get(node_id, {"dialogues": 0, "silent_entries": 0, "spoken": 0, "narration": 0}) as Dictionary).duplicate(true),
		"degree": degree.duplicate(true),
		"component": {
			"weak": str((weak_data.get("by_node", {}) as Dictionary).get(node_id, "")),
			"scc": scc_id,
		},
	}


func _placeholder_node_report(spec: Dictionary, dot_id: String, edges: Array[Dictionary]) -> Dictionary:
	var node_id := str(spec.get("id", ""))
	var in_edges := 0
	for edge in edges:
		if str(edge.get("target", "")) == node_id:
			in_edges += 1
	var kind := str(spec.get("placeholder_kind", "missing"))
	return {
		"id": node_id,
		"dot_id": dot_id,
		"defined": false,
		"placeholder_kind": kind,
		"raw_name": str(spec.get("original_id", node_id)),
		"display_name": str(spec.get("display_name", spec.get("original_id", node_id))),
		"namespace": "",
		"scope": "placeholder",
		"type": "placeholder",
		"end_name": "",
		"location": (spec.get("location", {}) as Dictionary).duplicate(true),
		"flags": [],
		"classes": ["%s_target" % kind],
		"metrics": {"dialogues": 0, "silent_entries": 0, "spoken": 0, "narration": 0},
		"degree": {"in_edges": in_edges, "out_edges": 0, "in_neighbors": in_edges, "out_neighbors": 0},
		"component": {"weak": "", "scc": ""},
	}


func _placeholder_spec(edge: Dictionary, context_by_id: Dictionary) -> Dictionary:
	var kind := str(edge.get("target_kind", "missing"))
	var target := str(edge.get("target", ""))
	if kind == "external":
		var context: Dictionary = context_by_id.get(str(edge.get("original_target", target)), {})
		return {
			"id": target, "placeholder_kind": "external",
			"display_name": str(context.get("display_name", edge.get("original_target", target))),
			"original_id": str(edge.get("original_target", target)), "location": _location(context),
		}
	if kind == "dynamic":
		return {
			"id": target, "placeholder_kind": "dynamic",
			"display_name": str(edge.get("target_expression", "dynamic target")),
			"original_id": str(edge.get("target_expression", "")), "location": (edge.get("location", {}) as Dictionary).duplicate(true),
		}
	return {
		"id": target, "placeholder_kind": "missing",
		"display_name": str(edge.get("original_target", target)),
		"original_id": str(edge.get("original_target", target)), "location": (edge.get("location", {}) as Dictionary).duplicate(true),
	}


func _summary(analysis: Dictionary, nodes: Array[Dictionary], edges: Array[Dictionary], roots: Array[String], reachable: Dictionary, weak_data: Dictionary, scc_data: Dictionary) -> Dictionary:
	var defined := 0
	var placeholders := 0
	var counts := {"jump_to": 0, "jump_if": 0, "branch": 0}
	var target_counts := {"missing": 0, "external": 0, "dynamic": 0, "filtered": 0}
	for node in nodes:
		if bool(node.get("defined", false)):
			defined += 1
		else:
			placeholders += 1
	for edge in edges:
		var kind := str(edge.get("kind", "jump_to"))
		counts[kind] = int(counts.get(kind, 0)) + 1
		var target_kind := str(edge.get("target_kind", "defined"))
		if target_counts.has(target_kind):
			target_counts[target_kind] = int(target_counts[target_kind]) + 1
	var reachable_defined := 0
	for node in nodes:
		if bool(node.get("defined", false)) and reachable.has(str(node.get("id", ""))):
			reachable_defined += 1
	var cyclic_sccs := 0
	for component in scc_data.get("components", []):
		if bool((component as Dictionary).get("cyclic", false)):
			cyclic_sccs += 1
	return {
		"files": int((analysis.get("summary", {}) as Dictionary).get("files", 0)),
		"defined_nodes": defined,
		"placeholder_nodes": placeholders,
		"nodes": nodes.size(),
		"edges": edges.size(),
		"roots": roots.size(),
		"reachable_defined": reachable_defined,
		"unreachable_defined": defined - reachable_defined,
		"weak_components": (weak_data.get("components", []) as Array).size(),
		"sccs": (scc_data.get("components", []) as Array).size(),
		"cyclic_sccs": cyclic_sccs,
		"jump_to_edges": int(counts.jump_to),
		"jump_if_edges": int(counts.jump_if),
		"branch_edges": int(counts.branch),
		"missing_targets": int(target_counts.missing),
		"external_targets": int(target_counts.external),
		"dynamic_targets": int(target_counts.dynamic),
		"filtered_targets": int(target_counts.filtered),
	}


func _node_metrics(analysis: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_node in analysis.get("nodes", []):
		if raw_node is Dictionary:
			out[str((raw_node as Dictionary).get("id", ""))] = {"dialogues": 0, "silent_entries": 0, "spoken": 0, "narration": 0}
	for raw_entry in analysis.get("entries", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var node_id := str(entry.get("node", ""))
		if not out.has(node_id):
			continue
		var metrics: Dictionary = out[node_id]
		metrics["dialogues"] = int(metrics.dialogues) + 1
		if bool(entry.get("has_speaker", false)):
			metrics["spoken"] = int(metrics.spoken) + 1
		else:
			metrics["narration"] = int(metrics.narration) + 1
	for raw_entry in analysis.get("silent_entries", []):
		if raw_entry is Dictionary:
			var node_id := str((raw_entry as Dictionary).get("node", ""))
			if out.has(node_id):
				var metrics: Dictionary = out[node_id]
				metrics["silent_entries"] = int(metrics.silent_entries) + 1
	return out


func _degrees(node_ids: Array, edges: Array[Dictionary], node_by_id: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var in_neighbors: Dictionary = {}
	var out_neighbors: Dictionary = {}
	for raw_id in node_ids:
		var node_id := str(raw_id)
		out[node_id] = {"in_edges": 0, "out_edges": 0, "in_neighbors": 0, "out_neighbors": 0}
		in_neighbors[node_id] = {}
		out_neighbors[node_id] = {}
	for edge in edges:
		var source := str(edge.get("source", ""))
		var target := str(edge.get("target", ""))
		if out.has(source):
			var source_degree: Dictionary = out[source]
			source_degree["out_edges"] = int(source_degree.out_edges) + 1
			(out_neighbors[source] as Dictionary)[target] = true
		if out.has(target):
			var target_degree: Dictionary = out[target]
			target_degree["in_edges"] = int(target_degree.in_edges) + 1
			(in_neighbors[target] as Dictionary)[source] = true
	for node_id in out.keys():
		var degree: Dictionary = out[node_id]
		degree["in_neighbors"] = (in_neighbors[node_id] as Dictionary).size()
		degree["out_neighbors"] = (out_neighbors[node_id] as Dictionary).size()
	return out


func _defined_adjacency(node_ids: Array, edges: Array[Dictionary], node_by_id: Dictionary) -> Dictionary:
	var adjacency: Dictionary = {}
	for raw_id in node_ids:
		adjacency[str(raw_id)] = []
	for edge in edges:
		var source := str(edge.get("source", ""))
		var target := str(edge.get("target", ""))
		if not adjacency.has(source) or not node_by_id.has(target):
			continue
		var neighbors: Array = adjacency[source]
		if target not in neighbors:
			neighbors.append(target)
	for node_id in adjacency.keys():
		var neighbors: Array = adjacency[node_id]
		neighbors.sort()
	return adjacency


func _reachable_ids(roots: Array, adjacency: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var pending: Array[String] = []
	for raw_root in roots:
		pending.append(str(raw_root))
	while not pending.is_empty():
		var node_id := str(pending.pop_back())
		if visited.has(node_id) or not adjacency.has(node_id):
			continue
		visited[node_id] = true
		var neighbors: Array = adjacency[node_id]
		for i in range(neighbors.size() - 1, -1, -1):
			if not visited.has(str(neighbors[i])):
				pending.append(str(neighbors[i]))
	return visited


func _weak_components(node_ids: Array[String], adjacency: Dictionary, rank: Dictionary) -> Dictionary:
	var undirected: Dictionary = {}
	for node_id in node_ids:
		undirected[node_id] = []
	for source in adjacency.keys():
		for raw_target in adjacency[source]:
			var target := str(raw_target)
			_add_unique(undirected[source], target)
			_add_unique(undirected[target], str(source))
	var visited: Dictionary = {}
	var components: Array[Dictionary] = []
	var by_node: Dictionary = {}
	for node_id in node_ids:
		if visited.has(node_id):
			continue
		var members: Array[String] = []
		var pending: Array[String] = [node_id]
		while not pending.is_empty():
			var current := str(pending.pop_back())
			if visited.has(current):
				continue
			visited[current] = true
			members.append(current)
			var neighbors: Array = undirected[current]
			neighbors.sort_custom(func(a, b) -> bool: return int(rank.get(str(a), 1 << 30)) < int(rank.get(str(b), 1 << 30)))
			for i in range(neighbors.size() - 1, -1, -1):
				if not visited.has(str(neighbors[i])):
					pending.append(str(neighbors[i]))
		members.sort_custom(func(a: String, b: String) -> bool: return int(rank.get(a, 1 << 30)) < int(rank.get(b, 1 << 30)))
		var component_id := "w%04d" % (components.size() + 1)
		for member in members:
			by_node[member] = component_id
		components.append({"id": component_id, "nodes": members})
	return {"components": components, "by_node": by_node}


func _strong_components(node_ids: Array[String], adjacency: Dictionary, rank: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var finish: Array[String] = []
	for node_id in node_ids:
		_dfs_finish(node_id, adjacency, visited, finish)
	var reverse: Dictionary = {}
	for node_id in node_ids:
		reverse[node_id] = []
	for source in adjacency.keys():
		for raw_target in adjacency[source]:
			_add_unique(reverse[str(raw_target)], str(source))
	for node_id in reverse.keys():
		var neighbors: Array = reverse[node_id]
		neighbors.sort_custom(func(a, b) -> bool: return int(rank.get(str(a), 1 << 30)) < int(rank.get(str(b), 1 << 30)))
	visited.clear()
	var raw_components: Array[Array] = []
	for i in range(finish.size() - 1, -1, -1):
		var node_id := finish[i]
		if visited.has(node_id):
			continue
		var members: Array[String] = []
		_dfs_collect(node_id, reverse, visited, members)
		members.sort_custom(func(a: String, b: String) -> bool: return int(rank.get(a, 1 << 30)) < int(rank.get(b, 1 << 30)))
		raw_components.append(members)
	raw_components.sort_custom(func(a: Array, b: Array) -> bool: return int(rank.get(str(a.front()), 1 << 30)) < int(rank.get(str(b.front()), 1 << 30)))
	var components: Array[Dictionary] = []
	var by_node: Dictionary = {}
	var cyclic: Dictionary = {}
	for members in raw_components:
		var component_id := "s%04d" % (components.size() + 1)
		var is_cyclic := members.size() > 1
		if not is_cyclic and not members.is_empty():
			is_cyclic = str(members.front()) in adjacency.get(str(members.front()), [])
		for member in members:
			by_node[str(member)] = component_id
		cyclic[component_id] = is_cyclic
		components.append({"id": component_id, "nodes": members, "cyclic": is_cyclic})
	return {"components": components, "by_node": by_node, "cyclic": cyclic}


func _dfs_finish(node_id: String, adjacency: Dictionary, visited: Dictionary, finish: Array[String]) -> void:
	if visited.has(node_id):
		return
	visited[node_id] = true
	for raw_neighbor in adjacency.get(node_id, []):
		_dfs_finish(str(raw_neighbor), adjacency, visited, finish)
	finish.append(node_id)


func _dfs_collect(node_id: String, adjacency: Dictionary, visited: Dictionary, members: Array[String]) -> void:
	if visited.has(node_id):
		return
	visited[node_id] = true
	members.append(node_id)
	for raw_neighbor in adjacency.get(node_id, []):
		_dfs_collect(str(raw_neighbor), adjacency, visited, members)


func _node_flags(node: Dictionary) -> Array[String]:
	var flags: Array[String] = []
	if bool(node.get("is_start", false)):
		flags.append("start")
	if bool(node.get("is_unlocked_start", false)):
		flags.append("unlocked_start")
	if bool(node.get("is_debug", false)):
		flags.append("debug")
	if bool(node.get("is_save_point", false)):
		flags.append("save_point")
	if str(node.get("type", "normal")) == "chapter":
		flags.append("chapter")
	if str(node.get("type", "normal")) == "end":
		flags.append("end")
	if bool(node.get("local", false)):
		flags.append("local")
	return _ordered_values(flags, FLAG_ORDER)


func _location(source: Variant) -> Dictionary:
	var value: Dictionary = source if source is Dictionary else {}
	return {
		"path": str(value.get("path", "")),
		"line": int(value.get("line", 0)),
		"column": int(value.get("column", 1)),
	}


func _dot_node(node: Dictionary, options: Dictionary) -> String:
	var attributes := PackedStringArray()
	attributes.append("label=\"%s\"" % _dot_escape(_node_label(node, options)))
	var location: Dictionary = node.get("location", {})
	attributes.append("tooltip=\"%s\"" % _dot_escape("%s:%d:%d" % [location.get("path", ""), int(location.get("line", 0)), int(location.get("column", 1))]))
	var placeholder_kind := str(node.get("placeholder_kind", ""))
	if placeholder_kind == "external":
		attributes.append("shape=box")
		attributes.append("style=\"dashed\"")
		attributes.append("color=\"#57606a\"")
	elif placeholder_kind == "missing":
		attributes.append("shape=octagon")
		attributes.append("color=\"#cf222e\"")
	elif placeholder_kind == "dynamic":
		attributes.append("shape=diamond")
		attributes.append("color=\"#9a6700\"")
	elif placeholder_kind == "filtered":
		attributes.append("shape=box")
		attributes.append("style=\"dashed\"")
		attributes.append("color=\"#8c959f\"")
	elif str(node.get("type", "normal")) == "end":
		attributes.append("shape=doublecircle")
	elif str(node.get("type", "normal")) == "chapter":
		attributes.append("shape=box")
	else:
		attributes.append("shape=ellipse")
	if "root" in node.get("classes", []):
		attributes.append("style=\"filled\"")
		attributes.append("fillcolor=\"#d1f7c4\"")
	if "unreachable" in node.get("classes", []) and bool(node.get("defined", false)):
		attributes.append("color=\"#cf222e\"")
	return "%s [%s];" % [node.get("dot_id", ""), ", ".join(attributes)]


func _dot_edge_attributes(edge: Dictionary, options: Dictionary) -> String:
	var attributes := PackedStringArray()
	attributes.append("label=\"%s\"" % _dot_escape(_truncate(_edge_text(edge), int(options.get("max_label_chars", 80)))))
	attributes.append("tooltip=\"%s\"" % _dot_escape("%s:%d:%d" % [
		(edge.get("location", {}) as Dictionary).get("path", ""),
		int((edge.get("location", {}) as Dictionary).get("line", 0)),
		int((edge.get("location", {}) as Dictionary).get("column", 1)),
	]))
	match str(edge.get("kind", "jump_to")):
		"jump_if":
			attributes.append("style=dashed")
			attributes.append("color=\"#8250df\"")
		"branch":
			var branch: Dictionary = edge.get("branch", {})
			attributes.append("color=\"#0969da\"" if str(branch.get("mode", "normal")) != "jump" else "color=\"#bc4c00\"")
		_:
			attributes.append("color=\"#24292f\"")
	return " [%s]" % ", ".join(attributes)


func _node_label(node: Dictionary, options: Dictionary) -> String:
	var node_id := str(node.get("id", ""))
	var display := str(node.get("display_name", node_id))
	var label_mode := str(options.get("label", "both"))
	var label := node_id if label_mode == "id" else (display if label_mode == "display" else (display if display == node_id else "%s\n(%s)" % [display, node_id]))
	if bool(node.get("defined", false)):
		var metrics: Dictionary = node.get("metrics", {})
		label += "\nD:%d" % int(metrics.get("dialogues", 0))
	return _truncate(label, int(options.get("max_label_chars", 80)))


func _edge_text(edge: Dictionary) -> String:
	var kind := str(edge.get("kind", "jump_to"))
	var phase_prefix := ""
	if str(edge.get("phase", "eager")) == "lazy":
		var stage := str(edge.get("stage", "default"))
		phase_prefix = "lazy:%s " % (stage if not stage.is_empty() else "default")
	if kind == "branch":
		var branch: Dictionary = edge.get("branch", {})
		var parts := PackedStringArray(["branch #%d" % (int(branch.get("option_index", 0)) + 1), "[%s]" % branch.get("mode", "normal")])
		var text := str(branch.get("text", ""))
		if not text.is_empty():
			parts.append(text)
		var condition := str(branch.get("condition_normalized", ""))
		if not condition.is_empty():
			parts.append("if %s" % condition)
		if bool(branch.get("fallback", false)):
			parts.append("fallback")
		return phase_prefix + " ".join(parts)
	if kind == "jump_if":
		var condition := str((edge.get("guard", {}) as Dictionary).get("normalized", ""))
		return phase_prefix + ("jump_if" if condition.is_empty() else "jump_if %s" % condition)
	return phase_prefix + "jump_to"


func _dot_escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\r", "").replace("\n", "\\n")


func _mermaid_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;").replace("\r", "").replace("\n", "<br/>")


func _truncate(value: String, maximum: int) -> String:
	if maximum <= 0 or value.length() <= maximum:
		return value
	return value.substr(0, maxi(maximum - 1, 0)) + "…"


func _glob_match(value: String, pattern: String) -> bool:
	var regex := "^"
	for i in range(pattern.length()):
		var character := pattern.substr(i, 1)
		if character == "*":
			regex += ".*"
		elif character == "?":
			regex += "."
		elif character in [".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\"]:
			regex += "\\" + character
		else:
			regex += character
	regex += "$"
	var compiled := RegEx.new()
	return compiled.compile(regex) == OK and compiled.search(value) != null


func _ordered_values(values: Array[String], order: Array) -> Array[String]:
	var out: Array[String] = []
	for raw_value in order:
		var value := str(raw_value)
		if value in values:
			out.append(value)
	for value in values:
		if value not in out:
			out.append(value)
	return out


func _sorted_unique_strings(raw_values: Variant) -> Array[String]:
	var seen: Dictionary = {}
	var values: Array = raw_values if raw_values is Array else []
	for raw_value in values:
		var value := str(raw_value).strip_edges()
		if not value.is_empty():
			seen[value] = true
	var out: Array[String] = []
	for value in seen.keys():
		out.append(str(value))
	out.sort()
	return out


func _enum_value(value: String, allowed: Array, fallback: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if normalized in allowed else fallback


func _has_error(diagnostics: Array[Dictionary]) -> bool:
	for diagnostic in diagnostics:
		if str(diagnostic.get("severity", "")) == "error":
			return true
	return false


func _add_unique(array: Array, value: String) -> void:
	if value not in array:
		array.append(value)

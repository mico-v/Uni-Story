#!/usr/bin/env python3
"""Display NovaScript branch structure as text, DOT/graphviz, Mermaid, or JSON.

This is a lightweight wrapper around `scenario_visualize.py` that focuses
specifically on branch visualization.  It invokes the shared IR-building
Godot script to extract branch/flow data, then formats it for human or
tool consumption.

- text:  ASCII tree view of branch points and their targets
- dot:   GraphViz DOT format (pipe to `dot -Tpng` for images)
- mermaid: Markdown Mermaid flowchart (embed in docs)
- json:  Structured data for programmatic consumption
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Optional

from utils import (
    CliError, PROJECT_ROOT, SCENARIOS_DIR,
    resolve_project_root, write_output, format_json,
)


GODOT_SCRIPT = "res://scripts/tools/scenario_visualize.gd"
GODOT_TIMEOUT = 300


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Display NovaScript branch structure visually.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "mermaid", "dot"), default="text",
                   help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--godot", metavar="PATH", default="godot", help="path to godot binary (default: godot)")
    p.add_argument("--scenario", metavar="FILE", help="single scenario file (default: all)")
    p.add_argument("--direction", choices=("TD", "LR", "RL", "BT"), default="TD",
                   help="graph direction for mermaid/dot (default: TD)")
    return p


def find_godot(godot_arg: str, project_root: Path) -> str:
    """Find the godot binary."""
    if godot_arg and godot_arg != "godot":
        return godot_arg
    # Try to find godot via which
    found = shutil.which("godot")
    if found:
        return found
    return "godot"


def run_godot_ir(godot_path: str, project_root: Path, scenario: Optional[str] = None) -> dict:
    """Run scenario_visualize.gd via Godot to get the flow IR in JSON."""
    tmpdir = tempfile.mkdtemp(prefix="uni_story_branches_")
    output_path = Path(tmpdir) / "ir.json"

    args_list = [
        godot_path,
        "--headless",
        "--path", str(project_root),
        "--script", str(project_root / "scripts" / "tools" / "scenario_visualize.gd"),
        "--",
        "--format", "json",
        "--output", str(output_path),
    ]
    if scenario:
        args_list.extend(["--scenario", scenario])

    try:
        result = subprocess.run(
            args_list,
            capture_output=True,
            text=True,
            timeout=GODOT_TIMEOUT,
            cwd=str(project_root),
        )
    except subprocess.TimeoutExpired:
        raise CliError(f"Godot timed out after {GODOT_TIMEOUT}s")
    except FileNotFoundError:
        raise CliError(f"Godot binary not found: {godot_path}")

    if output_path.is_file():
        try:
            return json.loads(output_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            raise CliError("Godot did not produce valid JSON output")
    else:
        # Try to extract from stdout
        # Fallback: manually parse scenarios
        return _fallback_parse_scenarios(project_root, scenario)


def _fallback_parse_scenarios(project_root: Path, scenario: Optional[str]) -> dict:
    """Fallback: parse scenarios directly for branch information without Godot."""
    import re

    sc_dir = project_root / "resources" / "scenarios"
    if not sc_dir.is_dir():
        return {"files": {}, "total_branches": 0, "total_jumps": 0}

    files = {}
    to_process = [scenario] if scenario else sorted(
        f.name for f in sc_dir.iterdir()
        if f.suffix == ".txt" and not f.name.startswith(".")
    )

    for fname in to_process:
        fpath = sc_dir / fname
        if not fpath.is_file():
            continue

        text = fpath.read_text(encoding="utf-8")

        # Extract branch() calls
        branches = []
        for m in re.finditer(
            r'branch\s*\(\s*(?:type\s*=\s*)?["\']?(\w+)["\']?\s*,?\s*["\']?([^"\')\n]+?)["\']?\s*\)',
            text,
        ):
            branches.append({
                "type": m.group(1),
                "label": m.group(2).strip(),
                "line": text[:m.start()].count("\n") + 1,
            })

        # Extract jump_to() calls
        jumps = re.findall(r"jump_to\(['\"](\w+)['\"]\)", text)

        # Extract label() calls
        labels = re.findall(r"label\(['\"](\w+)['\"]", text)

        # Extract is_end() markers
        ends = re.findall(r"is_end\(\)", text)
        end_lines = [text[:m.start()].count("\n") + 1 for m in re.finditer(r"is_end\(\)", text)]

        # Extract ending() markers
        endings = re.findall(r'ending\(["\']?(\w+)["\']?\)', text)

        files[fname] = {
            "branches": branches,
            "jumps": jumps,
            "labels": labels,
            "endings": endings,
            "ends": len(ends),
            "end_lines": end_lines,
        }

    total_branches = sum(len(f["branches"]) for f in files.values())
    total_jumps = sum(len(f["jumps"]) for f in files.values())

    return {
        "files": files,
        "total_branches": total_branches,
        "total_jumps": total_jumps,
        "note": "Generated via fallback parser (Godot binary not available).",
    }


def format_mermaid(data: dict, direction: str = "TD") -> str:
    """Convert branch data to Mermaid flowchart."""
    lines = [f"```mermaid", f"flowchart {direction}"]
    node_id = 0
    node_map: dict[str, str] = {}

    def get_node(name: str) -> str:
        nonlocal node_id
        if name not in node_map:
            node_id += 1
            node_map[name] = f"n{node_id}"
        return node_map[name]

    # Extract node labels and branch connections
    for fname, finfo in data.get("files", {}).items():
        stem = Path(fname).stem
        # Add chapter node
        ch_node = get_node(f"ch_{stem}")
        lines.append(f'    {ch_node}["{stem}"]')

        for br in finfo.get("branches", []):
            br_node = get_node(f"br_{stem}_{br['type']}")
            lines.append(f'    {br_node}{{"{br["type"]}?"}}')
            lines.append(f'    {ch_node} --> {br_node}')

            # Branch targets (simplified - link to labels)
            for label in finfo.get("labels", [])[:1]:
                lbl_node = get_node(f"lbl_{stem}_{label}")
                lines.append(f'    {br_node} --> {lbl_node}["{label}"]')

        # Ending nodes
        for ending in finfo.get("endings", []):
            end_node = get_node(f"end_{stem}_{ending}")
            lines.append(f'    {end_node}(("{ending}"))')
            last_label = finfo.get("labels", [None])[-1]
            if last_label:
                lbl_node = get_node(f"lbl_{stem}_{last_label}")
                lines.append(f'    {lbl_node} --> {end_node}')

    lines.append("```")
    return "\n".join(lines)


def format_dot(data: dict, direction: str = "TD") -> str:
    """Convert branch data to GraphViz DOT format."""
    direction_map = {"TD": "TB", "LR": "LR", "RL": "RL", "BT": "BT"}
    dir_ = direction_map.get(direction, "TB")

    lines = [
        "digraph NovaBranches {",
        f'    rankdir={dir_};',
        '    node [shape=box, style=rounded];',
        '    edge [arrowhead=vee];',
        "",
    ]

    node_id = 0
    node_map: dict[str, str] = {}
    def get_node(name: str) -> str:
        nonlocal node_id
        if name not in node_map:
            node_id += 1
            node_map[name] = f"n{node_id}"
        return node_map[name]

    for fname, finfo in data.get("files", {}).items():
        stem = Path(fname).stem
        ch_node = get_node(f"ch_{stem}")
        lines.append(f'    {ch_node} [label="{stem}"];')

        for br in finfo.get("branches", []):
            br_node = get_node(f"br_{stem}_{br['type']}")
            lines.append(f'    {br_node} [label="{br["type"]}?", shape=diamond];')
            lines.append(f'    {ch_node} -> {br_node};')

            for label in finfo.get("labels", [])[:1]:
                lbl_node = get_node(f"lbl_{stem}_{label}")
                lines.append(f'    {lbl_node} [label="{label}"];')
                lines.append(f'    {br_node} -> {lbl_node};')

        for ending in finfo.get("endings", []):
            end_node = get_node(f"end_{stem}_{ending}")
            lines.append(f'    {end_node} [label="{ending}", style=filled, fillcolor=lightgray];')

    lines.append("}")
    return "\n".join(lines)


def format_text_branches(data: dict) -> str:
    """Format branch data as human-readable text."""
    lines: list[str] = []
    lines.append("=== NovaScript Branch Structure ===")
    lines.append(f"Total branches: {data.get('total_branches', 0)}")
    lines.append(f"Total jumps: {data.get('total_jumps', 0)}")
    if data.get("note"):
        lines.append(f"Note: {data['note']}")
    lines.append("")

    for fname, finfo in data.get("files", {}).items():
        lines.append(f"[{fname}]")
        if finfo.get("labels"):
            lines.append(f"  Labels: {', '.join(finfo['labels'])}")
        if finfo.get("branches"):
            lines.append(f"  Branches ({len(finfo['branches'])}):")
            for br in finfo["branches"]:
                lines.append(f"    → {br['type']}: \"{br['label']}\"  (line {br['line']})")
        if finfo.get("jumps"):
            lines.append(f"  Jumps: {', '.join(finfo['jumps'])}")
        if finfo.get("endings"):
            lines.append(f"  Endings: {', '.join(finfo['endings'])}")
        lines.append("")

    return "\n".join(lines)


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    # Try Godot first, fallback to direct parsing
    try:
        godot_path = find_godot(args.godot, project_root)
        data = run_godot_ir(godot_path, project_root, args.scenario)
    except CliError:
        # Fallback
        data = _fallback_parse_scenarios(project_root, args.scenario)

    if args.format == "json":
        write_output(args.output, format_json(data))
    elif args.format == "mermaid":
        write_output(args.output, format_mermaid(data, args.direction))
    elif args.format == "dot":
        write_output(args.output, format_dot(data, args.direction))
    else:
        write_output(args.output, format_text_branches(data))


if __name__ == "__main__":
    main()

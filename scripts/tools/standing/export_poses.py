#!/usr/bin/env python3
"""Export all Pose definitions from a StandingProfile or pose.lua to JSON/YAML.

Usage:
  python3 scripts/tools/standing/export_poses.py --profile resources/standing_profile.tres
  python3 scripts/tools/standing/export_poses.py --profile resources/standing_profile.tres --character gaotian
  python3 scripts/tools/standing/export_poses.py --pose-lua Nova/Assets/Nova/Lua/pose.lua --format yaml
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml as yaml_lib
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


def _find_braced_block(text: str, start_key: str) -> str:
    """Find a braced block starting after a key, properly handling nesting."""
    idx = text.find(start_key)
    if idx < 0:
        return ""
    brace_start = text.find("{", idx)
    if brace_start < 0:
        return ""
    depth = 0
    for i in range(brace_start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[brace_start + 1:i]
    return ""


def parse_profile_poses(tres_path: Path, character: str = "") -> dict:
    """Parse pose definitions from a Godot .tres StandingProfile."""
    text = tres_path.read_text(encoding="utf-8")

    # Parse characters block
    char_block = _find_braced_block(text, "characters = {")
    if not char_block:
        print("Error: could not parse 'characters' block", file=sys.stderr)
        sys.exit(1)

    result: dict = {}
    pos = 0
    while pos < len(char_block):
        name_match = re.search(r'"([^"]+)"\s*:\s*\{', char_block[pos:])
        if not name_match:
            break
        char_name = name_match.group(1)
        if character and char_name != character:
            pos += name_match.end()
            continue

        inner_start = pos + name_match.end() - 1
        inner_block = _find_braced_block(char_block[inner_start:], "{")
        if not inner_block:
            break

        char_poses: dict = {}
        poses_block = _find_braced_block(inner_block, '"poses"')
        if poses_block:
            # Match both bare arrays and explicit Array[String] syntax
            array_poses = re.findall(
                r'"([^"]+)"\s*:\s*(?:Array\[String\]\()?\[(.*?)\]\)?',
                poses_block,
                re.DOTALL,
            )
            for pose_name, layer_list in array_poses:
                layers = re.findall(r'"([^"]+)"', layer_list)
                char_poses[pose_name] = layers

            str_poses = re.findall(
                r'"([^"]+)"\s*:\s*"([^"]+)"',
                poses_block,
            )
            for pose_name, layers_str in str_poses:
                char_poses[pose_name] = layers_str.split("+")

        layer_order: list[str] = []
        lo_match = re.search(
            r'"layer_order"\s*:\s*(?:Array\[String\]\()?\[(.*?)\]\)?',
            inner_block,
            re.DOTALL,
        )
        if lo_match:
            layer_order = re.findall(r'"([^"]+)"', lo_match.group(1))

        offsets: dict = {}
        offsets_block = _find_braced_block(inner_block, '"offsets"')
        if offsets_block:
            offset_entries = re.findall(
                r'"([^"]+)"\s*:\s*Vector2\(([^)]+)\)',
                offsets_block,
            )
            for layer_name, coords in offset_entries:
                parts = [float(x.strip()) for x in coords.split(",")]
                offsets[layer_name] = parts if len(parts) == 2 else [0.0, 0.0]

        char_data: dict = {"poses": char_poses}
        if layer_order:
            char_data["layer_order"] = layer_order
        if offsets:
            char_data["offsets"] = offsets
        if character:
            result = char_data
            break
        else:
            result[char_name] = char_data

        pos = inner_start + len(inner_block) + 2

    return result


def parse_lua_poses(lua_path: Path, character: str = "") -> dict:
    """Parse pose definitions from Nova-style pose.lua."""
    text = lua_path.read_text(encoding="utf-8")
    match = re.search(r"local\s+poses\s*=\s*(\{.*?\n\})", text, re.DOTALL)
    if not match:
        return {}

    poses_block = match.group(1)
    result: dict = {}

    char_entries = re.findall(
        r"\['([^']+)'\]\s*=\s*\{([^}]*)\}",
        poses_block,
        re.DOTALL,
    )

    for char_name, entry in char_entries:
        if character and char_name != character:
            continue
        pose_entries = re.findall(r"\['([^']+)'\]\s*=\s*'([^']+)'", entry)
        char_poses = {}
        for pose_name, layers_str in pose_entries:
            char_poses[pose_name] = layers_str.split("+")
        if character:
            result = {"poses": char_poses}
        else:
            result[char_name] = {"poses": char_poses}

    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export Pose definitions from StandingProfile or pose.lua.",
    )
    parser.add_argument("--profile", "-p", help="Path to standing_profile.tres")
    parser.add_argument("--pose-lua", help="Path to Nova-style pose.lua")
    parser.add_argument("--character", "-c", default="", help="Filter by character name")
    parser.add_argument("--format", "-f", choices=["json", "yaml"], default="json", help="Output format")
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)")

    args = parser.parse_args()

    if args.profile:
        data = parse_profile_poses(Path(args.profile), args.character)
    elif args.pose_lua:
        data = parse_lua_poses(Path(args.pose_lua), args.character)
    else:
        print("Error: --profile or --pose-lua is required.", file=sys.stderr)
        sys.exit(1)

    if args.format == "yaml":
        if not HAS_YAML:
            print("Error: PyYAML is required for YAML output. Install: pip install PyYAML", file=sys.stderr)
            sys.exit(1)
        output = yaml_lib.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False)
    else:
        output = json.dumps(data, indent=2, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(output + "\n", encoding="utf-8")
        print(f"Exported to {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""List standing pose (POS) position definitions from StandingProfile.

Reads the project's StandingProfile resource (.tres) and extracts
all character positions, layers, offsets and pose definitions.
Outputs a structured listing suitable for tooling and documentation.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Optional

from utils import (
    CliError, PROJECT_ROOT,
    resolve_project_root, write_output, format_json,
)


DEFAULT_PROFILE = "standing_profile.tres"


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="List standing pose definitions from StandingProfile.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "csv"), default="text", help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--profile", metavar="PATH", help=f"path to .tres profile (default: resources/{DEFAULT_PROFILE})")
    p.add_argument("--character", metavar="NAME", help="filter by character name")
    return p


def parse_vector2(value: str) -> tuple[float, float]:
    """Parse 'Vector2(x, y)' into (x, y)."""
    m = re.match(r'Vector2\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)', value)
    if m:
        return (float(m.group(1)), float(m.group(2)))
    return (0.0, 0.0)


def _find_matching_brace(text: str, start: int) -> int:
    """Find the matching closing brace from start position (pointing at '{')."""
    if start >= len(text) or text[start] != '{':
        return -1
    bc = 0
    for i in range(start, len(text)):
        if text[i] == '{':
            bc += 1
        elif text[i] == '}':
            bc -= 1
            if bc == 0:
                return i
    return -1


def _parse_character_block(block: str) -> dict:
    """Parse a single character block's interior (between outer braces)."""
    info: dict = {
        "pose_count": 0,
        "poses": {},
        "offsets": {},
    }

    # Directory
    dir_m = re.search(r'"directory"\s*:\s*"([^"]*)"', block)
    if dir_m:
        info["directory"] = dir_m.group(1)

    # Layer order override
    lo_m = re.search(r'"layer_order"\s*:\s*Array\[String\]\(([^)]+)\)', block)
    if lo_m:
        layers = [s.strip('"') for s in re.findall(r'"([^"]*)"', lo_m.group(1))]
        info["layer_order"] = layers

    # Poses block
    poses_m = re.search(r'"poses"\s*:\s*\{', block)
    if poses_m:
        poses_end = _find_matching_brace(block, poses_m.end() - 1)
        if poses_end > 0:
            poses_block = block[poses_m.end():poses_end]
            # Match both Array[String](...) and JSON [...] style
            for pm in re.finditer(r'"(\w+)"\s*:\s*(?:Array\[String\]\(|\[)\s*([^\])\]]+)\s*(?:\)|\])', poses_block):
                pose_name = pm.group(1)
                layers_val = pm.group(2)
                layers = [s.strip().strip('"') for s in layers_val.split(",") if s.strip()]
                info["poses"][pose_name] = layers
            info["pose_count"] = len(info["poses"])

    # Offsets block
    offsets_m = re.search(r'"offsets"\s*:\s*\{', block)
    if offsets_m:
        offsets_end = _find_matching_brace(block, offsets_m.end() - 1)
        if offsets_end > 0:
            offsets_block = block[offsets_m.end():offsets_end]
            for om in re.finditer(r'"(\w+)"\s*:\s*(Vector2\([^)]+\))', offsets_block):
                layer_name = om.group(1)
                vec = parse_vector2(om.group(2))
                info["offsets"][layer_name] = {"x": vec[0], "y": vec[1]}

    return info


def parse_tres_profile(filepath: Path) -> dict:
    """Parse a Godot .tres StandingProfile resource.

    Extracts character definitions with poses, offsets, and layer orders.
    """
    if not filepath.is_file():
        raise CliError(f"Profile file not found: {filepath}")

    content = filepath.read_text(encoding="utf-8")
    result: dict = {
        "source": filepath.as_posix(),
        "characters": {},
        "global_settings": {},
    }

    # Extract global settings
    for key, pattern in [
        ("character_root", r'character_root\s*=\s*"([^"]*)"'),
        ("offset_sidecar_extension", r'offset_sidecar_extension\s*=\s*"([^"]*)"'),
        ("offset_pixels_per_unit", r'offset_pixels_per_unit\s*=\s*(\d+\.?\d*)'),
        ("invert_sidecar_y", r'invert_sidecar_y\s*=\s*(true|false)'),
    ]:
        m = re.search(pattern, content)
        if m:
            result["global_settings"][key] = m.group(1)

    m = re.search(r'default_layer_order\s*=\s*Array\[String\]\(([^)]+)\)', content)
    if m:
        layer_str = m.group(1)
        layers = [s.strip('"') for s in re.findall(r'"([^"]*)"', layer_str)]
        result["global_settings"]["default_layer_order"] = layers

    # Extract characters block using brace counting
    chars_m = re.search(r'characters\s*=\s*\{', content)
    if chars_m:
        chars_end = _find_matching_brace(content, chars_m.end() - 1)
        if chars_end > 0:
            chars_block = content[chars_m.end():chars_end]

            # Extract each character
            char_start_re = re.compile(r'"(\w+)"\s*:\s*\{')
            pos = 0
            while pos < len(chars_block):
                m = char_start_re.search(chars_block, pos)
                if not m:
                    break
                char_name = m.group(1)
                brace_start = m.end() - 1

                char_end = _find_matching_brace(chars_block, brace_start)
                if char_end < 0:
                    break

                char_block = chars_block[brace_start + 1:char_end]
                char_info = _parse_character_block(char_block)
                default_lo = result["global_settings"].get("default_layer_order", [])
                char_info["layer_order"] = char_info.get("layer_order", default_lo)
                result["characters"][char_name] = char_info
                pos = char_end + 1

    result["character_count"] = len(result["characters"])
    result["total_poses"] = sum(c["pose_count"] for c in result["characters"].values())

    return result


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    profile_path = args.profile or str(project_root / "resources" / DEFAULT_PROFILE)
    try:
        data = parse_tres_profile(Path(profile_path))
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    # Filter by character
    if args.character and args.character in data["characters"]:
        data["characters"] = {args.character: data["characters"][args.character]}
        data["character_count"] = 1
        data["total_poses"] = sum(c["pose_count"] for c in data["characters"].values())
    elif args.character:
        print(f"Character '{args.character}' not found in profile", file=sys.stderr)
        sys.exit(2)

    if args.format == "json":
        write_output(args.output, format_json(data))
    elif args.format == "csv":
        lines = ["character,pose,layers,offset_layer,offset_x,offset_y"]
        for char_name, char_info in data["characters"].items():
            for pose_name, layers in char_info["poses"].items():
                lines.append(f'{char_name},{pose_name},{"|".join(layers)},,,')
            for layer_name, offset in char_info["offsets"].items():
                lines.append(f'{char_name},,,"{layer_name}",{offset["x"]},{offset["y"]}')
        write_output(args.output, "\n".join(lines) + "\n")
    else:
        lines: list[str] = []
        lines.append("=== Standing Pose (POS) Definitions ===")
        lines.append(f"Source: {data['source']}")
        lines.append(f"Characters: {data['character_count']}  |  Total poses: {data['total_poses']}")
        if data["global_settings"]:
            gs = data["global_settings"]
            lines.append(f"Character root: {gs.get('character_root', 'N/A')}")
            lines.append(f"Default layer order: {gs.get('default_layer_order', [])}")
        lines.append("")

        for char_name, char_info in data["characters"].items():
            lines.append(f"[{char_name}]")
            if "directory" in char_info:
                lines.append(f"  Directory: {char_info['directory']}")
            if char_info["poses"]:
                lines.append(f"  Poses ({char_info['pose_count']}):")
                for pose_name, layers in char_info["poses"].items():
                    lines.append(f"    {pose_name}: {layers}")
            if char_info["offsets"]:
                lines.append(f"  Layer Offsets:")
                for layer_name, offset in char_info["offsets"].items():
                    lines.append(f"    {layer_name}: ({offset['x']:.0f}, {offset['y']:.0f})")
            lines.append("")

        write_output(args.output, "\n".join(lines))


if __name__ == "__main__":
    main()

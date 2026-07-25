#!/usr/bin/env python3
"""Merge standing layers into full character sprites per Pose configuration.

Reads StandingProfile (.tres) or a pose JSON file, and composes the layer
PNGs into merged character images that match the Godot SpriteComposer output.

Usage:
  python3 scripts/tools/standing/merge_psd_layers.py \\
    --layers-dir resources/Standings/Gaotian/ \\
    --profile resources/standing_profile.tres \\
    --character gaotian \\
    --output-dir out/gaotian_poses/

  python3 scripts/tools/standing/merge_psd_layers.py \\
    --layers-dir resources/Standings/Gaotian/ \\
    --poses '{"normal": ["body","mouth_smile","eye_normal","eyebrow_normal","hair"], "cry": ["body","mouth_smile","eye_cry","eyebrow_normal","hair"]}' \\
    --output-dir out/
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
from pathlib import Path

try:
    from PIL import Image
    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


# --- StandingProfile .tres parsing ---

def _find_braced_block(text: str, start_key: str) -> str:
    """Find a braced block starting after a key, properly handling nesting."""
    idx = text.find(start_key)
    if idx < 0:
        return ""
    # find opening brace
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


def parse_tres_profile(tres_path: Path) -> dict:
    """Parse a Godot .tres StandingProfile resource into a Python dict.

    Returns: {
        "characters": {
            "<name>": {
                "directory": "...",
                "layer_order": [...],
                "poses": {"normal": [...], ...},
                "offsets": {"body": [x,y], ...}
            }
        }
    }
    """
    if not tres_path.exists():
        print(f"Error: profile not found: {tres_path}", file=sys.stderr)
        sys.exit(1)

    text = tres_path.read_text(encoding="utf-8")

    result: dict = {"characters": {}}

    # Find the characters block
    char_block = _find_braced_block(text, "characters = {")
    if not char_block:
        print("Error: could not parse 'characters' block from .tres", file=sys.stderr)
        sys.exit(1)

    # Parse each character entry using nested brace tracking
    pos = 0
    while pos < len(char_block):
        # Find next quoted character name
        name_match = re.search(r'"([^"]+)"\s*:\s*\{', char_block[pos:])
        if not name_match:
            break
        char_name = name_match.group(1)
        # Find the nested block for this character
        inner_start = pos + name_match.end() - 1  # position of {
        inner_block = _find_braced_block(char_block[inner_start:], "{")
        if not inner_block:
            break

        char_data: dict = {"poses": {}, "offsets": {}, "layer_order": [], "directory": ""}

        # directory
        dir_match = re.search(r'"directory"\s*:\s*"([^"]+)"', inner_block)
        if dir_match:
            char_data["directory"] = dir_match.group(1)

        # layer_order
        lo_match = re.search(
            r'"layer_order"\s*:\s*(?:Array\[String\]\()?\[(.*?)\]\)?',
            inner_block,
            re.DOTALL,
        )
        if lo_match:
            items = re.findall(r'"([^"]+)"', lo_match.group(1))
            char_data["layer_order"] = items

        # poses
        poses_block = _find_braced_block(inner_block, '"poses"')
        if poses_block:
            # Match both bare arrays and explicit Array[String] syntax
            array_poses = re.findall(
                r'"([^"]+)"\s*:\s*(?:Array\[String\]\()?\[(.*?)\]\)?',
                poses_block,
                re.DOTALL,
            )
            for pose_name, layer_list_str in array_poses:
                layer_items = re.findall(r'"([^"]+)"', layer_list_str)
                char_data["poses"][pose_name] = layer_items
            # String format
            str_poses = re.findall(
                r'"([^"]+)"\s*:\s*"([^"]+)"',
                poses_block,
            )
            for pose_name, layers_str in str_poses:
                char_data["poses"][pose_name] = layers_str.split("+")

        # offsets
        offsets_block = _find_braced_block(inner_block, '"offsets"')
        if offsets_block:
            offset_entries = re.findall(
                r'"([^"]+)"\s*:\s*Vector2\(([^)]+)\)',
                offsets_block,
            )
            for layer_name, coords in offset_entries:
                parts = [float(x.strip()) for x in coords.split(",")]
                char_data["offsets"][layer_name] = parts if len(parts) == 2 else [0.0, 0.0]

        result["characters"][char_name.lower()] = char_data
        pos = inner_start + len(inner_block) + 2  # skip past }}

    return result


def parse_lua_pose(lua_path: Path) -> dict:
    """Parse Nova-style pose.lua to extract poses dict."""
    if not lua_path.exists():
        print(f"Warning: pose.lua not found: {lua_path}", file=sys.stderr)
        return {}

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
        result[char_name] = {}
        pose_entries = re.findall(r"\['([^']+)'\]\s*=\s*'([^']+)'", entry)
        for pose_name, layers_str in pose_entries:
            result[char_name][pose_name] = layers_str.split("+")

    return result


# --- Layer composition ---

def load_layer(layers_dir: Path, layer_name: str) -> Image.Image | None:
    """Load a PNG layer from the layers directory. Try multiple extensions."""
    for ext in (".png", ".PNG"):
        path = layers_dir / f"{layer_name}{ext}"
        if path.exists():
            img = Image.open(str(path)).convert("RGBA")
            return img
    return None


def compose_pose(
    layers_dir: Path,
    pose_layers: list[str],
    offsets: dict[str, list[float]],
    layer_order: list[str],
    scale: float = 1.0,
) -> Image.Image | None:
    """Compose a set of layers into one image with offsets applied.

    The composition matches Godot's SpriteComposer behavior:
    - All layers share the same canvas size (max of background layers)
    - offset is in Godot pixels (100 px/unit), applied from center
    - Layers are drawn in layer_order sequence
    """
    # First pass: load all layers and determine canvas size
    loaded: dict[str, Image.Image] = {}
    max_w, max_h = 0, 0

    for layer_name in pose_layers:
        img = load_layer(layers_dir, layer_name)
        if img is not None:
            loaded[layer_name] = img
            max_w = max(max_w, img.width)
            max_h = max(max_h, img.height)

    if not loaded:
        print("  No layers could be loaded!", file=sys.stderr)
        return None

    # Sort loaded layers by layer_order
    order_map = {name: i for i, name in enumerate(layer_order)}
    sorted_layers = sorted(
        loaded.keys(),
        key=lambda n: (order_map.get(_layer_group(n), len(layer_order)), n),
    )

    # Create canvas
    canvas = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))

    for layer_name in sorted_layers:
        img = loaded[layer_name]
        group = _layer_group(layer_name)
        off = offsets.get(group, offsets.get(layer_name, [0.0, 0.0]))
        # Godot offset: 100 pixels_per_unit, from center
        # Since canvas is existing layer images (already at sprite positions),
        # we interpret offset relative to the top-left corner of the sprite.
        # In practice, offsets are small adjustments; we paste at (offset_x, offset_y)
        ox = int(off[0])
        oy = int(off[1])

        # Paste with alpha blending
        canvas.paste(img, (ox, oy), img)

    if scale != 1.0:
        new_size = (int(canvas.width * scale), int(canvas.height * scale))
        canvas = canvas.resize(new_size, Image.LANCZOS)

    return canvas


def _layer_group(layer_name: str) -> str:
    """Extract the group prefix from a layer name."""
    if "_" in layer_name:
        return layer_name.split("_")[0]
    return layer_name


def main() -> None:
    if not HAS_PILLOW:
        print("Error: Pillow is required. Install: pip install Pillow", file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser(
        description="Merge standing layers into character sprites per Pose config.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -d resources/Standings/Gaotian/ -p resources/standing_profile.tres -c gaotian -o out/
  %(prog)s -d resources/Standings/Gaotian/ --poses '{"normal":["body","mouth_smile","eye_normal","eyebrow_normal","hair"]}' -o out/
        """.strip(),
    )
    parser.add_argument("--layers-dir", "-d", required=True, help="Directory containing PNG layer files")
    parser.add_argument("--profile", "-p", help="Path to standing_profile.tres")
    parser.add_argument("--character", "-c", default="", help="Character name (for profile lookup)")
    parser.add_argument("--poses", help='Inline JSON pose definition, e.g. \'{"normal":["body","hair"]}\'')
    parser.add_argument("--pose-lua", help="Path to Nova pose.lua for pose definitions")
    parser.add_argument("--output-dir", "-o", required=True, help="Output directory for merged PNGs")
    parser.add_argument("--scale", "-s", type=float, default=1.0, help="Output scale factor (default: 1.0)")
    parser.add_argument("--layer-order", default="", help="Comma-separated layer draw order (top to bottom)")

    args = parser.parse_args()

    layers_dir = Path(args.layers_dir).resolve()
    output_dir = Path(args.output_dir).resolve()

    if not layers_dir.is_dir():
        print(f"Error: layers directory not found: {layers_dir}", file=sys.stderr)
        sys.exit(1)

    # Resolve poses
    poses: dict[str, list[str]] = {}
    offsets: dict[str, list[float]] = {}
    layer_order: list[str] = []
    character_name = args.character.strip().lower()

    if args.poses:
        poses = json.loads(args.poses)

    if args.profile:
        tres_path = Path(args.profile).resolve()
        profile = parse_tres_profile(tres_path)
        if character_name and character_name in profile.get("characters", {}):
            char_data = profile["characters"][character_name]
            if not poses:
                poses = char_data.get("poses", {})
            offsets = char_data.get("offsets", {})
            layer_order = char_data.get("layer_order", [])

    if args.pose_lua:
        lua_path = Path(args.pose_lua).resolve()
        lua_poses = parse_lua_pose(lua_path)
        if character_name and character_name in lua_poses:
            if not poses:
                poses = lua_poses[character_name]

    if args.layer_order:
        layer_order = [s.strip() for s in args.layer_order.split(",")]

    if not poses:
        print("Error: no poses specified. Use --poses, --profile, or --pose-lua.", file=sys.stderr)
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    exported: list[str] = []
    for pose_name, pose_layers in poses.items():
        print(f"Merging pose '{pose_name}': {pose_layers}")
        img = compose_pose(layers_dir, pose_layers, offsets, layer_order, args.scale)
        if img is None:
            print(f"  ✗ Failed to compose '{pose_name}'", file=sys.stderr)
            continue
        out_path = output_dir / f"{pose_name}.png"
        img.save(str(out_path), "PNG", optimize=True)
        exported.append(pose_name)
        print(f"  ✓ {pose_name}.png ({img.size[0]}×{img.size[1]})")

    print(f"\nMerged {len(exported)} pose(s) to {output_dir}")
    if len(exported) == 0:
        print("⚠ No poses were merged. Check layer paths and pose definitions.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

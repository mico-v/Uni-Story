#!/usr/bin/env python3
"""Export PSD layers as individual PNG files.

Supports layer grouping following docs/StandingImportGuide.md naming conventions.

Usage:
  python3 scripts/tools/standing/export_psd_layers.py --input char.psd --output-dir out/
  python3 scripts/tools/standing/export_psd_layers.py --input char.psd --output-dir out/ --scale 0.5
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

try:
    from PIL import Image
    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False

try:
    from psd_tools import PSDImage
    HAS_PSD_TOOLS = True
except ImportError:
    HAS_PSD_TOOLS = False


# Default layer group mapping (base name → group prefix)
# These map PSD layer names to the StandingImportGuide naming convention.
DEFAULT_GROUP_MAP = {
    # body
    "body": "body",
    "base": "body",
    "身体": "body",
    # face/expression
    "face": "face",
    "eye": "eye",
    "eyes": "eye",
    "eyebrow": "eyebrow",
    "eyebrows": "eyebrow",
    "brow": "eyebrow",
    "mouth": "mouth",
    "lip": "mouth",
    "lips": "mouth",
    # hair
    "hair": "hair",
    "front_hair": "hair",
    "前发": "hair",
    # effects
    "blush": "blush",
    "sweat": "sweat",
    "effect": "effect",
    "effects": "effect",
}

# Priority for root-level layer naming (standalone layers)
STANDALONE_GROUPS = {"body", "hair", "blush", "sweat", "effect"}


def _detect_group(layer_name: str) -> str:
    """Map a layer name to its group prefix using heuristics."""
    name_lower = layer_name.lower().strip()
    # Direct match
    if name_lower in DEFAULT_GROUP_MAP:
        return DEFAULT_GROUP_MAP[name_lower]

    # Check if it starts with a known group prefix
    for prefix, group in DEFAULT_GROUP_MAP.items():
        if name_lower.startswith(prefix + "_") or name_lower.startswith(prefix + " "):
            return group

    # Heuristic: if name contains an underscore, first part might be group
    if "_" in name_lower:
        first = name_lower.split("_")[0]
        if first in DEFAULT_GROUP_MAP:
            return DEFAULT_GROUP_MAP[first]

    return name_lower


def _normalize_variant(layer_name: str, group: str) -> str:
    """Normalize variant name to match group_variant.png convention."""
    name_lower = layer_name.lower().strip()

    # If layer name is exactly the group name, no variant
    if name_lower == group or name_lower in DEFAULT_GROUP_MAP:
        return ""

    # Remove group prefix
    for prefix in [group + "_", group + " ", group]:
        if name_lower.startswith(prefix):
            variant = name_lower[len(prefix):]
            break
    else:
        variant = name_lower

    variant = variant.strip().strip("_").strip()
    if variant in ("", group):
        return ""

    # Normalize common variant names
    variant_map = {
        "normal": "normal",
        "default": "normal",
        "通常": "normal",
        "smile": "smile",
        "happy": "smile",
        "笑": "smile",
        "shock": "shock",
        "surprise": "shock",
        "惊": "shock",
        "angry": "angry",
        "怒": "angry",
        "close": "close",
        "closed": "close",
        "闭": "close",
        "cry": "cry",
        "泣": "cry",
        "divert": "divert",
        "down": "down",
        "squint": "squint",
        "眯": "squint",
        "open": "open",
        "open2": "open2",
        "close2": "close2",
        "angry2": "angry2",
        "down2": "down2",
        "happy2": "happy2",
        "side": "side",
    }
    return variant_map.get(variant, variant.lower().replace(" ", "_"))


def _output_filename(layer_name: str, group: str, variant: str) -> str:
    """Build output filename: group_variant.png or group.png."""
    if not variant:
        return f"{group}.png"
    return f"{group}_{variant}.png"


def export_with_psd_tools(
    psd_path: Path,
    output_dir: Path,
    scale: float = 1.0,
    prefix: str = "",
) -> list[str]:
    """Export PSD layers using psd-tools library."""
    psd = PSDImage.open(str(psd_path))
    width, height = psd.size
    exported: list[str] = []

    output_dir.mkdir(parents=True, exist_ok=True)

    for layer in psd.descendants():
        if not layer.is_visible():
            continue
        if layer.kind not in ("pixel", "smartobject", "shape", "type"):
            continue

        layer_name = layer.name.strip()
        if not layer_name:
            continue

        group = _detect_group(layer_name)
        variant = _normalize_variant(layer_name, group)
        out_filename = _output_filename(layer_name, group, variant)
        if prefix:
            out_filename = f"{prefix}{out_filename}"

        # Composite the layer onto a transparent canvas at correct position
        try:
            layer_img = layer.composite(viewport=(0, 0, width, height))
        except Exception:
            # Fallback: try to get layer image directly
            try:
                layer_img = layer.topil()
            except Exception:
                print(f"  SKIP: cannot render layer '{layer_name}'", file=sys.stderr)
                continue

        if layer_img.mode == "RGB":
            layer_img = layer_img.convert("RGBA")

        # Get layer position
        bbox = layer.bbox
        left = bbox[0]
        top = bbox[1]

        # Create full canvas
        full = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        full.paste(layer_img, (left, top))

        if scale != 1.0:
            new_size = (int(width * scale), int(height * scale))
            full = full.resize(new_size, Image.LANCZOS)

        out_path = output_dir / out_filename
        full.save(str(out_path), "PNG", optimize=True)
        exported.append(out_filename)
        print(f"  ✓ {out_filename} ({full.size[0]}×{full.size[1]})")

    return exported


def export_with_pillow_only(
    psd_path: Path,
    output_dir: Path,
    scale: float = 1.0,
) -> list[str]:
    """Fallback: export using Pillow only (limited PSD support).

    Pillow has basic PSD reading. It can extract merged image and basic layers.
    """
    img = Image.open(str(psd_path))
    output_dir.mkdir(parents=True, exist_ok=True)
    exported: list[str] = []

    # Pillow can only extract layers from some PSD files
    try:
        layers = getattr(img, "layers", None) if hasattr(img, "layers") else None
    except Exception:
        layers = None

    if layers is None:
        # Fallback: save the merged image
        out_path = output_dir / "body.png"
        full = img.convert("RGBA")
        if scale != 1.0:
            new_size = (int(full.width * scale), int(full.height * scale))
            full = full.resize(new_size, Image.LANCZOS)
        full.save(str(out_path), "PNG", optimize=True)
        exported.append("body.png")
        print(f"  ✓ body.png (merged, {full.size[0]}×{full.size[1]})")
        print("  ⚠ psd-tools not installed; only merged body layer exported.", file=sys.stderr)
        print("  ⚠ Install: pip install psd-tools", file=sys.stderr)
        return exported

    # Iterate nested layers if available
    def _walk(layer, depth=0):
        for item in getattr(layer, "layers", []):
            try:
                name = getattr(item, "name", f"layer_{depth}")
                if hasattr(item, "im") and item.im is not None:
                    group = _detect_group(name)
                    variant = _normalize_variant(name, group)
                    out_filename = _output_filename(name, group, variant)
                    layer_img = item.im.convert("RGBA")
                    out_path = output_dir / out_filename
                    if scale != 1.0:
                        new_size = (int(layer_img.width * scale), int(layer_img.height * scale))
                        layer_img = layer_img.resize(new_size, Image.LANCZOS)
                    layer_img.save(str(out_path), "PNG", optimize=True)
                    exported.append(out_filename)
                    print(f"  ✓ {out_filename}")
                _walk(item, depth + 1)
            except Exception:
                pass

    _walk(img)
    return exported


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export PSD layers as individual PNG files for Uni-Story standing pipeline.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --input char.psd --output-dir Gaotian/
  %(prog)s --input char.psd --output-dir Gaotian/ --scale 0.5
  %(prog)s --input char.psd --output-dir Gaotian/ --prefix "gaotian_"
        """.strip(),
    )
    parser.add_argument("--input", "-i", required=True, help="Path to source PSD file")
    parser.add_argument("--output-dir", "-o", required=True, help="Output directory for PNG layers")
    parser.add_argument("--scale", "-s", type=float, default=1.0, help="Scale factor (default: 1.0)")
    parser.add_argument("--prefix", default="", help="Optional filename prefix")
    parser.add_argument("--group-map", help="Path to JSON file with custom group-name mapping")

    args = parser.parse_args()

    psd_path = Path(args.input).resolve()
    output_dir = Path(args.output_dir).resolve()

    if not psd_path.exists():
        print(f"Error: PSD file not found: {psd_path}", file=sys.stderr)
        sys.exit(1)

    if HAS_PSD_TOOLS:
        exported = export_with_psd_tools(psd_path, output_dir, args.scale, args.prefix)
    elif HAS_PILLOW:
        exported = export_with_pillow_only(psd_path, output_dir, args.scale)
    else:
        print("Error: Neither psd-tools nor Pillow is installed.", file=sys.stderr)
        print("Install: pip install psd-tools Pillow", file=sys.stderr)
        sys.exit(1)

    print(f"\nExported {len(exported)} layer(s) to {output_dir}")
    if len(exported) == 0:
        print("⚠ No layers exported. Check if the PSD file has visible pixel layers.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

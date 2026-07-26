#!/usr/bin/env python3
"""List and catalog all shader assets in the project.

Complements shaderproto_gen.py by providing a discovery/listing tool
that scans the resources/shaders/ directory and reports all .gdshader
and .shaderproto files with metadata.

Output: text/JSON/CSV listing of all shader assets.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

from utils import (
    CliError, PROJECT_ROOT,
    resolve_project_root, write_output, format_json,
)


SHADERS_DIR = "shaders"


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="List all shader assets and shaderproto templates.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "csv"), default="text", help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--type", choices=("all", "shader", "shaderproto"), default="all",
                   help="filter by asset type (default: all)")
    p.add_argument("--counts-only", action="store_true", help="only show counts, not individual files")
    return p


def scan_shaders(project_root: Path, asset_type: str) -> dict:
    """Scan resources/shaders/ and collect all shader files."""
    shaders_dir = project_root / "resources" / SHADERS_DIR
    result: dict = {
        "gdshaders": [],
        "shaderprotos": [],
        "total_shader_files": 0,
    }

    if not shaders_dir.is_dir():
        return result

    for f in sorted(shaders_dir.iterdir()):
        if f.name.startswith("."):
            continue

        if f.suffix == ".gdshader" and asset_type in ("all", "shader"):
            # Determine if it's a base, object, or post variant
            variant = "base"
            if "_post" in f.stem:
                variant = "post"
            elif f.name == "default.gdshader":
                variant = "base"

            result["gdshaders"].append({
                "name": f.stem,
                "filename": f.name,
                "variant": variant,
                "size": f.stat().st_size,
                "has_shaderproto": (shaders_dir / f"{f.stem}.shaderproto").exists(),
            })

        elif f.suffix == ".shaderproto" and asset_type in ("all", "shaderproto"):
            # Check if corresponding gdshader exists
            base_name = f.stem
            has_base = (shaders_dir / f"{base_name}.gdshader").exists()
            result["shaderprotos"].append({
                "name": f.stem,
                "filename": f.name,
                "size": f.stat().st_size,
                "has_gdshader": has_base,
            })

    result["total_shader_files"] = len(result["gdshaders"])
    result["total_proto_files"] = len(result["shaderprotos"])

    # Group by categories
    categories = categorize_shaders(result["gdshaders"])
    result["categories"] = categories

    return result


def categorize_shaders(gdshaders: list) -> dict:
    """Categorize shaders by their effect type."""
    categories = {
        "blur": [],
        "distortion": [],
        "color": [],
        "transition": [],
        "vfx": [],
        "utility": [],
        "other": [],
    }

    blur_keywords = ["blur", "radial", "zoom"]
    distortion_keywords = ["barrel", "swirl", "kaleidoscope", "mosaic", "pixelate", "ripple", "wiggle", "shake", "rand_roll"]
    color_keywords = ["colorless", "mono", "grayscale", "invert", "vignette", "chromatic", "glow", "overglow"]
    transition_keywords = ["dissolve", "wipe", "fade", "flip_grid", "roll", "change_texture"]
    vfx_keywords = ["glitch", "broken_tv", "rain", "water", "blink", "edge_detect", "gray_wave", "overlay", "mix_add", "show_second_texture", "masked", "sharpen"]
    utility_keywords = ["default", "final_blit"]

    for sh in gdshaders:
        name = sh["name"].lower()
        categorized = False
        for kw in blur_keywords:
            if kw in name:
                categories["blur"].append(sh)
                categorized = True
                break
        if not categorized:
            for kw in distortion_keywords:
                if kw in name:
                    categories["distortion"].append(sh)
                    categorized = True
                    break
        if not categorized:
            for kw in color_keywords:
                if kw in name:
                    categories["color"].append(sh)
                    categorized = True
                    break
        if not categorized:
            for kw in transition_keywords:
                if kw in name:
                    categories["transition"].append(sh)
                    categorized = True
                    break
        if not categorized:
            for kw in vfx_keywords:
                if kw in name:
                    categories["vfx"].append(sh)
                    categorized = True
                    break
        if not categorized:
            for kw in utility_keywords:
                if kw in name:
                    categories["utility"].append(sh)
                    categorized = True
                    break
        if not categorized:
            categories["other"].append(sh)

    return {k: {"count": len(v), "shaders": v} for k, v in categories.items()}


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    data = scan_shaders(project_root, args.type)

    if args.format == "json":
        write_output(args.output, format_json(data))
    elif args.format == "csv":
        lines = ["name,filename,variant,size,has_shaderproto"]
        for sh in data["gdshaders"]:
            lines.append(f'{sh["name"]},{sh["filename"]},{sh["variant"]},{sh["size"]},{sh["has_shaderproto"]}')
        for sp in data["shaderprotos"]:
            lines.append(f'{sp["name"]},{sp["filename"]},shaderproto,{sp["size"]},{sp["has_gdshader"]}')
        write_output(args.output, "\n".join(lines) + "\n")
    else:
        lines: list[str] = []
        lines.append("=== Uni-Story Shader Assets Catalog ===")
        lines.append(f"Total .gdshader files:  {data['total_shader_files']}")
        lines.append(f"Total .shaderproto files: {data['total_proto_files']}")
        lines.append("")

        cat_labels = {
            "blur": "Blur Effects",
            "distortion": "Distortion Effects",
            "color": "Color / Tone Effects",
            "transition": "Transition Effects",
            "vfx": "VFX / Special Effects",
            "utility": "Utility Shaders",
            "other": "Other",
        }
        for cat_key, cat_label in cat_labels.items():
            cat = data["categories"].get(cat_key, {})
            if cat.get("count", 0) == 0:
                continue
            lines.append(f"[{cat_label}]  ({cat['count']} shaders)")
            if not args.counts_only:
                for sh in cat.get("shaders", []):
                    lines.append(f"  {sh['filename']}  ({sh['variant']})")
                lines.append("")

        write_output(args.output, "\n".join(lines))


if __name__ == "__main__":
    main()

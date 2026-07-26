#!/usr/bin/env python3
"""List background (BG) assets in the project.

Scans resources/Backgrounds/ and reports all background image files
with metadata (dimensions, format, file size).
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import sys
from pathlib import Path
from typing import Optional

from utils import (
    CliError, PROJECT_ROOT,
    resolve_project_root, write_output, format_json,
)


BG_DIRS = ["Backgrounds", "Backgrounds/Snapshots"]
SUPPORTED_EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".svg")


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="List background (BG) assets and their metadata.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "csv"), default="text", help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--details", action="store_true", help="include dimensions and file size")
    p.add_argument("--counts-only", action="store_true", help="only show counts, not individual files")
    return p


def get_png_dimensions(filepath: Path) -> tuple[int, int] | None:
    """Get PNG image dimensions from file header."""
    try:
        with open(filepath, "rb") as f:
            f.read(8)  # Skip PNG signature
            f.read(4)  # Skip IHDR length
            f.read(4)  # Skip IHDR type
            width = struct.unpack(">I", f.read(4))[0]
            height = struct.unpack(">I", f.read(4))[0]
            return (width, height)
    except Exception:
        return None


def get_jpeg_dimensions(filepath: Path) -> tuple[int, int] | None:
    """Get JPEG image dimensions from file (basic SOF0 reader)."""
    try:
        with open(filepath, "rb") as f:
            if f.read(2) != b"\xff\xd8":
                return None
            while True:
                marker = f.read(2)
                if len(marker) < 2:
                    return None
                if marker[0] != 0xFF:
                    return None
                length = struct.unpack(">H", f.read(2))[0] - 2
                if marker[1] in (0xC0, 0xC2):
                    f.read(1)  # precision
                    height = struct.unpack(">H", f.read(2))[0]
                    width = struct.unpack(">H", f.read(2))[0]
                    return (width, height)
                f.seek(length, 1)
    except Exception:
        return None


def get_image_dimensions(filepath: Path) -> tuple[int, int] | None:
    """Get image dimensions based on file extension."""
    suffix = filepath.suffix.lower()
    if suffix == ".png":
        return get_png_dimensions(filepath)
    elif suffix in (".jpg", ".jpeg"):
        return get_jpeg_dimensions(filepath)
    return None


def scan_backgrounds(project_root: Path, details: bool) -> dict:
    """Scan all background resources."""
    res_dir = project_root / "resources"
    files = []
    categories: dict[str, list[dict]] = {}

    for bg_dir_name in BG_DIRS:
        bg_dir = res_dir / bg_dir_name
        if not bg_dir.is_dir():
            continue
        cat_files: list[dict] = []
        for dirpath, _, filenames in sorted(os.walk(bg_dir)):
            for fname in sorted(filenames):
                if fname.startswith(".") or fname.endswith(".import"):
                    continue
                fpath = Path(dirpath) / fname
                if fpath.suffix.lower() not in SUPPORTED_EXTENSIONS:
                    continue
                rel = fpath.relative_to(res_dir).as_posix()
                entry: dict = {
                    "name": fpath.stem,
                    "path": rel,
                    "extension": fpath.suffix.lower(),
                    "size": fpath.stat().st_size,
                }
                if details:
                    dims = get_image_dimensions(fpath)
                    if dims:
                        entry["width"] = dims[0]
                        entry["height"] = dims[1]
                cat_files.append(entry)
                files.append(entry)
        if cat_files:
            categories[bg_dir_name] = cat_files

    return {
        "total": len(files),
        "categories": {k: {"count": len(v), "files": v} for k, v in categories.items()},
        "all_files": files,
    }


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    data = scan_backgrounds(project_root, args.details)

    if args.format == "json":
        write_output(args.output, format_json(data))
    elif args.format == "csv":
        headers = ["name", "path", "extension", "size"]
        if args.details:
            headers += ["width", "height"]
        rows = []
        for f in data["all_files"]:
            row = [f["name"], f["path"], f["extension"], str(f["size"])]
            if args.details:
                row += [str(f.get("width", "")), str(f.get("height", ""))]
            rows.append(row)
        lines = [",".join(headers)]
        for row in rows:
            quoted = [f'"{c}"' if "," in c else c for c in row]
            lines.append(",".join(quoted))
        write_output(args.output, "\n".join(lines) + "\n")
    else:
        lines: list[str] = []
        lines.append("=== Background (BG) Assets ===")
        lines.append(f"Total: {data['total']} files")
        lines.append("")
        for cat_name, cat_info in sorted(data["categories"].items()):
            lines.append(f"[{cat_name}]  ({cat_info['count']} files)")
            if not args.counts_only:
                for f in cat_info["files"]:
                    if args.details and "width" in f:
                        lines.append(f"  {f['path']}  ({f['width']}×{f['height']}, {f['size']} bytes)")
                    else:
                        lines.append(f"  {f['path']}")
                lines.append("")
        write_output(args.output, "\n".join(lines))


if __name__ == "__main__":
    main()

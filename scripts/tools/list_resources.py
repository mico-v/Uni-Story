#!/usr/bin/env python3
"""Public cross-platform CLI for listing project resources (bg, bgm, sounds, etc.)."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Optional, Sequence


SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]

RESOURCE_DIRS = {
    "bg":         ["Backgrounds"],
    "bgm":        ["BGM"],
    "cg":         ["cg"],
    "se":         ["Sounds"],
    "voice":      ["Voices"],
    "mask":       ["Masks"],
    "video":      ["Videos"],
    "character":  ["Standings"],
    "foreground": ["foregrounds"],
    "ui":         ["UIImages", "Choices"],
    "prefab":     ["prefabs"],
    "font":       ["fonts"],
    "shader":     ["shaders"],
}

CATEGORY_LABELS = {
    "bg":         "Backgrounds",
    "bgm":        "BGM (music)",
    "cg":         "CG / event art",
    "se":         "Sound effects",
    "voice":      "Voice lines",
    "mask":       "Transition masks",
    "video":      "Videos",
    "character":  "Character standings",
    "foreground": "Foreground overlays",
    "ui":         "UI images",
    "prefab":     "Prefabs",
    "font":       "Fonts",
    "shader":     "Shaders",
}


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="List project resources by category (bg, bgm, se, cg, etc.).",
    )
    parser.add_argument(
        "category",
        nargs="*",
        default=["all"],
        help="Resource categories to list (default: all).  Choices: %s" % ", ".join(sorted(RESOURCE_DIRS.keys())),
    )
    parser.add_argument(
        "--format",
        choices=("text", "json", "csv"),
        default="text",
        help="output format (default: text)",
    )
    parser.add_argument(
        "--output",
        metavar="PATH",
        default="-",
        help="write to PATH, or '-' for stdout (default: -)",
    )
    parser.add_argument(
        "--project",
        metavar="PATH",
        help="project root (defaults to repository root)",
    )
    parser.add_argument(
        "--counts-only",
        action="store_true",
        help="only show file counts, not individual paths",
    )
    parser.add_argument(
        "--ext",
        action="append",
        default=[],
        metavar="EXT",
        help="filter by file extension (repeatable, e.g. --ext .png --ext .ogg)",
    )
    return parser


def resolve_project_root(explicit: str | None) -> Path:
    if explicit:
        p = Path(explicit).resolve()
        if not p.is_dir():
            raise CliError(f"project root not found: {p}")
        return p
    return PROJECT_ROOT


def _ext_filter(exts: Sequence[str], filename: str) -> bool:
    if not exts:
        return True
    lower = filename.lower()
    for ext in exts:
        e = ext if ext.startswith(".") else f".{ext}"
        if lower.endswith(e):
            return True
    return False


def collect_resources(
    project_root: Path,
    categories: Sequence[str],
    ext_filters: Sequence[str],
) -> dict:
    resources_dir = project_root / "resources"
    result: dict[str, list[str]] = {}

    for cat in categories:
        candidates = RESOURCE_DIRS.get(cat, [])
        files: list[str] = []
        for subdir in candidates:
            full_path = resources_dir / subdir
            if not full_path.is_dir():
                continue
            for dirpath, _, filenames in os.walk(full_path):
                for fname in sorted(filenames):
                    if fname.startswith(".") or fname.endswith(".import"):
                        continue
                    if _ext_filter(ext_filters, fname):
                        rel = os.path.relpath(os.path.join(dirpath, fname), project_root)
                        files.append(rel)
        files.sort()
        result[cat] = files
    return result


def format_text(result: dict, counts_only: bool) -> str:
    lines: list[str] = []
    for cat, files in result.items():
        label = CATEGORY_LABELS.get(cat, cat)
        lines.append(f"[{label}]  ({len(files)} files)")
        if not counts_only:
            for f in files:
                lines.append(f"  {f}")
            lines.append("")
    return "\n".join(lines)


def format_json(result: dict) -> str:
    output: dict = {}
    for cat, files in result.items():
        output[cat] = {
            "label": CATEGORY_LABELS.get(cat, cat),
            "count": len(files),
            "files": files,
        }
    return json.dumps(output, indent=2, ensure_ascii=False)


def format_csv(result: dict) -> str:
    lines = ["category,label,path"]
    for cat, files in result.items():
        label = CATEGORY_LABELS.get(cat, cat)
        for f in files:
            # CSV-safe quoting if needed
            safe_path = f'"{f}"' if ',' in f or '"' in f else f
            lines.append(f"{cat},{label},{safe_path}")
    return "\n".join(lines) + "\n"


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    raw_cats = args.category
    if "all" in raw_cats:
        categories = list(RESOURCE_DIRS.keys())
    else:
        valid = set(RESOURCE_DIRS.keys())
        for c in raw_cats:
            if c not in valid:
                print(f"Unknown category: {c} (valid: {', '.join(sorted(valid))})", file=sys.stderr)
                sys.exit(2)
        categories = [c for c in raw_cats if c in RESOURCE_DIRS]

    ext_filters = args.ext or []

    result = collect_resources(project_root, categories, ext_filters)

    if args.format == "json":
        rendered = format_json(result)
    elif args.format == "csv":
        rendered = format_csv(result)
    else:
        rendered = format_text(result, args.counts_only)

    if args.output == "-":
        print(rendered)
    else:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main()

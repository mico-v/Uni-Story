#!/usr/bin/env python3
"""Generate I18n localized resource path mapping table.

Scans the LocalizedResourcePaths.txt and the localized_resources/ directory
to produce a complete mapping of original paths → localized equivalents
for all supported locales.

Output: JSON/CSV/text mapping table suitable for tooling and documentation.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Optional

from utils import (
    CliError, PROJECT_ROOT, RESOURCES_DIR,
    resolve_project_root, write_output, format_json,
)


LOCALIZED_PATHS_FILE = "LocalizedResourcePaths.txt"
LOCALIZED_RESOURCES_DIR = "localized_resources"
LOCALIZED_DIRS = ["LocalizedResources", "localized_resources"]


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Generate I18n localized resource path mapping table.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "csv"), default="text", help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--locales", nargs="*", default=[], help="filter by locale codes (e.g. English ChineseSimplified)")
    return p


def discover_locales(resources_dir: Path) -> list[str]:
    """Discover available locale directories under LocalizedResources/ and localized_resources/."""
    locales = []
    for loc_dir_name in LOCALIZED_DIRS:
        loc_dir = resources_dir / loc_dir_name
        if loc_dir.is_dir():
            for d in loc_dir.iterdir():
                if d.is_dir() and not d.name.startswith(".") and d.name != "localized_strings":
                    if d.name not in locales:
                        locales.append(d.name)
    return sorted(locales)


def parse_localized_paths(project_root: Path) -> dict[str, list[str]]:
    """Parse LocalizedResourcePaths.txt into {locale: [paths]} mapping."""
    paths_file = project_root / "resources" / LOCALIZED_PATHS_FILE
    result: dict[str, list[str]] = {}

    if not paths_file.is_file():
        return result

    for line in paths_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # Format: LocalizedResources/<Locale>/<category>/<name>
        parts = line.split("/")
        if len(parts) >= 4 and parts[0] == "LocalizedResources":
            locale = parts[1]
            if locale not in result:
                result[locale] = []
            result[locale].append(line)

    return result


def scan_localized_resources(project_root: Path, locales: list[str]) -> dict:
    """Scan the file system for all localized resource files.

    Returns {locale: [{original_path, localized_path, exists, size}]}.
    """
    res_dir = project_root / "resources"
    result: dict = {}

    for locale in locales:
        all_files = []
        found_any = False
        for loc_dir_name in LOCALIZED_DIRS:
            locale_dir = res_dir / loc_dir_name / locale
            if not locale_dir.is_dir():
                continue
            found_any = True
            for dirpath, _, filenames in sorted(os.walk(locale_dir)):
                for fname in sorted(filenames):
                    if fname.startswith(".") or fname.endswith(".import"):
                        continue
                    fpath = Path(dirpath) / fname
                    rel_path = fpath.relative_to(res_dir).as_posix()
                    all_files.append({
                        "localized_path": rel_path,
                        "size": fpath.stat().st_size,
                    })
        result[locale] = {"files": all_files, "count": len(all_files), "exists": found_any}

    return result


def build_mapping_table(project_root: Path, locales: list[str]) -> dict:
    """Build a complete mapping table from all sources."""
    if not locales:
        locales = discover_locales(project_root / "resources")

    parsed = parse_localized_paths(project_root)
    scanned = scan_localized_resources(project_root, locales)

    # Build locale-info objects
    locales_info: dict = {}
    for locale in locales:
        parsed_count = len(parsed.get(locale, []))
        scan_info = scanned.get(locale, {"files": [], "count": 0, "exists": False})
        locales_info[locale] = {
            "parsed_entries": parsed_count,
            "scanned_files": scan_info["count"],
            "exists": scan_info["exists"],
            "parsed_paths": parsed.get(locale, []),
            "scanned_files_list": scan_info.get("files", []),
        }

    # Cross-reference: which parsed paths have actual files?
    cross_ref: list = []
    for locale in locales:
        for pp in parsed.get(locale, []):
            # Check if a corresponding file exists
            # pp = "LocalizedResources/English/scenarios/ch1"
            # Look for files starting with this prefix
            matches = []
            for f in scanned.get(locale, {}).get("files", []):
                lp = f["localized_path"]
                # Normalize: pp can be "LocalizedResources/English/..." or "localized_resources/English/..."
                for prefix_variant in [pp, pp.replace("LocalizedResources", "localized_resources", 1), pp.replace("localized_resources", "LocalizedResources", 1)]:
                    if lp.startswith(prefix_variant) or lp == prefix_variant:
                        if lp not in matches:
                            matches.append(lp)
            cross_ref.append({
                "locale": locale,
                "parsed_path": pp,
                "resolved_files": matches,
                "resolved": len(matches) > 0,
            })

    return {
        "locales": locales,
        "locale_count": len(locales),
        "locales_info": locales_info,
        "cross_reference": cross_ref,
        "total_parsed": sum(len(v) for v in parsed.values()),
        "total_scanned": sum(info["count"] for info in scanned.values()),
    }


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    data = build_mapping_table(project_root, args.locales)

    if args.format == "json":
        write_output(args.output, format_json(data))
    elif args.format == "csv":
        lines = ["locale,type,path,resolved,file_count"]
        for locale, info in data["locales_info"].items():
            for pp in info["parsed_paths"]:
                lines.append(f'{locale},parsed,{pp},,')
        for cr in data["cross_reference"]:
            for rf in cr["resolved_files"]:
                lines.append(f'{cr["locale"]},resolved,{cr["parsed_path"]},yes,1')
            if not cr["resolved_files"]:
                lines.append(f'{cr["locale"]},resolved,{cr["parsed_path"]},no,0')
        write_output(args.output, "\n".join(lines) + "\n")
    else:
        lines: list[str] = []
        lines.append("=== I18n Localized Resource Paths ===")
        lines.append(f"Locales: {', '.join(data['locales'])}")
        lines.append(f"Total parsed entries: {data['total_parsed']}")
        lines.append(f"Total scanned files: {data['total_scanned']}")
        lines.append("")
        for locale, info in data["locales_info"].items():
            lines.append(f"[{locale}]")
            lines.append(f"  Parsed entries: {info['parsed_entries']}")
            lines.append(f"  Scanned files:  {info['scanned_files']}")
            if info["parsed_paths"]:
                lines.append(f"  Paths:")
                for pp in info["parsed_paths"]:
                    lines.append(f"    {pp}")
            lines.append("")

        # Cross-reference summary
        missing = [cr for cr in data["cross_reference"] if not cr["resolved"]]
        if missing:
            lines.append("=== Missing Files ===")
            for cr in missing:
                lines.append(f"  [{cr['locale']}] {cr['parsed_path']} → NO FILE FOUND")
        else:
            lines.append("All parsed paths resolved successfully.")

        write_output(args.output, "\n".join(lines))


if __name__ == "__main__":
    main()

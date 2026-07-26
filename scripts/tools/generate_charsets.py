#!/usr/bin/env python3
"""Generate font character sets from NovaScript scenario files.

Scans all scenario .txt files and extracts the unique set of characters
used in dialogue, text, and annotations.  This helps reduce font texture
size by limiting glyph sets to only what is actually used.

Output: one text file per scenario (containing unique chars) plus a
combined all-chars file, all written to `resources/fonts/charsets/`.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Optional

from utils import (
    CliError, PROJECT_ROOT, RESOURCES_DIR, SCENARIOS_DIR,
    resolve_project_root, write_output, format_json,
    iter_scenario_files, strip_code_blocks,
)


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Generate font character sets from NovaScript scenarios.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "csv"), default="text", help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--all-scenarios", action="store_true", help="process all scenarios (default)")
    p.add_argument("--scenario", metavar="FILE", help="process a single scenario file")
    p.add_argument("--output-dir", metavar="DIR", help="write individual files to DIR (default: resources/fonts/charsets/)")
    p.add_argument("--generate-files", action="store_true", help="write .charset files for each scenario + combined")
    p.add_argument("--sort-by", choices=("unicode", "frequency", "nlp"), default="unicode",
                   help="character sort order (default: unicode)")
    return p


def extract_unique_chars(text: str) -> OrderedDict[str, int]:
    """Extract unique characters with frequency count, preserving CJK and punctuation.

    Strips NovaScript code blocks first, then collects every character.
    Returns OrderedDict sorted by unicode codepoint (default) with char→frequency.
    """
    clean = strip_code_blocks(text)
    freq: OrderedDict[str, int] = OrderedDict()
    for ch in clean:
        freq[ch] = freq.get(ch, 0) + 1
    # Sort by unicode codepoint
    sorted_items = sorted(freq.items(), key=lambda x: ord(x[0]))
    return OrderedDict(sorted_items)


def sort_chars_by_frequency(chars: OrderedDict[str, int]) -> str:
    """Return characters sorted by frequency (most common first)."""
    sorted_items = sorted(chars.items(), key=lambda x: (-x[1], ord(x[0])))
    return "".join(ch for ch, _ in sorted_items)


def sort_chars_by_unicode(chars: OrderedDict[str, int]) -> str:
    """Return characters sorted by unicode codepoint."""
    return "".join(chars.keys())


def classify_chars(chars_str: str) -> dict:
    """Classify characters into categories: CJK, Latin, digit, punct, other."""
    result = {
        "cjk": [],
        "latin": [],
        "digit": [],
        "space": [],
        "punct_cjk": [],
        "punct_ascii": [],
        "other": [],
    }
    for ch in chars_str:
        cp = ord(ch)
        if ch == " " or ch == "\t" or ch == "\n":
            result["space"].append(ch)
        elif cp >= 0x4E00 and cp <= 0x9FFF:
            result["cjk"].append(ch)
        elif cp >= 0x3400 and cp <= 0x4DBF:
            result["cjk"].append(ch)
        elif (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A):
            result["latin"].append(ch)
        elif cp >= 0x30 and cp <= 0x39:
            result["digit"].append(ch)
        elif cp >= 0x3000 and cp <= 0x303F:
            result["punct_cjk"].append(ch)
        elif cp >= 0xFF00 and cp <= 0xFFEF:
            if cp >= 0xFF01 and cp <= 0xFF5E:
                result["punct_cjk"].append(ch)
            else:
                result["other"].append(ch)
        elif cp < 0x80:
            result["punct_ascii"].append(ch)
        else:
            result["other"].append(ch)
    return {k: "".join(v) for k, v in result.items()}


def generate_charsets(
    project_root: Path,
    scenario_file: Optional[str] = None,
    sort_by: str = "unicode",
) -> dict:
    """Generate character set analysis for scenarios."""
    result: dict = {"per_file": {}, "combined": {}}

    if scenario_file:
        path = Path(project_root) / "resources" / "scenarios" / scenario_file
        files = [path] if path.is_file() else []
    else:
        files = list(iter_scenario_files(project_root))

    all_chars: OrderedDict[str, int] = OrderedDict()

    for sf in files:
        text = sf.read_text(encoding="utf-8")
        chars = extract_unique_chars(text)
        char_str = sort_chars_by_unicode(chars) if sort_by == "unicode" else sort_chars_by_frequency(chars)
        result["per_file"][sf.name] = {
            "char_count": len(chars),
            "characters": char_str,
            "classification": classify_chars(char_str),
        }
        for ch, count in chars.items():
            all_chars[ch] = all_chars.get(ch, 0) + count

    # Combined
    all_sorted = OrderedDict(sorted(all_chars.items(), key=lambda x: ord(x[0])))
    all_str = sort_chars_by_unicode(all_sorted) if sort_by == "unicode" else sort_chars_by_frequency(all_sorted)
    result["combined"] = {
        "total_unique": len(all_sorted),
        "total_scenarios": len(files),
        "characters": all_str,
        "classification": classify_chars(all_str),
    }
    return result


def write_charset_files(project_root: Path, data: dict) -> None:
    """Write .charset files to resources/fonts/charsets/."""
    out_dir = project_root / "resources" / "fonts" / "charsets"
    out_dir.mkdir(parents=True, exist_ok=True)

    for fname, info in data["per_file"].items():
        stem = Path(fname).stem
        out_path = out_dir / f"{stem}.charset"
        out_path.write_text(info["characters"], encoding="utf-8")

    combined_path = out_dir / "all.charset"
    combined_path.write_text(data["combined"]["characters"], encoding="utf-8")

    # Also write a classification report
    report_path = out_dir / "charset_report.json"
    report_path.write_text(format_json(data), encoding="utf-8")

    print(f"Wrote {len(data['per_file'])} charset files + combined to {out_dir}", file=sys.stderr)


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    data = generate_charsets(project_root, args.scenario, args.sort_by)

    if args.generate_files:
        write_charset_files(project_root, data)

    if args.format == "json":
        write_output(args.output, format_json(data))
    elif args.format == "csv":
        lines = ["scenario,unique_chars,cjk_chars,latin_chars,digit_chars"]
        for fname, info in data["per_file"].items():
            cls = info["classification"]
            lines.append(f"{fname},{info['char_count']},{len(cls.get('cjk',''))},{len(cls.get('latin',''))},{len(cls.get('digit',''))}")
        lines.append(f"COMBINED,{data['combined']['total_unique']},"
                     f"{len(data['combined']['classification'].get('cjk',''))},"
                     f"{len(data['combined']['classification'].get('latin',''))},"
                     f"{len(data['combined']['classification'].get('digit',''))}")
        write_output(args.output, "\n".join(lines) + "\n")
    else:
        lines: list[str] = []
        lines.append(f"=== Uni-Story Font Character Set Generator ===")
        lines.append(f"Scenarios analyzed: {data['combined']['total_scenarios']}")
        lines.append(f"Combined unique characters: {data['combined']['total_unique']}")
        lines.append("")
        cl = data["combined"]["classification"]
        lines.append(f"  CJK:  {len(cl.get('cjk',''))} chars")
        lines.append(f"  Latin: {len(cl.get('latin',''))} chars  {cl.get('latin','')}")
        lines.append(f"  Digit: {len(cl.get('digit',''))} chars  {cl.get('digit','')}")
        lines.append(f"  CJK Punct: {len(cl.get('punct_cjk',''))} chars")
        lines.append(f"  ASCII Punct: {len(cl.get('punct_ascii',''))} chars")
        lines.append(f"  Other: {len(cl.get('other',''))} chars")
        lines.append("")
        lines.append("Per scenario:")
        for fname, info in data["per_file"].items():
            lines.append(f"  {fname}: {info['char_count']} unique chars")

        write_output(args.output, "\n".join(lines))


if __name__ == "__main__":
    main()

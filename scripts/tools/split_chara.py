#!/usr/bin/env python3
"""split_chara.py — split a NovaScript scenario into per-character files.

Each output file is named after the character role (e.g., `王二宫.txt`) and
contains only that character's dialogue plus surrounding narration and code
blocks.  The tool preserves original line numbers as comments for traceability.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Optional

SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


DIALOGUE_PATTERN = re.compile(r'^(.+?)：：\u201c(.+?)\u201d\s*$')
CODE_BLOCK_START = re.compile(r'^@?<\|')
CODE_BLOCK_END = re.compile(r'\|>\s*$')


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Split a NovaScript scenario into per-character files.",
    )
    parser.add_argument(
        "--input",
        "-i",
        metavar="PATH",
        required=True,
        help="input NovaScript scenario file",
    )
    parser.add_argument(
        "--output-dir",
        "-o",
        metavar="DIR",
        default="split_output",
        help="directory for per-character output files (default: split_output)",
    )
    parser.add_argument(
        "--include-narration",
        action="store_true",
        help="include narration lines in each character's file",
    )
    parser.add_argument(
        "--include-code",
        action="store_true",
        help="include code blocks in each character's file",
    )
    parser.add_argument(
        "--project",
        metavar="PATH",
        help="project root (defaults to repository root)",
    )
    return parser


def resolve_project_root(explicit: str | None) -> Path:
    if explicit:
        p = Path(explicit).resolve()
        if not p.is_dir():
            raise CliError(f"project root not found: {p}")
        return p
    return PROJECT_ROOT


def split_scenario(
    filepath: Path,
    output_dir: Path,
    include_narration: bool,
    include_code: bool,
) -> dict:
    """Split the scenario and write per-character files.

    Returns a report: {role: {"lines": count, "path": str, "dialogue_count": count}}
    """
    try:
        raw = filepath.read_text(encoding="utf-8")
    except Exception as exc:
        raise CliError(f"cannot read {filepath}: {exc}") from exc

    lines = raw.splitlines()
    actors: dict[str, list[str]] = {}
    narration: list[str] = []
    code_blocks_raw: list[str] = []

    in_code = False
    current_code: list[str] = []

    for lineno, line in enumerate(lines, start=1):
        stripped = line.strip()

        # Track code blocks
        if CODE_BLOCK_START.match(stripped):
            in_code = True
            current_code = [f"# L{lineno}: {line}"]
            continue
        if in_code:
            current_code.append(f"# L{lineno}: {line}")
            if CODE_BLOCK_END.match(stripped):
                in_code = False
                code_blocks_raw.append("\n".join(current_code))
            continue

        # Dialogue detection
        m = DIALOGUE_PATTERN.match(stripped)
        if m:
            role = m.group(1).strip()
            actors.setdefault(role, []).append(f"# L{lineno}: {line}")
            continue

        # Narration line
        narration.append(f"# L{lineno}: {line}")

    # Ensure all known roles have entries
    for role in list(actors.keys()):
        if role not in actors:
            actors[role] = []

    output_dir.mkdir(parents=True, exist_ok=True)
    report: dict = {}

    # Write per-character files
    for role, role_lines in sorted(actors.items()):
        safe_name = re.sub(r'[<>:"/\\|?*]', '_', role)
        out_path = output_dir / f"{safe_name}.txt"
        out_lines: list[str] = [
            f"# Character: {role}",
            f"# Split from: {filepath.name}",
            f"#",
        ]

        if include_code:
            out_lines.append("")
            for cb in code_blocks_raw:
                out_lines.append(cb)

        if include_narration:
            out_lines.append("")
            out_lines.extend(narration)

        out_lines.append("")
        out_lines.extend(role_lines)

        content = "\n".join(out_lines).strip() + "\n"
        out_path.write_text(content, encoding="utf-8")
        report[role] = {
            "path": str(out_path),
            "lines": len(out_lines),
            "dialogue_count": len(role_lines),
        }

    return report


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    input_path = Path(args.input)
    if not input_path.is_absolute():
        cwd_fp = Path.cwd() / input_path
        proj_fp = project_root / input_path
        input_path = cwd_fp if cwd_fp.exists() else proj_fp
    if not input_path.is_file():
        print(f"split_chara: error: input file not found: {input_path}", file=sys.stderr)
        sys.exit(2)

    output_dir = Path(args.output_dir)
    if not output_dir.is_absolute():
        output_dir = Path.cwd() / output_dir

    try:
        report = split_scenario(input_path, output_dir, args.include_narration, args.include_code)
    except CliError as e:
        print(f"split_chara: error: {e}", file=sys.stderr)
        sys.exit(2)

    print(f"Split {input_path.name} into {len(report)} character files in {output_dir}:")
    total_dialogues = 0
    for role, info in sorted(report.items()):
        dc = info["dialogue_count"]
        total_dialogues += dc
        print(f"  {role}: {dc} dialogue(s) → {info['path']}")
    print(f"\nTotal: {total_dialogues} dialogue(s) across {len(report)} character(s)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""merge.py — merge multiple character-split scenario files into a single NovaScript script.

Each input file should use `#角色名` header lines to mark which character owns the
following dialogue lines.  Lines not attributed to any role are treated as narration.

The tool interleaves the files chronologically, preserving the original line order
within each file while merging across files based on an optional timestamp or
manual ordering marker.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Optional, Sequence

SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


# Matches `角色名：："台词内容"` style dialogue lines.
DIALOGUE_PATTERN = re.compile(r'^(.+?)：：\u201c(.+?)\u201d\s*$')

# Matches `#角色名` role markers.
ROLE_MARKER = re.compile(r'^#(.+?)\s*$')

# Matches NovaScript code/control blocks: <|...|> or @<|...|>
CODE_BLOCK_START = re.compile(r'^@?<\|')
CODE_BLOCK_END = re.compile(r'\|>\s*$')


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Merge character-split scenario files into a single NovaScript script.",
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        metavar="FILE",
        help="character-split scenario files to merge",
    )
    parser.add_argument(
        "--output",
        "-o",
        metavar="PATH",
        default="-",
        help="write the merged script to PATH, or '-' for stdout (default: -)",
    )
    parser.add_argument(
        "--preserve-order",
        choices=("file", "interleave"),
        default="file",
        help="how to interleave lines across files (default: file — keep each file's content contiguous)",
    )
    parser.add_argument(
        "--title",
        metavar="TITLE",
        help="top-level chapter/script title to prepend",
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


def _is_dialogue(line: str) -> bool:
    return bool(DIALOGUE_PATTERN.match(line))


def _is_role_marker(line: str) -> bool:
    return bool(ROLE_MARKER.match(line))


def _in_code_block(lines: list[str], idx: int) -> bool:
    """Check if line at idx is inside a code block (rough heuristic)."""
    depth = 0
    for i, line in enumerate(lines[: idx + 1]):
        if CODE_BLOCK_START.match(line.strip()):
            depth += 1
        if CODE_BLOCK_END.match(line.strip()) and depth > 0:
            depth -= 1
    return depth > 0


def _guess_role(line: str, current_role: str) -> str:
    m = DIALOGUE_PATTERN.match(line)
    if m:
        return m.group(1).strip()
    return current_role


def parse_character_file(filepath: Path) -> list[dict]:
    """Parse a character-split file into a list of blocks.

    Each block is a dict with:
      - role: character name (or "" for narration)
      - lines: list of text lines
      - code_blocks: list of code block strings
    """
    try:
        raw = filepath.read_text(encoding="utf-8")
    except Exception as exc:
        raise CliError(f"cannot read {filepath}: {exc}") from exc

    raw_lines = raw.splitlines()

    # First pass: identify role sections
    sections: list[dict] = []
    current_role = ""
    current_lines: list[str] = []
    current_code: list[str] = []
    in_code = False

    for line in raw_lines:
        stripped = line.strip()

        # Role marker
        role_match = ROLE_MARKER.match(stripped)
        if role_match and not in_code:
            # Flush current section
            if current_lines or current_code:
                sections.append({
                    "role": current_role,
                    "lines": current_lines[:],
                    "code_blocks": current_code[:],
                })
            current_role = role_match.group(1).strip()
            current_lines = []
            current_code = []
            continue

        # Code block tracking
        if CODE_BLOCK_START.match(stripped):
            in_code = True
            current_code.append(line)
            continue
        if in_code:
            current_code.append(line)
            if CODE_BLOCK_END.match(stripped):
                in_code = False
            continue

        # Regular line
        current_lines.append(line)

    # Flush final section
    if current_lines or current_code:
        sections.append({
            "role": current_role,
            "lines": current_lines[:],
            "code_blocks": current_code[:],
        })

    return sections


def _normalize_role(role: str) -> str:
    """Normalize role name: strip whitespace, remove duplicates."""
    return role.strip()


def merge_files(
    filepaths: list[Path],
    preserve_order: str,
    title: str | None,
) -> str:
    """Merge multiple character-split files into a single NovaScript output."""
    all_sections: list[dict] = []
    all_roles: set[str] = set()

    for fp in filepaths:
        sections = parse_character_file(fp)
        for sec in sections:
            role = _normalize_role(sec["role"])
            sec["role"] = role
            if role:
                all_roles.add(role)
        all_sections.extend(sections)

    if not all_sections:
        return ""

    output_lines: list[str] = []

    # Add title header
    if title:
        output_lines.append(f"@<|")
        output_lines.append(f"label('{title}', '{title}')")
        output_lines.append(f"is_start()")
        output_lines.append(f"|>")
        output_lines.append("")

    # Collect all roles for the header
    sorted_roles = sorted(all_roles)
    if sorted_roles:
        output_lines.append("<|")
        for role in sorted_roles:
            output_lines.append(f"auto_voice_on('{role}', 001001)")
        output_lines.append("|>")
        output_lines.append("")

    # Output sections interleaved
    if preserve_order == "file":
        # Keep each file's sections contiguous
        current_file = None
        for fp, sections in zip(filepaths, [parse_character_file(f) for f in filepaths]):
            for sec in sections:
                for code_block in sec.get("code_blocks", []):
                    output_lines.append(code_block)
                for line in sec.get("lines", []):
                    output_lines.append(line)
    else:
        # Interleave: round-robin through sections
        for sec in all_sections:
            for code_block in sec.get("code_blocks", []):
                output_lines.append(code_block)
            for line in sec.get("lines", []):
                output_lines.append(line)

    result = "\n".join(output_lines)
    # Clean up excessive blank lines
    result = re.sub(r'\n{3,}', '\n\n', result)
    return result.strip() + "\n"


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    filepaths: list[Path] = []
    for raw in args.inputs:
        fp = Path(raw)
        if not fp.is_absolute():
            # Try relative to cwd, then relative to project
            cwd_fp = Path.cwd() / fp
            proj_fp = project_root / fp
            fp = cwd_fp if cwd_fp.exists() else proj_fp
        if not fp.is_file():
            print(f"merge: error: file not found: {fp}", file=sys.stderr)
            sys.exit(2)
        filepaths.append(fp)

    try:
        result = merge_files(filepaths, args.preserve_order, args.title)
    except CliError as e:
        print(f"merge: error: {e}", file=sys.stderr)
        sys.exit(2)

    if args.output == "-":
        sys.stdout.write(result)
    else:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(result, encoding="utf-8")


if __name__ == "__main__":
    main()

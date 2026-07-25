#!/usr/bin/env python3
"""strip_code.py — strip all <|...|> code blocks from a NovaScript scenario, outputting pure text.

Useful for giving the script to voice actors, editors, or translation teams who
only need the readable content without engine directives.

Part of the strip_code family:
  strip_code.py         → plain text
  strip_code_docx.py    → Word (.docx)
  strip_code_tex.py     → LaTeX
  strip_code_xlsx.py    → Excel (.xlsx, columns: speaker/text/location)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Optional, Sequence

SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


DIALOGUE_PATTERN = re.compile(r'^(.+?)：：\u201c(.+?)\u201d\s*$')
CODE_BLOCK_START = re.compile(r'^@?<\|')
CODE_BLOCK_END = re.compile(r'\|>\s*$')
TODO_PATTERN = re.compile(r'（TODO[：:].*?）|\(TODO[：:].*?\)', re.IGNORECASE)
STAGE_DIRECTION = re.compile(r'^\[.*\]\s*$')  # e.g., [Enter scene]


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Strip NovaScript code blocks and output pure text.",
    )
    parser.add_argument(
        "--input",
        "-i",
        metavar="PATH",
        required=True,
        help="input NovaScript scenario file",
    )
    parser.add_argument(
        "--output",
        "-o",
        metavar="PATH",
        default="-",
        help="write stripped output to PATH, or '-' for stdout (default: -)",
    )
    parser.add_argument(
        "--keep-todo",
        action="store_true",
        help="preserve (TODO: ...) annotations as comments",
    )
    parser.add_argument(
        "--keep-stage-directions",
        action="store_true",
        help="preserve [stage directions] as comments",
    )
    parser.add_argument(
        "--keep-speaker-names",
        action="store_true",
        help="preserve speaker names before dialogue (e.g., '王二宫: ...')",
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


def strip_code(
    filepath: Path,
    keep_todo: bool = False,
    keep_stage_directions: bool = False,
    keep_speaker_names: bool = False,
) -> str:
    """Strip code blocks from a NovaScript file, return plain text."""
    try:
        raw = filepath.read_text(encoding="utf-8")
    except Exception as exc:
        raise CliError(f"cannot read {filepath}: {exc}") from exc

    lines = raw.splitlines()
    output: list[str] = []
    in_code = False
    current_code_block: list[str] = []

    for line in lines:
        stripped = line.strip()

        if CODE_BLOCK_START.match(stripped):
            in_code = True
            current_code_block = [line]
            continue
        if in_code:
            current_code_block.append(line)
            if CODE_BLOCK_END.match(stripped):
                in_code = False
                # Extract TODO comments from code block
                if keep_todo:
                    for cl in current_code_block:
                        todos = TODO_PATTERN.findall(cl)
                        for todo in todos:
                            output.append(f"// {todo}")
                current_code_block = []
            continue

        if not stripped:
            output.append("")
            continue

        m = DIALOGUE_PATTERN.match(stripped)
        if m:
            speaker = m.group(1).strip()
            text = m.group(2).strip()
            if keep_speaker_names:
                output.append(f"{speaker}: {text}")
            else:
                output.append(text)
            continue

        # Narration — preserve
        if keep_stage_directions and STAGE_DIRECTION.match(stripped):
            output.append(f"// {stripped[1:-1]}")
        elif keep_todo and TODO_PATTERN.match(stripped):
            output.append(f"// {stripped}")
        else:
            output.append(stripped)

    # Clean up
    result = "\n".join(output)
    result = re.sub(r'\n{3,}', '\n\n', result)
    return result.strip() + "\n"


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
        print(f"strip_code: error: input file not found: {input_path}", file=sys.stderr)
        sys.exit(2)

    try:
        result = strip_code(
            input_path,
            keep_todo=args.keep_todo,
            keep_stage_directions=args.keep_stage_directions,
            keep_speaker_names=args.keep_speaker_names,
        )
    except CliError as e:
        print(f"strip_code: error: {e}", file=sys.stderr)
        sys.exit(2)

    if args.output == "-":
        sys.stdout.write(result)
    else:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(result, encoding="utf-8")


if __name__ == "__main__":
    main()

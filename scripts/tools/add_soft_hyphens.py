#!/usr/bin/env python3
"""add_soft_hyphens.py — insert soft hyphens (U+00AD) into Chinese/Japanese text.

Useful for visual novel text rendering where automatic line-breaking at
character boundaries would be incorrect.  The soft hyphen tells the layout
engine where it is acceptable to break a line.

Inspired by Nova's add_soft_hyphens.py.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path
from typing import Optional

SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]

SOFT_HYPHEN = "\u00AD"


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


DIALOGUE_PATTERN = re.compile(r'^(.+?)：：\u201c(.+?)\u201d\s*$')
CODE_BLOCK_START = re.compile(r'^@?<\|')
CODE_BLOCK_END = re.compile(r'\|>\s*$')

# CJK character range
CJK_RANGES = [
    (0x4E00, 0x9FFF),   # CJK Unified Ideographs
    (0x3400, 0x4DBF),   # CJK Unified Ideographs Extension A
    (0x20000, 0x2A6DF), # CJK Unified Ideographs Extension B
    (0x2A700, 0x2B73F), # CJK Unified Ideographs Extension C
    (0x2B740, 0x2B81F), # CJK Unified Ideographs Extension D
    (0x2B820, 0x2CEAF), # CJK Unified Ideographs Extension E
    (0xF900, 0xFAFF),   # CJK Compatibility Ideographs
    (0x2F800, 0x2FA1F), # CJK Compatibility Ideographs Supplement
    (0x3000, 0x303F),   # CJK Symbols and Punctuation
    (0xFF00, 0xFFEF),   # Halfwidth and Fullwidth Forms
    (0x3040, 0x309F),   # Hiragana
    (0x30A0, 0x30FF),   # Katakana
    (0x31F0, 0x31FF),   # Katakana Phonetic Extensions
]


def _is_cjk(c: str) -> bool:
    cp = ord(c)
    for lo, hi in CJK_RANGES:
        if lo <= cp <= hi:
            return True
    return False


def _is_cjk_punctuation(c: str) -> bool:
    """Characters that should not have a break opportunity before them."""
    return c in "，。、；：！？」』】》）》\"'.],:;!?)"


def _insert_soft_hyphens(text: str, language: str) -> str:
    """Insert soft hyphens between adjacent CJK characters where safe."""
    result: list[str] = []
    prev_is_cjk = False
    prev_is_punct = False

    for i, ch in enumerate(text):
        is_cjk = _is_cjk(ch)
        is_punct = _is_cjk_punctuation(ch)

        # Insert soft hyphen between two CJK characters that aren't punctuation
        if prev_is_cjk and is_cjk and not prev_is_punct and not is_punct:
            result.append(SOFT_HYPHEN)

        # Also insert after a Latin char followed by CJK (mixed scripts)
        if not prev_is_cjk and is_cjk and i > 0 and not prev_is_punct:
            prev_code = ord(text[i - 1])
            if (0x0020 <= prev_code <= 0x007E) or (0x00A0 <= prev_code <= 0x024F):
                result.append(SOFT_HYPHEN)

        result.append(ch)
        prev_is_cjk = is_cjk
        prev_is_punct = is_punct

    return "".join(result)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Insert soft hyphens into CJK text for better line-breaking.",
    )
    parser.add_argument(
        "--input", "-i", metavar="PATH", required=True,
        help="input NovaScript scenario file",
    )
    parser.add_argument(
        "--output", "-o", metavar="PATH", default="-",
        help="write output to PATH, or '-' for stdout (default: -)",
    )
    parser.add_argument(
        "--language", choices=("zh", "ja"),
        default="zh",
        help="language for typographic rules (default: zh)",
    )
    parser.add_argument(
        "--text-only", action="store_true",
        help="strip code blocks and only process dialogue/narration text",
    )
    parser.add_argument(
        "--min-length", type=int, default=4,
        help="minimum line length (in chars) to insert hyphens (default: 4)",
    )
    parser.add_argument(
        "--project", metavar="PATH",
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


def process_file(
    filepath: Path,
    language: str,
    text_only: bool,
    min_length: int,
) -> str:
    try:
        raw = filepath.read_text(encoding="utf-8")
    except Exception as exc:
        raise CliError(f"cannot read {filepath}: {exc}") from exc

    lines = raw.splitlines()
    output: list[str] = []
    in_code = False

    for line in lines:
        stripped = line.strip()

        if CODE_BLOCK_START.match(stripped):
            in_code = True
            output.append(line)
            continue
        if in_code:
            output.append(line)
            if CODE_BLOCK_END.match(stripped):
                in_code = False
            continue

        if text_only and stripped:
            # Process only dialogue text
            m = DIALOGUE_PATTERN.match(stripped)
            if m:
                speaker = m.group(1)
                text = m.group(2)
                if len(text) >= min_length:
                    processed_text = _insert_soft_hyphens(text, language)
                    output.append(f'{speaker}：：“{processed_text}”')
                else:
                    output.append(line)
            elif len(stripped) >= min_length:
                output.append(_insert_soft_hyphens(line, language))
            else:
                output.append(line)
        elif not text_only and stripped:
            if len(stripped) >= min_length:
                output.append(_insert_soft_hyphens(line, language))
            else:
                output.append(line)
        else:
            output.append(line)

    return "\n".join(output) + "\n"


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
        print(f"add_soft_hyphens: error: input file not found: {input_path}", file=sys.stderr)
        sys.exit(2)

    try:
        # Count soft hyphens inserted
        original = input_path.read_text(encoding="utf-8")
        result = process_file(input_path, args.language, args.text_only, args.min_length)
        inserted = result.count(SOFT_HYPHEN) - original.count(SOFT_HYPHEN)
    except CliError as e:
        print(f"add_soft_hyphens: error: {e}", file=sys.stderr)
        sys.exit(2)

    if args.output == "-":
        sys.stdout.write(result)
    else:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(result, encoding="utf-8")

    print(f"Inserted {inserted} soft hyphen(s) (language={args.language})", file=sys.stderr)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Common utilities shared across Uni-Story Python tools."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Callable, Iterable, Iterator, List, Optional, Sequence, TypeVar


# ── Path resolution ────────────────────────────────────────────────
SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]
RESOURCES_DIR = PROJECT_ROOT / "resources"
SCENARIOS_DIR = RESOURCES_DIR / "scenarios"
TOOLS_DIR = SCRIPT_PATH.parent


T = TypeVar("T")


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


# ── CLI helpers ─────────────────────────────────────────────────────
def add_common_args(parser: argparse.ArgumentParser) -> None:
    """Add --project, --format, --output args to a parser."""
    parser.add_argument(
        "--project",
        metavar="PATH",
        help="project root (defaults to repository root)",
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


def resolve_project_root(explicit: str | None) -> Path:
    """Resolve project root from optional explicit path."""
    if explicit:
        p = Path(explicit).resolve()
        if not p.is_dir():
            raise CliError(f"project root not found: {p}")
        return p
    return PROJECT_ROOT


def write_output(path_str: str, content: str) -> None:
    """Write content to output path (or stdout if '-')."""
    if path_str == "-":
        sys.stdout.write(content)
    else:
        output_path = Path(path_str)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(content, encoding="utf-8")


def exit_on_error(msg: str) -> None:
    """Print error message to stderr and exit with code 2."""
    print(msg, file=sys.stderr)
    sys.exit(2)


# ── Format helpers ──────────────────────────────────────────────────
def format_json(data: Any) -> str:
    """Format data as JSON with indentation."""
    return json.dumps(data, indent=2, ensure_ascii=False)


def format_csv(headers: List[str], rows: List[List[str]]) -> str:
    """Format data as CSV."""
    lines = [",".join(headers)]
    for row in rows:
        quoted = []
        for cell in row:
            s = str(cell)
            if "," in s or '"' in s or "\n" in s:
                s = '"' + s.replace('"', '""') + '"'
            quoted.append(s)
        lines.append(",".join(quoted))
    return "\n".join(lines) + "\n"


# ── File iteration ─────────────────────────────────────────────────
def iter_scenario_files(
    project_root: Path,
    ext: str = ".txt",
) -> Iterator[Path]:
    """Yield all scenario files in resources/scenarios (sorted)."""
    sc_dir = project_root / "resources" / "scenarios"
    if not sc_dir.is_dir():
        return
    for f in sorted(sc_dir.iterdir()):
        if f.is_file() and f.suffix == ext and not f.name.startswith("."):
            yield f


def iter_resource_files(
    project_root: Path,
    subdir: str,
    exts: Sequence[str] | None = None,
) -> Iterator[Path]:
    """Walk a subdirectory under resources/ and yield all files."""
    res_dir = project_root / "resources" / subdir
    if not res_dir.is_dir():
        return
    for dirpath, _, filenames in sorted(os.walk(res_dir)):
        for fname in sorted(filenames):
            if fname.startswith(".") or fname.endswith(".import"):
                continue
            if exts is not None:
                if not any(fname.lower().endswith(e.lower()) for e in exts):
                    continue
            yield Path(dirpath) / fname


def make_rel(path: Path, root: Path) -> str:
    """Return posix-style relative path from root."""
    return path.resolve().relative_to(root.resolve()).as_posix()


# ── NovaScript parsing ──────────────────────────────────────────────
NOVASCRIPT_CODE_BLOCK_RE = None  # lazy import


def _get_code_block_pattern():
    """Return regex for NovaScript code blocks <|...|>."""
    import re
    return re.compile(r'<\|(.*?)\|>', re.DOTALL)


def extract_code_blocks(text: str) -> List[str]:
    """Extract all NovaScript code blocks from text."""
    import re
    return re.findall(r'<\|(.*?)\|>', text, re.DOTALL)


def strip_code_blocks(text: str) -> str:
    """Remove all NovaScript code blocks, returning pure dialogue text."""
    import re
    return re.sub(r'<\|.*?\|>', '', text, flags=re.DOTALL)


def extract_dialogue_lines(text: str) -> List[tuple[str, str]]:
    """Extract (speaker, dialogue) tuples from stripped text.
    
    Recognizes patterns like:
    - 王二宫：："真没想到..."
    - 旁白：这是描述
    - "(no speaker)" for narration without speaker marker
    """
    import re
    clean = strip_code_blocks(text)
    lines: List[tuple[str, str]] = []
    
    # Pattern: SpeakerName：："dialogue" or SpeakerName："dialogue"
    pattern = re.compile(r'^(.+?)[：:][：:]\s*(.+)$', re.MULTILINE)
    for m in pattern.finditer(clean):
        speaker = m.group(1).strip()
        dialogue = m.group(2).strip()
        if speaker and dialogue:
            lines.append((speaker, dialogue))
    
    return lines


def parse_scenarios_dir(project_root: Path) -> dict[str, str]:
    """Return {filename: full_text} mapping for all scenario .txt files."""
    result: dict[str, str] = {}
    for sf in iter_scenario_files(project_root):
        result[sf.name] = sf.read_text(encoding="utf-8")
    return result


# ── I18n helpers ────────────────────────────────────────────────────
def load_localized_strings(project_root: Path, locale: str) -> dict:
    """Load localized strings JSON for a given locale."""
    path = project_root / "resources" / "localized_resources" / "localized_strings" / f"{locale}.json"
    if path.is_file():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def iter_i18n_locales(project_root: Path) -> Iterator[str]:
    """Yield available locale codes from localized_strings/*.json."""
    loc_dir = project_root / "resources" / "localized_resources" / "localized_strings"
    if not loc_dir.is_dir():
        return
    for f in sorted(loc_dir.iterdir()):
        if f.suffix == ".json" and not f.name.startswith("."):
            yield f.stem


# ── Output dispatch ─────────────────────────────────────────────────
def dispatch_output(
    fmt: str,
    output: str,
    text_formatter: Callable[[], str],
    data_formatter: Callable[[], Any],
    csv_formatter: Callable[[], tuple[List[str], List[List[str]]]],
) -> None:
    """Format and write output based on user-specified format."""
    if fmt == "json":
        rendered = format_json(data_formatter())
    elif fmt == "csv":
        headers, rows = csv_formatter()
        rendered = format_csv(headers, rows)
    else:
        rendered = text_formatter()
    write_output(output, rendered)

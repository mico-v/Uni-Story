#!/usr/bin/env python3
"""NovaScript parser — read and analyze NovaScript .txt scenario files.

This is a pure-Python reference parser inspired by the Nova C# parser.
It tokenizes NovaScript files into blocks (eager code, lazy code, text),
extracts metadata, and provides analysis functions.

Unlike the Godot runtime parser (ScriptLoader.gd), this tool does NOT
compile or execute GDScript.  It only performs static syntactic analysis.

Usage:
    nova_script_parser.py                          # parse all scenarios, show summary
    nova_script_parser.py --scenario ch1.txt       # parse single scenario
    nova_script_parser.py --format json            # JSON output
    nova_script_parser.py --validate               # validate block structure
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator, List, Optional, Tuple

from utils import (
    CliError, PROJECT_ROOT,
    resolve_project_root, write_output, format_json,
    iter_scenario_files,
)


# ── Data types ──────────────────────────────────────────────────────

@dataclass
class Block:
    """A single NovaScript block."""
    kind: str               # "eager", "lazy", or "text"
    content: str            # Raw inner content (code or text)
    start_line: int         # 1-indexed line where block starts
    end_line: int           # 1-indexed line where block ends
    attributes: dict = field(default_factory=dict)  # parsed attributes


@dataclass
class Scenario:
    """A parsed NovaScript scenario file."""
    filename: str
    blocks: List[Block]
    total_lines: int = 0
    warnings: List[str] = field(default_factory=list)
    metadata: dict = field(default_factory=dict)

    @property
    def eager_count(self) -> int:
        return sum(1 for b in self.blocks if b.kind == "eager")

    @property
    def lazy_count(self) -> int:
        return sum(1 for b in self.blocks if b.kind == "lazy")

    @property
    def text_count(self) -> int:
        return sum(1 for b in self.blocks if b.kind == "text")

    @property
    def total_characters(self) -> int:
        return sum(len(b.content) for b in self.blocks)

    @property
    def dialogue_lines(self) -> int:
        """Count lines with speaker：： pattern in text blocks."""
        count = 0
        for b in self.blocks:
            if b.kind == "text":
                for line in b.content.split("\n"):
                    if "：：" in line or "::" in line:
                        count += 1
        return count


# ── Parser ──────────────────────────────────────────────────────────

NOVASCRIPT_BLOCK_RE = re.compile(
    # Eager blocks: <|  ...  |>
    # Lazy blocks:  @<| ...  |>
    # Text: everything else
    r'(?P<lazy>@<\|(?P<lazy_content>.*?)\|>)|'
    r'(?P<eager><\|(?P<eager_content>.*?)\|>)',
    re.DOTALL,
)

# Pattern for attributes at the start of an eager block
# e.g. <| [speed=fast, align=center] ... |>
ATTRIBUTE_RE = re.compile(r'^\s*\[\s*(.*?)\s*\]\s*', re.DOTALL)

# API call patterns
API_CALL_RE = re.compile(
    r'(label|jump_to|jump_if|branch|is_start|is_end|ending|show|hide|move|tint|'
    r'show_char|set_layer|hide_char|set_avatar|clear_avatar|'
    r'play_bgm|stop_bgm|play_se|play_voice|say|'
    r'auto_voice_on|auto_voice_off|set_auto_voice_delay|'
    r'cam|trans|set_box|vfx|clear_vfx|clear_effect|'
    r'capture_screen|post_fx|clear_post_fx|shake|'
    r'load_prefab|show_prefab|hide_prefab|destroy_prefab|'
    r'timeline|play_video|'
    r'show_toast|show_confirm|'
    r'set_var|get_var|has_var|add_var|'
    r'begin_interrupt|end_interrupt|'
    r'wait|print|'
    r'box_tint|box_anchor|box_alignment|box_offset|new_page|'
    r'input_on|input_off|ff_shortcut_on|ff_shortcut_off|'
    r'stop_auto_ff|stop_ff|immediate_step|auto_time|'
    r'text_delay|text_duration|text_scroll|set_text_speed|skip_mode_custom|'
    r'auto_fade_on|auto_fade_off|anim_hold_begin|anim_hold_end|'
    r'volume|get_current_position|text_easing|'
    r'set_box_pos|anim:trans_fade|box_hide_show|sync|'
    r'anim:volume|anim:move_to|anim:fade_to|anim:rotate_to|animate|'
    r'preload_asset|cancel_preload|'
    r'minigame|timeline|'
    r'is_unlocked_start|is_unlocked_end|'
    r'auto_voice_off_all|auto_voice_skip|say)'
    r'\s*\(.*?\)',
    re.DOTALL,
)


def parse_attributes(content: str) -> Tuple[dict, str]:
    """Parse [key=value, ...] attributes from block content start."""
    m = ATTRIBUTE_RE.match(content)
    if not m:
        return {}, content

    attr_str = m.group(1).strip()
    attrs: dict = {}
    for pair in attr_str.split(","):
        pair = pair.strip()
        if "=" in pair:
            key, val = pair.split("=", 1)
            attrs[key.strip()] = val.strip()
        else:
            attrs[pair] = True

    return attrs, content[m.end():]


def parse_scenario(text: str, filename: str = "unknown") -> Scenario:
    """Parse a NovaScript text into a Scenario object."""
    scenario = Scenario(filename=filename, blocks=[], total_lines=len(text.split("\n")))

    pos = 0
    lines_before = 0
    block_idx = 0

    for m in NOVASCRIPT_BLOCK_RE.finditer(text):
        # Text between blocks
        text_between = text[pos:m.start()]
        if text_between.strip():
            start_line = text[:pos].count("\n") + 1 if pos > 0 else 1
            scenario.blocks.append(Block(
                kind="text",
                content=text_between,
                start_line=start_line,
                end_line=text[:m.start()].count("\n") + 1,
            ))

        if m.group("eager"):
            content = m.group("eager_content")
            start_line = text[:m.start()].count("\n") + 1
            attrs, content = parse_attributes(content)
            scenario.blocks.append(Block(
                kind="eager",
                content=content.strip(),
                start_line=start_line,
                end_line=text[:m.end()].count("\n") + 1,
                attributes=attrs,
            ))
        elif m.group("lazy"):
            content = m.group("lazy_content")
            start_line = text[:m.start()].count("\n") + 1
            scenario.blocks.append(Block(
                kind="lazy",
                content=content.strip(),
                start_line=start_line,
                end_line=text[:m.end()].count("\n") + 1,
            ))

        pos = m.end()

    # Trailing text after last block
    if pos < len(text):
        trailing = text[pos:]
        if trailing.strip():
            scenario.blocks.append(Block(
                kind="text",
                content=trailing,
                start_line=text[:pos].count("\n") + 1,
                end_line=scenario.total_lines,
            ))

    # Extract metadata
    scenario.metadata = extract_metadata(scenario)

    # Validate
    if not scenario.blocks:
        scenario.warnings.append("No blocks found (empty file?)")

    return scenario


def extract_metadata(scenario: Scenario) -> dict:
    """Extract metadata from parsed scenario."""
    all_code = "\n".join(b.content for b in scenario.blocks if b.kind in ("eager", "lazy"))

    api_calls = {}
    for m in API_CALL_RE.finditer(all_code):
        api_name = m.group(1)
        api_calls[api_name] = api_calls.get(api_name, 0) + 1

    # Find labels, jumps, branches, endings
    labels = re.findall(r'label\(["\'](\w+)["\']', all_code)
    jumps = re.findall(r'jump_to\(["\'](\w+)["\']', all_code)
    branches = re.findall(r'branch\s*\(.*?["\'](\w+)["\']', all_code)
    endings = re.findall(r'ending\(["\']?(\w+)["\']?\)', all_code)
    starts = re.findall(r'is_start\(\)', all_code)
    ends = re.findall(r'is_end\(\)', all_code)

    # Extract dialogue stats
    speakers: dict[str, int] = {}
    total_chars = 0
    for b in scenario.blocks:
        if b.kind == "text":
            for line in b.content.split("\n"):
                # Pattern: 角色名：：dialogue
                m = re.match(r'^(.+?)[：:][：:]\s*(.*)', line)
                if m:
                    speaker = m.group(1).strip()
                    dialogue = m.group(2).strip()
                    speakers[speaker] = speakers.get(speaker, 0) + 1
                    total_chars += len(dialogue)
                else:
                    # Narration
                    speakers["__narration__"] = speakers.get("__narration__", 0) + 1

    return {
        "api_calls": api_calls,
        "labels": labels,
        "jumps": jumps,
        "branches": branches,
        "endings": endings,
        "has_start": len(starts) > 0,
        "has_end": len(ends) > 0,
        "ends": len(ends),
        "speakers": {k: v for k, v in speakers.items() if k != "__narration__"},
        "narration_lines": speakers.get("__narration__", 0),
        "total_dialogue_chars": total_chars,
    }


# ── Analysis ────────────────────────────────────────────────────────

def analyze_scenario(scenario: Scenario) -> dict:
    """Generate a human-readable analysis of a scenario."""
    return {
        "filename": scenario.filename,
        "total_lines": scenario.total_lines,
        "blocks": {
            "total": len(scenario.blocks),
            "eager": scenario.eager_count,
            "lazy": scenario.lazy_count,
            "text": scenario.text_count,
        },
        "stats": {
            "labels": scenario.metadata.get("labels", []),
            "jumps": scenario.metadata.get("jumps", []),
            "branches": scenario.metadata.get("branches", []),
            "endings": scenario.metadata.get("endings", []),
            "total_dialogue_chars": scenario.metadata.get("total_dialogue_chars", 0),
            "narration_lines": scenario.metadata.get("narration_lines", 0),
        },
        "api_calls": scenario.metadata.get("api_calls", {}),
        "warnings": scenario.warnings,
    }


# ── CLI ─────────────────────────────────────────────────────────────

def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Parse and analyze NovaScript .txt scenario files.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "csv"), default="text", help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--scenario", metavar="FILE", help="single scenario file to parse")
    p.add_argument("--validate", action="store_true", help="validate block structure")
    p.add_argument("--all", action="store_true", help="parse all scenarios and show summary")
    return p


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    if args.scenario:
        sc_path = project_root / "resources" / "scenarios" / args.scenario
        if not sc_path.is_file():
            print(f"Scenario not found: {sc_path}", file=sys.stderr)
            sys.exit(2)
        scenarios = [parse_scenario(sc_path.read_text(encoding="utf-8"), sc_path.name)]
    else:
        scenarios = []
        for sf in iter_scenario_files(project_root):
            scenarios.append(parse_scenario(sf.read_text(encoding="utf-8"), sf.name))

    analyses = [analyze_scenario(sc) for sc in scenarios]

    if args.format == "json":
        write_output(args.output, format_json({
            "scenarios": analyses,
            "total_scenarios": len(scenarios),
            "total_blocks": sum(len(sc.blocks) for sc in scenarios),
            "total_dialogue_chars": sum(a["stats"]["total_dialogue_chars"] for a in analyses),
        }))
    elif args.format == "csv":
        lines = ["filename,total_lines,eager_blocks,lazy_blocks,text_blocks,labels,jumps,branches,endings,dialogue_chars"]
        for a in analyses:
            lines.append(
                f'{a["filename"]},{a["total_lines"]},'
                f'{a["blocks"]["eager"]},{a["blocks"]["lazy"]},{a["blocks"]["text"]},'
                f'{len(a["stats"]["labels"])},{len(a["stats"]["jumps"])},'
                f'{len(a["stats"]["branches"])},{len(a["stats"]["endings"])},'
                f'{a["stats"]["total_dialogue_chars"]}'
            )
        write_output(args.output, "\n".join(lines) + "\n")
    else:
        lines: list[str] = []
        lines.append("=== NovaScript Parser ===")
        lines.append(f"Scenarios: {len(scenarios)}")
        lines.append(f"Total blocks: {sum(len(sc.blocks) for sc in scenarios)}")
        lines.append("")

        for a in analyses:
            lines.append(f"[{a['filename']}]")
            lines.append(f"  Lines: {a['total_lines']}  |  Blocks: {a['blocks']['total']} (E:{a['blocks']['eager']} L:{a['blocks']['lazy']} T:{a['blocks']['text']})")
            if a["stats"]["labels"]:
                lines.append(f"  Labels: {', '.join(a['stats']['labels'])}")
            if a["stats"]["branches"]:
                lines.append(f"  Branches: {', '.join(a['stats']['branches'])}")
            if a["stats"]["endings"]:
                lines.append(f"  Endings: {', '.join(a['stats']['endings'])}")
            if a["stats"]["total_dialogue_chars"]:
                lines.append(f"  Dialogue chars: {a['stats']['total_dialogue_chars']}")
            if a["warnings"]:
                for w in a["warnings"]:
                    lines.append(f"  ⚠ {w}")
            lines.append("")

        write_output(args.output, "\n".join(lines))


if __name__ == "__main__":
    main()

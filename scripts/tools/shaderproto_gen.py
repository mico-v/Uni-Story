#!/usr/bin/env python3
"""Shaderproto generator: produce .gdshader variants from template files.

Inspired by Nova's shaderproto system which generates Unity shaders from
parametric templates. This Godot/GDScript version reads a `.shaderproto`
definition and emits one or more `.gdshader` files with substituted constants.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional, Sequence


SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]

SHADER_OUTPUT_DIR = "resources/shaders"


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


@dataclass
class ShaderProto:
    """Parsed representation of a .shaderproto file."""

    name: str
    source_path: str
    base_template: str = ""
    variants: list[dict[str, str]] = field(default_factory=list)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate .gdshader files from .shaderproto templates.",
    )
    parser.add_argument(
        "protos",
        nargs="*",
        metavar="FILE",
        help=".shaderproto files to process (default: all under resources/shaders/)",
    )
    parser.add_argument(
        "--project",
        metavar="PATH",
        help="Godot project root (defaults to repository root)",
    )
    parser.add_argument(
        "--output-dir",
        metavar="PATH",
        help=f"Output directory for generated shaders (default: {SHADER_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be generated without writing files",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available .shaderproto files",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="output format for --list / --dry-run (default: text)",
    )
    return parser


def resolve_project_root(explicit: str | None) -> Path:
    if explicit:
        p = Path(explicit).resolve()
        if not p.is_dir():
            raise CliError(f"project root not found: {p}")
        return p
    return PROJECT_ROOT


def find_protos(project_root: Path) -> list[Path]:
    shader_dir = project_root / SHADER_OUTPUT_DIR
    if not shader_dir.is_dir():
        return []
    return sorted(shader_dir.glob("*.shaderproto"))


def parse_shaderproto(filepath: Path) -> ShaderProto:
    """Parse a .shaderproto file.

    Format is JSON with these fields:
    {
        "name": "effect_name",
        "template": "inline shader template text or path to .gdshader base",
        "variants": [
            {"suffix": "_post", "constants": {"KEY": "VALUE", ...}, "replacements": {"TEXT": "REPLACE", ...}},
            ...
        ]
    }
    """
    try:
        text = filepath.read_text(encoding="utf-8")
    except Exception as e:
        raise CliError(f"cannot read {filepath}: {e}") from e

    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise CliError(f"invalid JSON in {filepath}: {e}") from e

    name = data.get("name", filepath.stem)
    base = data.get("template", "")

    # If template is a path (not inline shader code), resolve and read inline
    if base and not base.strip().startswith("shader_type"):
        template_path: Path | None = None
        # Handle "res://" paths relative to project root
        if base.startswith("res://"):
            rel = base[len("res://"):]
            # Find project root by walking up from the proto file
            p = filepath.parent
            while p != p.parent:
                if (p / "project.godot").is_file():
                    template_path = p / rel
                    break
                p = p.parent
            if template_path is None:
                template_path = filepath.parent.parent.parent / rel
        else:
            template_path = filepath.parent / base
        if template_path is not None and template_path.suffix != ".gdshader":
            template_path = template_path.with_suffix(".gdshader")
        if template_path is not None and template_path.is_file():
            base = template_path.read_text(encoding="utf-8")
        elif not base.strip():
            base = ""

    variants: list[dict[str, str]] = []
    for v in data.get("variants", []):
        if not isinstance(v, dict):
            continue
        variant_suffix = v.get("suffix", "")
        variant_data: dict[str, str] = {"suffix": variant_suffix}

        constants = v.get("constants", {})
        if isinstance(constants, dict):
            for k, val in constants.items():
                variant_data[f"const:{k}"] = str(val)

        replacements = v.get("replacements", {})
        if isinstance(replacements, dict):
            for k, val in replacements.items():
                variant_data[f"replace:{k}"] = str(val)

        variants.append(variant_data)

    return ShaderProto(
        name=name,
        source_path=str(filepath),
        base_template=base,
        variants=variants,
    )


def apply_variant(full_template: str, variant: dict[str, str]) -> str:
    """Apply replacement rules to the template."""
    result = full_template

    # Apply string replacements first
    for key, value in variant.items():
        if key.startswith("replace:"):
            token = key[len("replace:"):]
            result = result.replace(token, value)

    # Then inject constants as uniforms
    const_lines: list[str] = []
    for key, value in variant.items():
        if key.startswith("const:"):
            const_name = key[len("const:"):]
            const_lines.append(f"const float {const_name} = {value};")

    if const_lines:
        # Insert constants before the fragment function
        marker = "void fragment()"
        if marker in result:
            const_block = "\n".join(const_lines) + "\n\n"
            result = result.replace(marker, const_block + marker)
        else:
            # Fallback: insert after shader_type line
            lines = result.split("\n")
            for i, line in enumerate(lines):
                if line.startswith("shader_type"):
                    lines.insert(i + 1, "")
                    lines.insert(i + 2, "\n".join(const_lines))
                    lines.insert(i + 3, "")
                    break
            result = "\n".join(lines)

    return result


def generate_shaders(
    project_root: Path,
    protos: list[Path],
    output_dir: str,
    dry_run: bool = False,
) -> dict[str, list[dict]]:
    """Process .shaderproto files and generate .gdshader output.

    Returns a report keyed by proto name with per-variant details.
    """
    report: dict[str, list[dict]] = {}
    out_path = project_root / output_dir

    for proto_path in protos:
        try:
            proto = parse_shaderproto(proto_path)
        except CliError as e:
            print(str(e), file=sys.stderr)
            continue

        if not proto.base_template:
            print(f"Warning: {proto_path} has empty template, skipping", file=sys.stderr)
            continue

        variants_report: list[dict] = []

        for variant in proto.variants:
            suffix = variant.get("suffix", "")
            output_name = f"{proto.name}{suffix}.gdshader"
            output_path = out_path / output_name

            generated = apply_variant(proto.base_template, variant)
            info = {
                "name": output_name,
                "path": str(output_path.relative_to(project_root)),
                "written": False,
            }

            if not dry_run:
                out_path.mkdir(parents=True, exist_ok=True)
                output_path.write_text(generated, encoding="utf-8")
                info["written"] = True

            variants_report.append(info)

        report[proto.name] = variants_report

    return report


def format_report(report: dict, fmt: str) -> str:
    if fmt == "json":
        return json.dumps(report, indent=2, ensure_ascii=False)

    lines: list[str] = []
    for proto_name, variants in report.items():
        lines.append(f"shaderproto: {proto_name} ({len(variants)} variant(s))")
        for v in variants:
            status = "WRITE" if v["written"] else "DRY-RUN"
            lines.append(f"  [{status}] {v['name']}")
            lines.append(f"          → {v['path']}")
        lines.append("")
    return "\n".join(lines)


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    shader_dir = project_root / SHADER_OUTPUT_DIR
    if not shader_dir.is_dir():
        print(f"Shader directory not found: {shader_dir}", file=sys.stderr)
        sys.exit(2)

    if args.list:
        protos = find_protos(project_root)
        if args.format == "json":
            print(json.dumps([str(p.relative_to(project_root)) for p in protos], indent=2))
        else:
            if protos:
                for p in protos:
                    print(str(p.relative_to(project_root)))
            else:
                print("(no .shaderproto files found)")
            print(f"\n{len(protos)} proto file(s) total")
        return

    if args.protos:
        protos = [Path(p).resolve() for p in args.protos]
        missing = [p for p in protos if not p.is_file()]
        if missing:
            for m in missing:
                print(f"proto file not found: {m}", file=sys.stderr)
            sys.exit(2)
    else:
        protos = find_protos(project_root)
        if not protos:
            print("No .shaderproto files found. Use --list to verify.", file=sys.stderr)
            sys.exit(0)

    output_dir = args.output_dir or SHADER_OUTPUT_DIR
    report = generate_shaders(project_root, protos, output_dir, dry_run=args.dry_run)

    rendered = format_report(report, args.format)
    print(rendered)

    if not args.dry_run:
        total = sum(len(v) for v in report.values())
        print(f"Generated {total} shader(s) from {len(report)} proto(s).")


if __name__ == "__main__":
    main()

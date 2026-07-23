#!/usr/bin/env python3
"""Public cross-platform CLI for Nova scenario flow visualization."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Iterable, List, Optional, Sequence


SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]
GODOT_SCRIPT = "res://scripts/tools/scenario_visualize.gd"
GODOT_TIMEOUT_SECONDS = 300


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


def _non_negative_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a non-negative integer") from exc
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be a non-negative integer")
    return parsed


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Visualize Nova scenario flow without executing eager code. "
            "The Godot bridge emits text, JSON, Graphviz DOT, or Mermaid output."
        ),
    )
    parser.add_argument(
        "--godot",
        metavar="PATH",
        help="Godot executable (otherwise GODOT_BIN, godot, then godot4 is used)",
    )
    parser.add_argument(
        "--project",
        metavar="PATH",
        help="Godot project directory (defaults to the repository containing this script)",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json", "dot", "mermaid"),
        default="text",
        help="output format (default: text)",
    )
    parser.add_argument(
        "--output",
        metavar="PATH",
        default="-",
        help="write the output to PATH, or '-' for stdout (default: -)",
    )
    parser.add_argument("--view", choices=("flow", "branches"))
    parser.add_argument(
        "--root-policy",
        choices=("auto", "start", "unlocked", "debug", "sources", "all"),
    )
    parser.add_argument(
        "--root",
        action="append",
        default=[],
        metavar="NODE",
        help="add an explicit root node (repeatable)",
    )
    parser.add_argument(
        "--reachable-only",
        action="store_true",
        help="emit only nodes reachable from the selected roots",
    )
    parser.add_argument(
        "--exclude-debug",
        action="store_true",
        help="exclude debug nodes from the graph",
    )
    parser.add_argument(
        "--node",
        action="append",
        default=[],
        metavar="GLOB",
        help="include nodes matching GLOB (repeatable)",
    )
    parser.add_argument(
        "--edge-kind",
        action="append",
        choices=("jump_to", "jump_if", "branch"),
        default=[],
        help="include an edge kind (repeatable)",
    )
    parser.add_argument(
        "--phase",
        action="append",
        choices=("eager", "lazy"),
        default=[],
        help="include a source phase (repeatable)",
    )
    parser.add_argument("--boundary", choices=("include", "drop"))
    parser.add_argument(
        "--context",
        action="append",
        default=[],
        metavar="PATH",
        help="add a context scenario file or directory (repeatable)",
    )
    parser.add_argument(
        "--no-context",
        action="store_true",
        help="disable automatically supplied graph context",
    )
    parser.add_argument("--cluster", choices=("none", "file"))
    parser.add_argument("--label", choices=("id", "display", "both"))
    parser.add_argument(
        "--max-label-chars",
        type=_non_negative_int,
        metavar="N",
        help="truncate rendered labels to at most N characters",
    )
    parser.add_argument(
        "paths",
        metavar="FILE_OR_DIR",
        nargs="*",
        help="scenario files or directories (default: resources/scenarios in the project)",
    )
    return parser


def _expanded_path(value: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(value)))


def _resolve_project(value: Optional[str]) -> Path:
    project = _expanded_path(value) if value else PROJECT_ROOT
    if project.name.lower() == "project.godot" and project.is_file():
        project = project.parent
    if not project.is_absolute():
        project = Path.cwd() / project
    project = project.resolve()
    if not project.is_dir():
        raise CliError("project directory does not exist: %s" % project)
    if not (project / "project.godot").is_file():
        raise CliError("project.godot was not found in: %s" % project)
    if not (project / "scripts" / "tools" / "scenario_visualize.gd").is_file():
        raise CliError("scenario visualization bridge was not found in project: %s" % project)
    return project


def _find_executable(value: str) -> Optional[str]:
    expanded = os.path.expandvars(os.path.expanduser(value.strip()))
    if not expanded:
        return None
    found = shutil.which(expanded)
    if found:
        return str(Path(found).resolve())
    candidate = Path(expanded)
    if not candidate.is_absolute():
        candidate = Path.cwd() / candidate
    if candidate.is_file():
        return str(candidate.resolve())
    return None


def _resolve_godot(explicit: Optional[str]) -> str:
    if explicit is not None:
        found = _find_executable(explicit)
        if not found:
            raise CliError("Godot executable from --godot was not found: %s" % explicit)
        return found
    environment = os.environ.get("GODOT_BIN")
    if environment:
        found = _find_executable(environment)
        if not found:
            raise CliError("Godot executable from GODOT_BIN was not found: %s" % environment)
        return found
    for command in ("godot", "godot4"):
        found = _find_executable(command)
        if found:
            return found
    raise CliError(
        "Godot was not found; pass --godot PATH or set GODOT_BIN "
        "(searched commands: godot, godot4)"
    )


def _resolve_paths(
    values: Sequence[str],
    project: Path,
    kind: str,
) -> List[str]:
    resolved: List[str] = []
    for value in values:
        if not value.strip():
            raise CliError("%s path cannot be empty" % kind)
        if value.startswith(("res://", "user://")):
            resolved.append(value)
            continue
        path = _expanded_path(value)
        if not path.is_absolute():
            cwd_path = Path.cwd() / path
            project_path = project / path
            path = cwd_path if cwd_path.exists() or not project_path.exists() else project_path
        path = path.resolve()
        try:
            relative = path.relative_to(project)
        except ValueError:
            resolved.append(str(path))
        else:
            resolved.append("res://" + relative.as_posix())
    return resolved


def _scenario_paths(values: Sequence[str], project: Path) -> List[str]:
    if not values:
        return ["res://resources/scenarios"]
    return _resolve_paths(values, project, "scenario")


def _append_values(command: List[str], option: str, values: Iterable[str]) -> None:
    for value in values:
        command.extend((option, value))


def _graph_arguments(args: argparse.Namespace, context_paths: Sequence[str]) -> List[str]:
    command: List[str] = []
    for option, value in (
        ("--view", args.view),
        ("--root-policy", args.root_policy),
        ("--boundary", args.boundary),
        ("--cluster", args.cluster),
        ("--label", args.label),
    ):
        if value is not None:
            command.extend((option, value))
    _append_values(command, "--root", args.root)
    if args.reachable_only:
        command.append("--reachable-only")
    if args.exclude_debug:
        command.append("--exclude-debug")
    _append_values(command, "--node", args.node)
    _append_values(command, "--edge-kind", args.edge_kind)
    _append_values(command, "--phase", args.phase)
    _append_values(command, "--context", context_paths)
    if args.no_context:
        command.append("--no-context")
    if args.max_label_chars is not None:
        command.extend(("--max-label-chars", str(args.max_label_chars)))
    return command


def _validate_output(payload: str, output_format: str) -> None:
    if not payload.strip():
        raise CliError("Godot scenario visualization process produced empty output")
    if output_format == "json":
        try:
            report = json.loads(payload)
        except json.JSONDecodeError as exc:
            raise CliError(
                "Godot scenario visualization process produced invalid JSON: %s" % exc
            ) from exc
        if (
            not isinstance(report, dict)
            or report.get("schema_version") != 1
            or report.get("kind") != "scenario_flow"
        ):
            raise CliError("Godot scenario visualization process produced an invalid report")
        return
    expected_prefix = {
        "text": "ScenarioVisualize:",
        "dot": "digraph",
        "mermaid": "flowchart",
    }[output_format]
    if not payload.startswith(expected_prefix):
        raise CliError(
            "Godot scenario visualization process produced invalid %s output"
            % output_format
        )


def _run_godot(
    godot: str,
    project: Path,
    scenario_paths: Sequence[str],
    context_paths: Sequence[str],
    args: argparse.Namespace,
) -> str:
    suffix = {
        "text": ".txt",
        "json": ".json",
        "dot": ".dot",
        "mermaid": ".mmd",
    }[args.format]
    with tempfile.TemporaryDirectory(prefix="unistory-scenario-visualize-") as temporary:
        report_path = Path(temporary) / ("report" + suffix)
        command = [
            godot,
            "--headless",
            "--quiet",
            "--path",
            str(project),
            "--script",
            GODOT_SCRIPT,
            "--",
            "--format",
            args.format,
            "--output",
            str(report_path),
        ]
        command.extend(_graph_arguments(args, context_paths))
        command.extend(scenario_paths)
        try:
            completed = subprocess.run(
                command,
                cwd=str(project),
                stdout=sys.stderr,
                stderr=subprocess.STDOUT,
                check=False,
                timeout=GODOT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            raise CliError(
                "Godot scenario visualization process timed out after %d seconds"
                % GODOT_TIMEOUT_SECONDS
            ) from exc
        except OSError as exc:
            raise CliError("could not start Godot: %s" % exc) from exc
        if completed.returncode != 0:
            raise CliError(
                "Godot scenario visualization process exited with code %d"
                % completed.returncode
            )
        if not report_path.is_file():
            raise CliError("Godot scenario visualization process did not produce output")
        try:
            payload = report_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            raise CliError("could not read the Godot visualization output: %s" % exc) from exc
    _validate_output(payload, args.format)
    return payload


def _write_bytes(stream: Any, payload: bytes) -> None:
    buffer = getattr(stream, "buffer", None)
    if buffer is not None:
        buffer.write(payload)
        buffer.flush()
        return
    stream.write(payload.decode("utf-8", errors="replace"))
    stream.flush()


def _write_output(payload: str, destination: str) -> None:
    encoded = payload.encode("utf-8")
    if destination == "-":
        _write_bytes(sys.stdout, encoded)
        return
    path = _expanded_path(destination)
    if not path.is_absolute():
        path = Path.cwd() / path
    try:
        path.write_bytes(encoded)
    except OSError as exc:
        raise CliError("could not write output to %s: %s" % (path, exc)) from exc


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    try:
        project = _resolve_project(args.project)
        godot = _resolve_godot(args.godot)
        scenario_paths = _scenario_paths(args.paths, project)
        context_paths = _resolve_paths(args.context, project, "context")
        payload = _run_godot(godot, project, scenario_paths, context_paths, args)
        _write_output(payload, args.output)
        return 0
    except CliError as exc:
        print("scenario-visualize: error: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

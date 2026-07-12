#!/usr/bin/env python3
"""Public cross-platform CLI for Nova scenario dialogue statistics."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Dict, Iterable, Optional, Sequence


SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]
GODOT_SCRIPT = "res://scripts/tools/scenario_stat.gd"
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
            "Inventory dialogue lengths in Nova scenario source files. "
            "This is a source inventory, not a single-playthrough estimate."
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
        choices=("text", "json"),
        default="text",
        help="report format (default: text)",
    )
    parser.add_argument(
        "--output",
        metavar="PATH",
        default="-",
        help="write the report to PATH, or '-' for stdout (default: -)",
    )
    parser.add_argument(
        "--top",
        type=_non_negative_int,
        default=10,
        help="include the N longest dialogue entries (default: 10)",
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
    if not (project / "scripts" / "tools" / "scenario_stat.gd").is_file():
        raise CliError("scenario statistics bridge was not found in project: %s" % project)
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


def _scenario_paths(values: Sequence[str], project: Path) -> Iterable[str]:
    if not values:
        return ("res://resources/scenarios",)
    resolved = []
    for value in values:
        if not value.strip():
            raise CliError("scenario path cannot be empty")
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


def _run_godot(
    godot: str,
    project: Path,
    scenario_paths: Iterable[str],
    top: int,
) -> Dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="unistory-scenario-stat-") as temporary:
        report_path = Path(temporary) / "report.json"
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
            "json",
            "--output",
            str(report_path),
            "--top",
            str(top),
        ]
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
                "Godot scenario statistics process timed out after %d seconds"
                % GODOT_TIMEOUT_SECONDS
            ) from exc
        except OSError as exc:
            raise CliError("could not start Godot: %s" % exc) from exc
        if completed.returncode != 0:
            raise CliError(
                "Godot scenario statistics process exited with code %d"
                % completed.returncode
            )
        if not report_path.is_file():
            raise CliError("Godot scenario statistics process did not produce a report")
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise CliError("could not read the Godot statistics report: %s" % exc) from exc
    if (
        not isinstance(report, dict)
        or report.get("schema_version") != 1
        or not isinstance(report.get("summary"), dict)
    ):
        raise CliError("Godot scenario statistics process produced an invalid report")
    return report


def _number(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _float(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _format_text(report: Dict[str, Any]) -> str:
    summary = report.get("summary", {})
    lines = [
        "ScenarioStat: files=%d nodes=%d dialogues=%d spoken=%d narration=%d speakers=%d"
        % (
            _number(summary.get("files")),
            _number(summary.get("nodes")),
            _number(summary.get("dialogues")),
            _number(summary.get("spoken")),
            _number(summary.get("narration")),
            _number(summary.get("speakers")),
        ),
        "Flow: blocks=%d eager=%d lazy=%d local=%d normal=%d chapter=%d end=%d jumps=%d branches=%d silent=%d"
        % (
            _number(summary.get("blocks")),
            _number(summary.get("eager_blocks")),
            _number(summary.get("lazy_blocks")),
            _number(summary.get("local_nodes")),
            _number(summary.get("node_types", {}).get("normal")),
            _number(summary.get("node_types", {}).get("chapter")),
            _number(summary.get("node_types", {}).get("end")),
            _number(summary.get("jumps")),
            _number(summary.get("branch_options")),
            _number(summary.get("silent_entries")),
        ),
        "Length: total=%d min=%d mean=%.3f p50=%d p90=%d p95=%d max=%d empty=%d"
        % (
            _number(summary.get("total_characters")),
            _number(summary.get("min")),
            _float(summary.get("mean")),
            _number(summary.get("p50")),
            _number(summary.get("p90")),
            _number(summary.get("p95")),
            _number(summary.get("max")),
            _number(summary.get("empty")),
        ),
    ]
    speakers = report.get("by_speaker", [])
    if isinstance(speakers, list) and speakers:
        lines.append("Speakers:")
        for speaker in speakers:
            if not isinstance(speaker, dict):
                continue
            lines.append(
                "  %s: dialogues=%d characters=%d mean=%.3f"
                % (
                    speaker.get("canonical_speaker", ""),
                    _number(speaker.get("dialogues")),
                    _number(speaker.get("characters")),
                    _float(speaker.get("mean")),
                )
            )
    longest = report.get("longest", [])
    if isinstance(longest, list) and longest:
        lines.append("Longest:")
        for entry in longest:
            if not isinstance(entry, dict):
                continue
            speaker = str(entry.get("display_speaker", ""))
            prefix = "%s: " % speaker if speaker else ""
            lines.append(
                "  %s:%d [%d] %s%s"
                % (
                    entry.get("path", ""),
                    _number(entry.get("line")),
                    _number(entry.get("length")),
                    prefix,
                    entry.get("normalized_text", ""),
                )
            )
    return "\n".join(lines) + "\n"


def _render_report(report: Dict[str, Any], output_format: str) -> str:
    if output_format == "json":
        return json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    return _format_text(report)


def _write_bytes(stream: Any, payload: bytes) -> None:
    buffer = getattr(stream, "buffer", None)
    if buffer is not None:
        buffer.write(payload)
        buffer.flush()
        return
    stream.write(payload.decode("utf-8", errors="replace"))
    stream.flush()


def _write_report(payload: str, destination: str) -> None:
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
        raise CliError("could not write report to %s: %s" % (path, exc)) from exc


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    try:
        project = _resolve_project(args.project)
        godot = _resolve_godot(args.godot)
        report = _run_godot(
            godot,
            project,
            _scenario_paths(args.paths, project),
            args.top,
        )
        _write_report(_render_report(report, args.format), args.output)
        return 0
    except CliError as exc:
        print("scenario-stat: error: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

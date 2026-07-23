#!/usr/bin/env python3
"""Cross-platform command-line entry point for the Nova scenario linter."""

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
GODOT_SCRIPT = "res://scripts/tools/scenario_lint.gd"
GODOT_TIMEOUT_SECONDS = 300


class CliError(Exception):
    """An invocation or infrastructure error that should return exit code 2."""


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Lint Nova scenario files with the project's Godot-based checks.",
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
        "--fail-on",
        choices=("error", "warning", "never"),
        default="error",
        help="minimum diagnostic severity that returns exit 1 (default: error)",
    )
    parser.add_argument(
        "--no-compile",
        action="store_true",
        help="skip translated GDScript compilation",
    )
    parser.add_argument(
        "--no-resources",
        action="store_true",
        help="skip resource existence checks",
    )
    parser.add_argument(
        "--no-no-op",
        action="store_true",
        help="skip compatibility no-op warnings",
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
    if not (project / "scripts" / "tools" / "scenario_lint.gd").is_file():
        raise CliError("scenario lint bridge was not found in project: %s" % project)
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
            working_directory_path = Path.cwd() / path
            project_path = project / path
            # Relative inputs normally follow the caller's working directory.
            # Falling back to the project keeps common project-relative paths
            # usable when the public script is launched from elsewhere.
            path = (
                working_directory_path
                if working_directory_path.exists() or not project_path.exists()
                else project_path
            )
        path = path.resolve()
        try:
            relative = path.relative_to(project)
        except ValueError:
            resolved.append(str(path))
        else:
            resolved.append("res://" + relative.as_posix())
    return resolved


def _write_bytes(stream: Any, payload: bytes) -> None:
    if not payload:
        return
    buffer = getattr(stream, "buffer", None)
    if buffer is not None:
        buffer.write(payload)
        buffer.flush()
        return
    stream.write(payload.decode("utf-8", errors="replace"))
    stream.flush()


def _run_godot(
    godot: str,
    project: Path,
    scenario_paths: Iterable[str],
    args: argparse.Namespace,
) -> Dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="unistory-scenario-lint-") as temporary:
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
            "--fail-on",
            "never",
        ]
        if args.no_compile:
            command.append("--no-compile")
        if args.no_resources:
            command.append("--no-resources")
        if args.no_no_op:
            command.append("--no-no-op")
        command.extend(scenario_paths)

        try:
            completed = subprocess.run(
                command,
                cwd=str(project),
                # Keep the report on its dedicated file and route any engine
                # output to stderr. Avoiding a PIPE also prevents inherited
                # Windows handles from delaying process completion.
                stdout=sys.stderr,
                stderr=subprocess.STDOUT,
                check=False,
                timeout=GODOT_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            raise CliError(
                "Godot scenario lint process timed out after %d seconds"
                % GODOT_TIMEOUT_SECONDS
            ) from exc
        except OSError as exc:
            raise CliError("could not start Godot: %s" % exc) from exc

        if completed.returncode != 0:
            raise CliError("Godot scenario lint process exited with code %d" % completed.returncode)
        if not report_path.is_file():
            raise CliError("Godot scenario lint process did not produce a report")
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise CliError("could not read the Godot lint report: %s" % exc) from exc

    _validate_report(report)
    return report


def _validate_report(report: Any) -> None:
    if not isinstance(report, dict) or report.get("schema_version") != 1:
        raise CliError("Godot scenario lint process produced an unsupported report schema")
    summary = report.get("summary")
    issues = report.get("issues")
    files = report.get("files")
    if not isinstance(summary, dict) or not isinstance(issues, list) or not isinstance(files, list):
        raise CliError("Godot scenario lint process produced an invalid report shape")

    counted = {"errors": 0, "warnings": 0}
    for issue in issues:
        if not isinstance(issue, dict):
            raise CliError("Godot scenario lint report contains a non-object diagnostic")
        severity = issue.get("severity")
        if severity not in ("error", "warning"):
            raise CliError("Godot scenario lint report contains an invalid severity")
        if not all(isinstance(issue.get(key), str) for key in ("path", "code", "message")):
            raise CliError("Godot scenario lint report contains an invalid diagnostic field")
        for key in ("line", "column"):
            value = issue.get(key)
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                raise CliError("Godot scenario lint report contains an invalid diagnostic location")
        counted["errors" if severity == "error" else "warnings"] += 1

    for key in ("errors", "warnings"):
        value = summary.get(key)
        if isinstance(value, bool) or not isinstance(value, int) or value != counted[key]:
            raise CliError("Godot scenario lint summary does not match its diagnostics")


def _number(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _format_text(report: Dict[str, Any]) -> str:
    lines = []
    issues = report.get("issues", [])
    if isinstance(issues, list):
        for issue in issues:
            if not isinstance(issue, dict):
                continue
            lines.append(
                "%s:%d:%d: %s [%s] %s"
                % (
                    issue.get("path", ""),
                    _number(issue.get("line")),
                    _number(issue.get("column", 1)),
                    issue.get("severity", "warning"),
                    issue.get("code", "lint"),
                    issue.get("message", ""),
                )
            )

    summary = report.get("summary", {})
    lines.append(
        "ScenarioLint: files=%d blocks=%d dialogues=%d labels=%d "
        "errors=%d warnings=%d resources=%d/%d virtual=%d missing=%d"
        % (
            _number(summary.get("files")),
            _number(summary.get("blocks")),
            _number(summary.get("dialogues")),
            _number(summary.get("labels")),
            _number(summary.get("errors")),
            _number(summary.get("warnings")),
            _number(summary.get("resource_found")),
            _number(summary.get("resource_references")),
            _number(summary.get("resource_virtual")),
            _number(summary.get("resource_missing")),
        )
    )
    return "\n".join(lines) + "\n"


def _render_report(report: Dict[str, Any], output_format: str) -> str:
    if output_format == "json":
        return json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    return _format_text(report)


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


def _exit_for_report(report: Dict[str, Any], fail_on: str) -> int:
    if fail_on == "never":
        return 0
    summary = report.get("summary", {})
    errors = _number(summary.get("errors"))
    warnings = _number(summary.get("warnings"))
    if fail_on == "warning":
        return 1 if errors > 0 or warnings > 0 else 0
    return 1 if errors > 0 else 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    try:
        project = _resolve_project(args.project)
        godot = _resolve_godot(args.godot)
        report = _run_godot(godot, project, _scenario_paths(args.paths, project), args)
        _write_report(_render_report(report, args.format), args.output)
        return _exit_for_report(report, args.fail_on)
    except CliError as exc:
        print("scenario-lint: error: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())

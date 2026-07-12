#!/usr/bin/env python3
"""Run every Godot headless smoke test and report one aggregate result."""

from __future__ import annotations

import argparse
import fnmatch
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


DEFAULT_TIMEOUT_SECONDS = 180.0
SCRIPT_ERROR_MARKERS = ("SCRIPT ERROR:", "Parse Error:", "GDScript backtrace")


@dataclass(frozen=True)
class TestResult:
    path: Path
    returncode: int
    duration_seconds: float
    output: str
    timed_out: bool = False

    @property
    def script_error(self) -> bool:
        return any(marker in self.output for marker in SCRIPT_ERROR_MARKERS)

    @property
    def passed(self) -> bool:
        return self.returncode == 0 and not self.timed_out and not self.script_error


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run scripts/tests/*_test.gd in isolated Godot processes.",
    )
    parser.add_argument(
        "--godot",
        help="Godot executable path or command name. Defaults to GODOT_BIN, godot, then godot4.",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Godot project root. Defaults to the repository root.",
    )
    parser.add_argument(
        "--pattern",
        action="append",
        default=[],
        help="Glob matched against the test filename or project-relative path. Repeatable.",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Glob for tests to exclude. Repeatable.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="Per-test timeout in seconds.",
    )
    parser.add_argument("--fail-fast", action="store_true", help="Stop after the first failed test.")
    parser.add_argument("--list", action="store_true", help="List selected tests without running them.")
    parser.add_argument("--verbose", action="store_true", help="Print output from passing tests too.")
    return parser.parse_args()


def resolve_godot(explicit: str | None) -> str:
    candidates = [explicit, os.environ.get("GODOT_BIN"), "godot", "godot4"]
    for candidate in candidates:
        if not candidate:
            continue
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
        path = Path(candidate).expanduser()
        if path.is_file():
            return str(path.resolve())
    raise FileNotFoundError(
        "Godot executable not found. Pass --godot or set the GODOT_BIN environment variable."
    )


def matches_any(path: Path, patterns: list[str], project: Path) -> bool:
    if not patterns:
        return True
    relative = path.relative_to(project).as_posix()
    return any(
        fnmatch.fnmatch(path.name, pattern) or fnmatch.fnmatch(relative, pattern)
        for pattern in patterns
    )


def discover_tests(project: Path, patterns: list[str], excludes: list[str]) -> list[Path]:
    tests_dir = project / "scripts" / "tests"
    tests = sorted(tests_dir.glob("*_test.gd"), key=lambda path: path.name.lower())
    return [
        path
        for path in tests
        if matches_any(path, patterns, project)
        and (not excludes or not matches_any(path, excludes, project))
    ]


def run_test(godot: str, project: Path, test_path: Path, timeout: float) -> TestResult:
    relative = test_path.relative_to(project).as_posix()
    command = [
        godot,
        "--headless",
        "--path",
        str(project),
        "--script",
        f"res://{relative}",
    ]
    started = time.monotonic()
    environment = os.environ.copy()
    environment.setdefault("UNISTORY_PYTHON", sys.executable)
    try:
        completed = subprocess.run(
            command,
            cwd=project,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            env=environment,
            timeout=timeout,
            check=False,
        )
        return TestResult(
            path=test_path,
            returncode=completed.returncode,
            duration_seconds=time.monotonic() - started,
            output=completed.stdout,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return TestResult(
            path=test_path,
            returncode=124,
            duration_seconds=time.monotonic() - started,
            output=output,
            timed_out=True,
        )


def print_test_output(output: str) -> None:
    cleaned = output.rstrip()
    if not cleaned:
        return
    encoded = (cleaned + "\n").encode("utf-8", errors="replace")
    buffer = getattr(sys.stdout, "buffer", None)
    if buffer is not None:
        sys.stdout.flush()
        buffer.write(encoded)
        buffer.flush()
    else:
        sys.stdout.write(encoded.decode("utf-8", errors="replace"))
        sys.stdout.flush()


def main() -> int:
    args = parse_args()
    project = args.project.expanduser().resolve()
    if not (project / "project.godot").is_file():
        print(f"error: project.godot not found under {project}", file=sys.stderr)
        return 2

    tests = discover_tests(project, args.pattern, args.exclude)
    if not tests:
        print("error: no headless tests matched", file=sys.stderr)
        return 2

    if args.list:
        for test in tests:
            print(test.relative_to(project).as_posix())
        return 0

    try:
        godot = resolve_godot(args.godot)
    except FileNotFoundError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    print(f"Headless suite: {len(tests)} test(s), Godot={godot}")
    results: list[TestResult] = []
    suite_started = time.monotonic()

    for index, test in enumerate(tests, start=1):
        relative = test.relative_to(project).as_posix()
        print(f"[{index:02d}/{len(tests):02d}] {relative}")
        result = run_test(godot, project, test, args.timeout)
        results.append(result)

        if result.passed:
            print(f"  PASS ({result.duration_seconds:.2f}s)")
            if args.verbose:
                print_test_output(result.output)
        else:
            reasons: list[str] = []
            if result.timed_out:
                reasons.append("timeout")
            if result.returncode != 0:
                reasons.append(f"exit={result.returncode}")
            if result.script_error:
                reasons.append("script error in output")
            print(f"  FAIL ({', '.join(reasons)}) ({result.duration_seconds:.2f}s)")
            print_test_output(result.output)
            if args.fail_fast:
                break

    failed = [result for result in results if not result.passed]
    elapsed = time.monotonic() - suite_started
    print()
    print(
        "Headless suite: "
        f"passed={len(results) - len(failed)}, failed={len(failed)}, "
        f"selected={len(tests)}, elapsed={elapsed:.2f}s"
    )
    if failed:
        print("Failed tests:")
        for result in failed:
            print(f"  - {result.path.relative_to(project).as_posix()}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

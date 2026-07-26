#!/usr/bin/env python3
"""List BGM (background music) assets in the project.

Scans resources/BGM/ and reports all music files with metadata
(format, duration estimation where possible, file size).
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
from pathlib import Path
from typing import Optional

from utils import (
    CliError, PROJECT_ROOT,
    resolve_project_root, write_output, format_json,
)


BGM_DIRS = ["BGM", "music"]
SUPPORTED_EXTENSIONS = (".ogg", ".mp3", ".wav", ".opus", ".flac", ".aac", ".m4a")


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="List BGM (background music) assets and their metadata.",
    )
    p.add_argument("--project", metavar="PATH", help="project root (defaults to repo root)")
    p.add_argument("--format", choices=("text", "json", "csv"), default="text", help="output format (default: text)")
    p.add_argument("--output", metavar="PATH", default="-", help="write to PATH, or '-' for stdout (default: -)")
    p.add_argument("--details", action="store_true", help="include estimated duration and file size")
    p.add_argument("--counts-only", action="store_true", help="only show counts, not individual files")
    return p


def estimate_ogg_duration(filepath: Path) -> float | None:
    """Estimate OGG Vorbis duration from headers."""
    try:
        with open(filepath, "rb") as f:
            # Find the last Ogg page (simplified)
            f.seek(-65536, 2)  # Last 64KB
            data = f.read()
            # OggS page header: "OggS\0" + version + flags + granule pos (8 bytes)
            last_granule = 0
            pos = 0
            while True:
                idx = data.find(b"OggS\x00", pos)
                if idx == -1:
                    break
                granule = struct.unpack_from("<q", data, idx + 6)[0]
                if granule > last_granule:
                    last_granule = granule
                pos = idx + 1
            if last_granule > 0:
                # Typical sample rate for VN BGM: 44100 or 48000
                for sr in [44100, 48000]:
                    duration = last_granule / sr
                    if 1 < duration < 3600:  # 1s to 1hr
                        return duration
            return None
    except Exception:
        return None


def estimate_wav_duration(filepath: Path) -> float | None:
    """Estimate WAV duration from header."""
    try:
        with open(filepath, "rb") as f:
            if f.read(4) != b"RIFF":
                return None
            f.read(4)  # file size
            if f.read(4) != b"WAVE":
                return None
            # Find fmt chunk
            while True:
                chunk_id = f.read(4)
                chunk_size = struct.unpack("<I", f.read(4))[0]
                if chunk_id == b"fmt ":
                    fmt_data = f.read(chunk_size)
                    audio_format = struct.unpack_from("<H", fmt_data, 0)[0]
                    channels = struct.unpack_from("<H", fmt_data, 2)[0]
                    sample_rate = struct.unpack_from("<I", fmt_data, 4)[0]
                    byte_rate = struct.unpack_from("<I", fmt_data, 8)[0]
                    if audio_format == 1 and sample_rate > 0:
                        remaining = os.path.getsize(filepath) - f.tell()
                        if byte_rate > 0:
                            return remaining / byte_rate
                    break
                else:
                    f.seek(chunk_size, 1)
            return None
    except Exception:
        return None


def scan_bgm(project_root: Path, details: bool) -> dict:
    """Scan all BGM resources."""
    res_dir = project_root / "resources"
    files = []

    for bgm_dir_name in BGM_DIRS:
        bgm_dir = res_dir / bgm_dir_name
        if not bgm_dir.is_dir():
            continue
        for dirpath, _, filenames in sorted(os.walk(bgm_dir)):
            for fname in sorted(filenames):
                if fname.startswith(".") or fname.endswith(".import"):
                    continue
                fpath = Path(dirpath) / fname
                if fpath.suffix.lower() not in SUPPORTED_EXTENSIONS:
                    continue
                rel = fpath.relative_to(res_dir).as_posix()
                entry: dict = {
                    "name": fpath.stem,
                    "path": rel,
                    "extension": fpath.suffix.lower(),
                    "size": fpath.stat().st_size,
                    "size_mb": round(fpath.stat().st_size / (1024 * 1024), 2),
                }
                if details:
                    if fpath.suffix.lower() == ".ogg":
                        dur = estimate_ogg_duration(fpath)
                    elif fpath.suffix.lower() == ".wav":
                        dur = estimate_wav_duration(fpath)
                    else:
                        dur = None
                    if dur is not None:
                        entry["duration_seconds"] = round(dur, 1)
                        entry["duration_display"] = f"{int(dur//60)}:{int(dur%60):02d}"
                files.append(entry)

    # By source directory
    by_dir: dict[str, list] = {}
    for f in files:
        top_dir = Path(f["path"]).parts[0]
        if top_dir not in by_dir:
            by_dir[top_dir] = []
        by_dir[top_dir].append(f)

    return {
        "total": len(files),
        "by_directory": {k: {"count": len(v), "files": v} for k, v in by_dir.items()},
        "all_files": files,
        "total_size_mb": round(sum(f["size"] for f in files) / (1024 * 1024), 2),
    }


def main() -> None:
    args = _parser().parse_args()
    try:
        project_root = resolve_project_root(args.project)
    except CliError as e:
        print(str(e), file=sys.stderr)
        sys.exit(2)

    data = scan_bgm(project_root, args.details)

    if args.format == "json":
        write_output(args.output, format_json(data))
    elif args.format == "csv":
        lines = ["name,path,extension,size_mb,duration"]
        for f in data["all_files"]:
            dur = f.get("duration_display", "")
            lines.append(f'{f["name"]},{f["path"]},{f["extension"]},{f["size_mb"]},{dur}')
        write_output(args.output, "\n".join(lines) + "\n")
    else:
        lines: list[str] = []
        lines.append("=== BGM (Background Music) Assets ===")
        lines.append(f"Total: {data['total']} files  |  Total size: {data['total_size_mb']} MB")
        lines.append("")
        for dir_name, dir_info in sorted(data["by_directory"].items()):
            lines.append(f"[{dir_name}]  ({dir_info['count']} files)")
            if not args.counts_only:
                for f in dir_info["files"]:
                    dur_info = f"  {f.get('duration_display', '?')}" if args.details else ""
                    lines.append(f"  {f['path']}  ({f['size_mb']} MB){dur_info}")
                lines.append("")
        write_output(args.output, "\n".join(lines))


if __name__ == "__main__":
    main()

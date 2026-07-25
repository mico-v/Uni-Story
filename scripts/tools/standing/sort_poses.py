#!/usr/bin/env python3
"""Sort Pose lists by naming convention for Uni-Story StandingProfile.

Orders poses following these rules:
  1. "normal" always comes first
  2. Basic emotions sorted alphabetically: angry, cry, happy, sad, shock, surprise
  3. Compound/idiomatic expressions: divert, down, side, squint
  4. Variants (e.g. angry2, down2) come after their base

Usage:
  python3 scripts/tools/standing/sort_poses.py --profile resources/standing_profile.tres --in-place
  python3 scripts/tools/standing/sort_poses.py --pose-lua Nova/Assets/Nova/Lua/pose.lua
  python3 scripts/tools/standing/sort_poses.py --poses '{"shock":["body","eye_shock"],"normal":["body","eye_normal"]}' --character gaotian
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# Sort priority for pose names (lower = earlier)
POSE_PRIORITY: dict[str, int] = {
    "normal": 0,
    "smile": 1,
    "happy": 2,
    "angry": 3,
    "angry2": 4,
    "sad": 5,
    "cry": 6,
    "shock": 7,
    "surprise": 8,
    "close": 9,
    "close2": 10,
    "open": 11,
    "open2": 12,
    "divert": 13,
    "down": 14,
    "down2": 15,
    "side": 16,
    "squint": 17,
}


def _pose_sort_key(pose_name: str) -> tuple[int, str]:
    """Sort key: priority first, then alphabetical for unknown names."""
    return (POSE_PRIORITY.get(pose_name, 999), pose_name)


def sort_pose_dict(poses: dict[str, list[str]]) -> dict[str, list[str]]:
    """Sort a poses dictionary by naming convention."""
    sorted_names = sorted(poses.keys(), key=_pose_sort_key)
    return {name: poses[name] for name in sorted_names}


def sort_poses_in_profile(tres_path: Path, character: str = "") -> str:
    """Sort poses within a .tres StandingProfile and return modified content."""
    text = tres_path.read_text(encoding="utf-8")

    def _reorder_poses_block(match: re.Match) -> str:
        block = match.group(1)
        # Parse existing Array[String] entries
        entries = re.findall(
            r'\n(\s*)("[^"]+")\s*:\s*Array\[String\]\(\[([^\]]*)\]\)',
            block,
            re.DOTALL,
        )
        if not entries:
            # Try string format
            str_entries = re.findall(
                r'\n(\s*)("[^"]+")\s*:\s*"([^"]+)"',
                block,
            )
            if not str_entries:
                return match.group(0)

            sorted_entries = sorted(str_entries, key=lambda e: _pose_sort_key(e[1].strip('"')))
            lines = ""
            for indent, pose_name, layers_str in sorted_entries:
                lines += f'\n{indent}{pose_name} = "{layers_str}"'
            return "{" + lines + "\n" + (match.group(0).split("\n")[-1].rstrip() if "\n" in match.group(0) else "")

        sorted_entries = sorted(entries, key=lambda e: _pose_sort_key(e[1].strip('"')))
        lines = ""
        for indent, pose_name, layer_list in sorted_entries:
            lines += f'\n{indent}{pose_name} = Array[String]([{layer_list}])'

        # Keep the closing bracket aligned
        closing = ""
        for line in reversed(block.split("\n")):
            stripped = line.rstrip()
            if stripped.endswith("}"):
                closing = "\n" + stripped[:len(stripped) - len(stripped.lstrip())] + "}"
                break
        return "{" + lines + closing

    if character:
        # Only sort one character's poses
        char_pattern = re.compile(
            rf'("{re.escape(character)}"\s*:\s*\{{.*?)((?:    )"poses"\s*:\s*\{{.*?\n    \}})(.*?\n\s*\}})',
            re.DOTALL,
        )

        def _replace_char_poses(m: re.Match) -> str:
            prefix = m.group(1)
            poses_section = m.group(2)
            suffix = m.group(3)

            # Find the poses block content
            poses_inner_match = re.search(r'"poses"\s*:\s*\{(.*?)\}', poses_section, re.DOTALL)
            if poses_inner_match:
                orig = poses_inner_match.group(0)
                reordered = _reorder_poses_block(
                    re.search(r'\{(.*?)\}', orig, re.DOTALL)  # type: ignore[union-attr]
                )
                if reordered:
                    new_poses = orig.replace(
                        re.search(r'\{(.*?)\}', orig, re.DOTALL).group(0),  # type: ignore[union-attr]
                        reordered,
                    )
                    return prefix + new_poses + suffix
            return m.group(0)

        text = char_pattern.sub(_replace_char_poses, text)

    else:
        # Sort all characters' poses
        char_pattern = re.compile(
            r'("poses"\s*:\s*\{)(.*?)(\n\s*\})',
            re.DOTALL,
        )

        def _replace_all_poses(m: re.Match) -> str:
            prefix = m.group(1)
            inner = m.group(2)
            suffix = m.group(3)
            reordered = _reorder_poses_block(re.search(r'\{(.*?)\}', "{" + inner + "}", re.DOTALL))
            if reordered:
                return prefix + reordered[1:] + suffix  # remove leading { since prefix has it
            return m.group(0)

        text = char_pattern.sub(_replace_all_poses, text)

    return text


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sort Pose definitions by naming convention.",
    )
    parser.add_argument("--profile", "-p", help="Path to standing_profile.tres")
    parser.add_argument("--pose-lua", help="Path to Nova-style pose.lua")
    parser.add_argument("--poses", help='Inline JSON poses: \'{"shock":[...],"normal":[...]}\'')
    parser.add_argument("--character", "-c", default="", help="Filter by character name")
    parser.add_argument("--in-place", "-i", action="store_true", help="Modify profile file in place")
    parser.add_argument("--output", "-o", help="Output file path (for --in-place with backup)")

    args = parser.parse_args()

    if args.poses:
        poses = json.loads(args.poses)
        sorted_poses = sort_pose_dict(poses)
        print(json.dumps(sorted_poses, indent=2, ensure_ascii=False))
        return

    if args.profile:
        profile_path = Path(args.profile).resolve()
        modified = sort_poses_in_profile(profile_path, args.character)

        if args.in_place:
            if args.output:
                Path(args.output).write_text(modified, encoding="utf-8")
                print(f"Sorted poses written to {args.output}")
            else:
                # Backup
                backup = profile_path.with_suffix(profile_path.suffix + ".bak")
                profile_path.rename(backup)
                profile_path.write_text(modified, encoding="utf-8")
                print(f"Sorted poses in {args.profile} (backup: {backup})")
        else:
            print(modified)

    elif args.pose_lua:
        lua_path = Path(args.pose_lua).resolve()
        # For Lua files, just print the sorted order as JSON
        from export_poses import parse_lua_poses
        poses_data = parse_lua_poses(lua_path, args.character)
        if args.character and args.character in poses_data:
            sorted_poses = sort_pose_dict(poses_data[args.character].get("poses", {}))
            poses_data[args.character]["poses"] = sorted_poses
        else:
            for char_name in poses_data:
                poses_data[char_name]["poses"] = sort_pose_dict(poses_data[char_name].get("poses", {}))
        print(json.dumps(poses_data, indent=2, ensure_ascii=False))

    else:
        print("Error: --poses, --profile, or --pose-lua is required.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

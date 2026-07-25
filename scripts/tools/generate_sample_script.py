#!/usr/bin/env python3
"""generate_sample_script.py — generate sample NovaScript scenario files from templates.

Templates: basic, branching, minigame

Each generated script is a valid NovaScript that can be parsed by the engine's
ScriptLoader and pass Scenario lint with zero errors.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional

SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]


class CliError(Exception):
    """An invocation or infrastructure error that returns exit code 2."""


BASIC_TEMPLATE = """@<|
label('sample_basic', '示例章节')
is_start()
is_chapter()
|>
<|
play(bgm, 'prelude')
show(bg, 'classroom')
box_hide_show(2)
|>
旁白：这是最简单的 NovaScript 示例。

舞台设置在放学后的教室里。

<|
show(heroine, 'normal', pos_c)
|>
女主角：："你好，欢迎来到 Uni-Story 的世界。"

女主角：："这是一个视觉小说引擎的示例剧本。"

<|
anim:move(heroine, pos_l, 0.5)
|>
女主角：："我们支持角色移动、图像显示、音乐播放等多种功能。"

女主角：："请享受这段简短的故事吧。"

<|
hide(heroine)
|>
旁白：故事到此结束。

<|
label('sample_basic_end', '结尾')
is_end('normal-ending')
|>
"""

BRANCHING_TEMPLATE = """@<|
label('sample_branch', '分支示例')
is_start()
is_chapter()
|>
<|
play(bgm, 'prelude')
show(bg, 'classroom')
box_hide_show(2)
|>
旁白：这是一个展示 NovaScript 分支功能的示例。

<|
show(heroine, 'normal', pos_c)
|>
女主角：："你好！我想问你一个问题。"

女主角：："你喜欢猫还是喜欢狗？"

@<|
branch {
    { dest = 'l_cat', text = '猫——独立而优雅', mode = 'jump' },
    { dest = 'l_dog', text = '狗——忠诚而热情', mode = 'jump' },
}
|>
@<|
label('l_cat', '猫路线')
|>
女主角：："果然！猫的优雅是无法替代的。"

女主角：："它们独来独往，却在不经意间给你温暖。"

<|
anim:fade_out(bgm, 2)
play(bgm, 'gentle')
|>
女主角：："就像……有些人的温柔一样。"

<|
jump_to('l_ending')
|>
@<|
label('l_dog', '狗路线')
|>
女主角：："狗狗的热情确实让人无法拒绝呢！"

女主角：："它们总是那么直率地表达爱意。"

<|
anim:fade_out(bgm, 2)
play(bgm, 'gentle')
|>
女主角：："也许……坦诚也是需要勇气的。"

<|
jump_to('l_ending')
|>
@<|
label('l_ending', '结局')
|>
女主角：："谢谢你的回答。"

女主角：："无论选择什么，都是你内心的声音。"

<|
label('sample_branch_end', '分支结尾')
is_end('branch-ending')
|>
"""

MINIGAME_TEMPLATE = """@<|
label('sample_minigame', '小游戏示例')
is_start()
is_chapter()
|>
<|
play(bgm, 'playful')
show(bg, 'classroom')
box_hide_show(2)
|>
<|
show(heroine, 'normal', pos_c)
|>
女主角：："我们来玩个游戏吧！"

女主角：："我会问你一个问题，你需要输入答案。"

女主角：："准备好了吗？"

@<|
branch {
    { dest = 'l_minigame_start', text = '准备好了！', mode = 'jump' },
    { dest = 'l_skip', text = '下次再说……', mode = 'jump' },
}
|>
@<|
label('l_minigame_start', '开始小游戏')
|>
女主角：："很好！那么问题是："

女主角：："Uni-Story 的引擎运行时是什么？"

<|
minigame('example_minigame', { 'prompt': 'Uni-Story 的引擎运行时是什么？（提示：三个字）', 'answer': 'Godot' })
|>
<|
show(heroine, 'happy', pos_c)
|>
女主角：："回答正确！Godot 引擎提供了强大的 2D/3D 支持。"

女主角：："Uni-Story 就是基于 Godot 构建的。"

<|
jump_to('l_minigame_end')
|>
@<|
label('l_skip', '跳过小游戏')
|>
女主角：："好的，下次再来玩吧！"

<|
jump_to('l_minigame_end')
|>
@<|
label('l_minigame_end', '小游戏结束')
|>
女主角：："谢谢参与！"

<|
label('sample_minigame_end', '结束')
is_end('minigame-ending')
|>
"""

TEMPLATES = {
    "basic": {
        "source": BASIC_TEMPLATE,
        "description": "A simple linear visual novel script with one character and one scene.",
    },
    "branching": {
        "source": BRANCHING_TEMPLATE,
        "description": "A branching script with player choices leading to different dialogue paths.",
    },
    "minigame": {
        "source": MINIGAME_TEMPLATE,
        "description": "A script integrating the minigame() API for interactive gameplay.",
    },
}


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate sample NovaScript scenario files from built-in templates.",
    )
    parser.add_argument(
        "--template",
        "-t",
        choices=sorted(TEMPLATES.keys()),
        default="basic",
        help="template to generate (default: basic)",
    )
    parser.add_argument(
        "--output",
        "-o",
        metavar="PATH",
        default="-",
        help="write generated script to PATH, or '-' for stdout (default: -)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="list available templates and exit",
    )
    parser.add_argument(
        "--project",
        metavar="PATH",
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


def main() -> None:
    args = _parser().parse_args()

    if args.list:
        print("Available templates:")
        for name, info in sorted(TEMPLATES.items()):
            print(f"  {name:12s} — {info['description']}")
        return

    template_name = args.template
    template = TEMPLATES[template_name]
    source = template["source"]

    if args.output == "-":
        sys.stdout.write(source)
    else:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(source, encoding="utf-8")
        print(f"Generated {template_name} template → {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()

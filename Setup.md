# 快速启动

## 环境要求

- Godot 4.6（标准版即可，无需 .NET）

## 打开项目

1. 启动 Godot 4.6，在项目管理器中导入本仓库根目录。
2. 等待编辑器完成资源扫描。
3. 打开主场景 `res://scene/game.tscn`，按 F5 运行。

## 当前架构概览

项目采用纯 GDScript 实现视觉小说运行时，核心入口是 `NovaController`（挂载在 `game.tscn` 的根节点）。它负责创建所有子系统并将模型信号桥接到视图。

场景树由代码与 `.tscn` 文件混合构建：

```
scene/
  game.tscn              # 主场景，挂载 NovaController
  view/
    title_view.tscn      # 标题界面
    chapter_select_view.tscn  # 章节选择
    game_view.tscn       # 游戏主视图（对话框、立绘、图片等）
  ui/
    dialogue_box.tscn    # 对话框
    dialogue_entry.tscn  # 对话条目
    button_ring.tscn     # 按钮环（选项/分支）
```

## 剧本文件

默认剧本位于 `resources/scenarios/`，使用 NovaScript 格式。`NovaController` 在启动时加载 Nova 原始剧本：

- `ch1.txt` 到 `ch4.txt` — 示例章节
- `tut01.txt` 到 `tut06.txt` — 教程剧本
- `test_*.txt` — Nova 原始功能自检剧本

旧 demo 剧本（如 `main.txt`、`plan_demo.txt`、`test_all.txt`）仍保留在同一目录，可在测试命令中显式传入，或在 `NovaController` 的 `scenario_files` 导出属性中手动切换。

## 本地化

本地化字符串位于 `resources/localized_resources/localized_strings/`（当前支持 `en.json` 和 `zh.json`）。`I18n` 模块在启动时根据系统 locale 自动选择语言并回退到英文。

## 存档

存档保存在 Godot 的 `user://saves/` 目录下，每个槽位一个 JSON 文件，包含模型快照以便重放恢复。


## 更多信息

- 开发计划与路线图：[PLAN.md](PLAN.md)
- 项目概述与 API 参考：[README.md](README.md)
- 对齐复盘记录与 NovaScript 语法：[review.md](review.md)

# 快速启动

## 环境要求

- Godot 4.6（标准版即可，无需 .NET）

## 打开项目

1. 启动 Godot 4.6，在项目管理器中导入本仓库根目录。
2. 等待编辑器完成资源扫描。
3. 打开主场景 `res://scene/game.tscn`，按 F5 运行。

## 当前架构概览

项目采用纯 GDScript 实现视觉小说运行时，核心入口是 `NovaController`（挂载在 `game.tscn` 的根节点）。它负责创建所有子系统并将模型信号桥接到视图。

已实现的子系统（28 个）：

| 子系统 | 职责 |
|--------|------|
| `NovaController` | Composition Root，装配所有子系统 |
| `GameState` | 对话推进、分支选择、结局判断 |
| `FlowChartGraph` | 节点/分支/跳转流程图 |
| `ScriptLoader` | NovaScript 解析与 GDScript 编译 |
| `GDRuntime` | 运行时脚本执行 |
| `CheckpointManager` | Node record / reached data / position checkpoint |
| `SaveSystem` | Bookmark slot 管理 + 缩略图 + 元数据 |
| `Variables` | 局部/全局/临时变量（v_/gv_ 兼容） |
| `I18n` | 多语言 UI 字符串（zh/en） |
| `Backlog` | 对话历史（支持语音路径记录） |
| `ReadTracker` | 已读对话追踪（Skip unread 依赖） |
| `Graphics` | 图片显示/隐藏/移动/染色 |
| `SpriteComposer` | StandingProfile 驱动立绘合成 |
| `AvatarSystem` | 对话框头像管理 |
| `AnimationSystem` | 动画域（per_dialogue/holding/ui/text）+ pause/resume/easing |
| `AudioSystem` | BGM 交叉淡入淡出 / SE 池化 / Voice 播放 |
| `CameraSystem` | 逻辑相机移动/缩放/旋转 |
| `TransitionSystem` | 屏幕转场（fade/flash/shader transition） |
| `DialogueBoxSystem` | 对话框位置/样式管理 |
| `VFXSystem` | 对象/后处理/转场 VFX + 屏幕震动 + shader 注册表 |
| `PrefabLoader` | 运行时 .tscn 加载与管理 |
| `VideoSystem` | 视频播放 |
| `PreloadSystem` | 资源预加载缓存（LRU） |
| `HotReload` | 开发期剧本热重载 |
| `ShortcutManager` | 可自定义快捷键 + 冲突检测 |
| `ViewManager` | 视图注册/切换/过渡动画 + 状态管理 |
| `InterruptManager` | 小游戏中断/恢复协议 |
| `DialogSystem` | Toast 通知 + Confirm 确认框 |
| `EngineContext` | Typed facade（逐步替代弱类型 _ctx） |

场景树由代码与 `.tscn` 文件混合构建：

```
scene/
  game.tscn                    # 主场景，挂载 NovaController + GlobalUI
  view/
    title_view.tscn            # 标题界面
    chapter_select_view.tscn   # 章节选择
    game_view.tscn             # 游戏主视图（对话框、立绘、图片等）
    settings_view.tscn         # 设置界面（文本/音量/显示/快捷键）
    help_view.tscn             # 帮助/首次提示
    save_load_view.tscn        # 独立存读档界面
    cg_gallery_view.tscn       # CG 鉴赏
    music_gallery_view.tscn    # 音乐鉴赏
  ui/
    notification_view.tscn     # Toast 通知面板
    slot_row.tscn              # 存读档槽位行（缩略图+章节+时间）
    button_ring.tscn           # 按钮环（选项/分支）
    dialogue_box.tscn          # 对话框
    base_menu_view.tscn        # GALGAME 侧栏布局基类
    context_menu.tscn          # 右键/长按上下文菜单
    cg_preview_overlay.tscn    # CG 全屏预览
```

## 剧本文件

默认剧本位于 `resources/scenarios/`，使用 NovaScript 格式。`NovaController` 在启动时加载 Nova 原始剧本：

- `ch1.txt` 到 `ch4.txt` — 示例章节
- `tut01.txt` 到 `tut06.txt` — 教程剧本
- `test_*.txt` — Nova 原始功能自检剧本

## 本地化

本地化字符串位于 `resources/localized_resources/localized_strings/`（当前支持 `en.json` 和 `zh.json`）。`I18n` 模块在启动时根据系统 locale 自动选择语言并回退到英文。

## 存档

存档保存在 Godot 的 `user://saves/` 目录下，每个槽位一个 JSON 文件。使用 Checkpoint + Bookmark 双层模型：bookmark 存储元数据（章节、时间、缩略图），checkpoint 存储运行时状态（GameState + 变量 + restorable 子系统快照）。支持从最近 checkpoint 恢复到任意已读对话位置。

## 自动化测试

项目包含 8 个 headless 测试脚本（`scripts/tests/`），覆盖核心流程：

| 测试 | 覆盖范围 |
|------|----------|
| `parse_scenarios_test.gd` | 28 个 Nova 剧本解析 + 流程图构建 |
| `game_state_smoke_test.gd` | 对话推进、分支选择、变量跳转、结局 |
| `save_system_smoke_test.gd` | 可配置槽位、bookmark 存档、restorable 恢复 |
| `checkpoint_manager_smoke_test.gd` | Position checkpoint、replay 恢复 |
| `nova_compat_smoke_test.gd` | NovaScript 兼容层（l_ label、v_/gv_、branch tuple） |
| `sprite_composer_smoke_test.gd` | StandingProfile 驱动立绘合成 |
| `main_scene_smoke_test.gd` | 主场景加载 + 所有子系统初始化 |
| `scenario_resource_scan_test.gd` | 剧本资源引用扫描 + 缺失报告 |

运行方式：
```bash
Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/<test>.gd
```

## 更多信息

- 开发计划与路线图：[PLAN.md](PLAN.md)
- Nova 对比与阶段复盘：[review.md](review.md)
- NovaScript 语法手册：[docs/NovaScript.md](docs/NovaScript.md)
- 编码规范：[docs/CodingStandards.md](docs/CodingStandards.md)
- 术语表：[docs/ProjectTerms.md](docs/ProjectTerms.md)
- Phase 任务清单：[docs/PhaseBacklog.md](docs/PhaseBacklog.md)

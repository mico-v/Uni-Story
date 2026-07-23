# 快速启动

## 环境要求

- Godot 4.6（标准版即可，无需 .NET）
- 当前开发分支：`dev`

## 打开项目

1. 启动 Godot 4.6，在项目管理器中导入本仓库根目录。
2. 等待编辑器完成资源扫描。
3. 打开主场景 `res://scene/game.tscn`，按 F5 运行。

`Nova/` 仅作为架构参考，不影响 Godot 项目启动。需要查看上游参考工程时执行：

```bash
git submodule update --init Nova
```

## 当前架构概览

项目采用纯 GDScript 实现视觉小说运行时，核心入口是 `NovaController`（挂载在 `game.tscn` 的根节点）。它负责创建所有子系统并将模型信号桥接到视图。

`NovaController` 当前装配约 32 个核心与协调子系统（按 facade/协调器的计数口径略有差异），下表列出主要职责：

| 子系统 | 职责 |
|--------|------|
| `NovaController` | Composition Root，装配所有子系统 |
| `ObjectManager` | 场景对象与脚本常量注册表 |
| `EngineContext` | Typed facade（逐步替代弱类型 _ctx） |
| `RestorableRegistry` | 统一登记 snapshot/restore 子系统 |
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
| `AutoVoiceSystem` | AutoVoiceProfile 驱动的 canonical speaker、6 位编号、delay、显式覆盖与恢复 |
| `CameraSystem` | 逻辑相机移动/缩放/旋转 |
| `TransitionSystem` | 屏幕转场（fade/flash/shader transition） |
| `DialogueBoxSystem` | 对话框位置/样式管理 |
| `VFXSystem` | 对象/后处理/转场 VFX、效果状态栈、屏幕捕获与震动；当前只显示栈顶材质 |
| `PrefabLoader` | WORLD/UI/PERSISTENT 三分类 .tscn 生命周期管理 |
| `VideoSystem` | 视频播放 |
| `PreloadSystem` | image/audio/prefab/other 分类型 LRU、优先级、取消与进度 |
| `HotReload` | 开发期剧本热重载 |
| `ShortcutManager` | 可自定义快捷键 + 冲突检测 |
| `ViewManager` | 视图注册/切换/过渡动画 + 状态管理 |
| `InterruptManager` | 小游戏中断/恢复协议 |
| `DialogSystem` | Toast 通知 + Confirm 确认框 |
| `ThemeManager` | base theme 结构层 + work theme 作品层 |
| `GalleryCoordinator` | CG/音乐鉴赏数据与控制器协调 |
| `SettingsCoordinator` | 设置读取、应用与持久化协调 |
| `MobileUiSupport` | 移动端横屏、触控与安全区适配 |

VFX 的“栈”当前是可快照、可按名称清除的效果状态栈。节点实际只绑定栈顶 `ShaderMaterial`；真正的 SubViewport/多 pass 合成，以及把 `capture_screen()` 结果传给转场 shader，仍属于后续任务。

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

### AutoVoice 配置

自动语音规则位于 `resources/auto_voice_profile.tres`。`AutoVoiceProfile` 将中文 canonical speaker 及 `ergong`、`qianye`、`xiben`、`gaotian` 等别名映射到大小写敏感的 `Voices/Ergong`、`Voices/Qianye`、`Voices/Xiben`、`Voices/Gaotian` 目录，并按 6 位数字补零生成 `.ogg` 路径。

剧本可以用 `显示名//内部名：：台词` 分离 UI 显示名与自动语音身份，例如 `？？？//张浅野：：时机到了`。该别名会在当前 flow-chart node 内继承；进入新 label 后重置。`set_auto_voice_delay()` 只影响下一条符合条件的自动语音，随后归零。显式 `say()` 默认覆盖下一条自动语音，Auto 模式会等待 pending delay 与实际语音播放结束，Backlog 保存精确语音路径以供重播。

AutoVoiceSystem 已注册到 RestorableRegistry。存档和 checkpoint 会保存 enabled/index/prefix、一次性 delay、覆盖标记与当前 cue；恢复时先静默 replay，再恢复 AutoVoice 状态并只调度目标对白，避免历史语音串播或编号重复消费。

## 剧本静态检查

公共 lint 命令默认递归检查 `resources/scenarios/` 下的 28 个主剧本：

```bash
python scripts/tools/scenario_lint.py --godot godot
```

检查范围包括块结构与属性、NovaScript 翻译后的 GDScript 编译、label/start/jump/branch/reachability、剧本资源、canonical speaker，以及 TODO/控制字符/中文引号/半角标点、`anim_hold` 配对、jump-mode branch fallback 和已知 no-op/discarded 兼容调用。诊断使用 `path:line:column: severity [rule] message` 格式。

常用参数：

- `--godot PATH`、`--project PATH`：指定 Godot 可执行文件和项目目录。
- `--format text|json`、`--output PATH`：选择报告格式和输出位置。
- `--fail-on error|warning|never`：设置退出 1 的最低诊断级别；默认 `error`。
- 末尾可传一个或多个剧本文件/目录；省略时检查默认目录。

退出码 0 表示未达到失败阈值，1 表示存在达到阈值的诊断，2 表示参数、Godot 启动或报告生成等命令错误。当前默认 corpus 为 `files=28`、`errors=0`、`warnings=133`、`referenced=372`、`found=370`、`virtual=2`、`missing=0`。CI/Release 使用 error 阈值，因此现有 warning 会被报告但不阻断构建。

## 剧本对白统计

使用公共 Scenario stat 命令生成全量剧本的 source inventory：

```bash
python scripts/tools/scenario_stat.py --godot godot --top 0
```

统计器使用不执行 eager code 的共享静态 IR，汇总文件、block、node、对白、canonical speaker、长度分布、最长对白和 jump/branch 流程；它不是单次通关时长估算。`--format text|json` 与 `--output PATH` 控制报告，`--top N` 控制最长对白条数（默认 10，`0` 关闭），末尾可传一个或多个文件/目录。退出码 0 表示成功，2 表示参数、输入、分析或基础设施失败。

文本规范化会移除配对 rich tag 和 `（TODO：…）` 注记、合并连续 ASCII 空格，并以 Unicode code point 计长。canonical speaker 映射在当前 node 内继承，遇到下一条 `label()` 重置。当前默认基线为 `files=28`、`blocks=360 (106 eager/254 lazy)`、`nodes=53`、`dialogues=731`、`spoken=111`、`narration=620`、`characters=15434`、`p50=14`、`p90=47`、`p95=62`、`jumps=23`、`branch_options=24`、`silent_entries=1`。

## 本地化

本地化字符串位于 `resources/localized_resources/localized_strings/`（当前支持 `en.json` 和 `zh.json`）。`I18n` 模块在启动时根据系统 locale 自动选择语言并回退到英文。

## 存档

存档保存在 Godot 的 `user://saves/` 目录下，每个槽位一个 JSON 文件。使用 Checkpoint + Bookmark 双层模型：bookmark 存储元数据（章节、时间、缩略图），checkpoint 存储运行时状态（GameState + 变量 + restorable 子系统快照）。支持从最近 checkpoint 恢复到任意已读对话位置。

## 自动化测试

项目包含 20 个 headless 测试脚本（`scripts/tests/`），当前完整套件为 20/20 PASS（约 55 秒），由跨平台 Python runner 统一执行：

| 测试 | 覆盖范围 |
|------|----------|
| `auto_voice_system_smoke_test.gd` | Profile 路径、canonical speaker、delay、显式覆盖、Backlog 与 checkpoint 恢复 |
| `parse_scenarios_test.gd` | 28 个 Nova 剧本解析 + 流程图构建 |
| `game_state_smoke_test.gd` | 对话推进、分支选择、变量跳转、结局 |
| `save_system_smoke_test.gd` | 可配置槽位、bookmark 存档、restorable 恢复 |
| `checkpoint_manager_smoke_test.gd` | Position checkpoint、replay 恢复 |
| `nova_compat_smoke_test.gd` | NovaScript 兼容层（l_ label、v_/gv_、branch tuple） |
| `sprite_composer_smoke_test.gd` | StandingProfile 驱动立绘合成 |
| `main_scene_smoke_test.gd` | 主场景加载 + 所有子系统初始化 |
| `scenario_linter_smoke_test.gd` | lint 有效/损坏 fixture、rule ID/定位/排序、JSON 与退出码 |
| `scenario_resource_scan_test.gd` | 剧本资源引用扫描 + 缺失报告 |
| `scenario_stat_smoke_test.gd` | execution-free 共享 IR、文本规范化、统计 schema/基线、Godot/Python CLI 与 0/2 退出码 |
| `chapter_select_smoke_test.gd` | 章节列表、解锁与起始节点选择 |
| `load_runtime_scripts_test.gd` | runtime/core 脚本加载与解析 |
| `nova_ch1_playback_smoke_test.gd` | 第一章关键播放路径 |
| `nova_runtime_compile_test.gd` | NovaScript 到 GDScript 的动态编译 |
| `nova_visual_compat_smoke_test.gd` | Nova 图像、立绘与演出兼容 |
| `prefab_loader_smoke_test.gd` | Prefab 三分类生命周期与快照恢复 |
| `preload_system_smoke_test.gd` | 分类型缓存、优先级、取消、进度与恢复 |
| `theme_manager_smoke_test.gd` | base/work theme 加载、应用与恢复 |
| `vfx_stack_smoke_test.gd` | 效果状态栈、按名清理、捕获接口与恢复 |

严格资源扫描包含 `say(speaker, id)` 引用；当前结果为 `referenced=369`、`found=367`、`virtual=2`、`missing=0`。

完整套件运行方式：

```bash
godot --headless --path . --import
python scripts/tools/scenario_lint.py --godot godot
python scripts/tools/scenario_stat.py --godot godot --top 0
python scripts/tests/run_headless_suite.py --godot godot --timeout 180
```

单测仍可直接运行：

```bash
godot --headless --path . --script res://scripts/tests/<test>.gd
```

`scripts/tests/run_headless_suite.py` 会自动发现全部 `*_test.gd`，检测非零退出码、超时和 Godot 脚本错误。CI 与 release workflow 会先以 `--fail-on error` 运行 Scenario lint，再运行完整 headless 门禁；只有两者通过后才开始 Windows、Linux 和 Android 构建。

## 更多信息

- 开发计划与路线图：[PLAN.md](PLAN.md)
- Nova 对比与阶段复盘：[review.md](review.md)
- NovaScript 语法手册：[docs/NovaScript.md](docs/NovaScript.md)
- 编码规范：[docs/CodingStandards.md](docs/CodingStandards.md)
- 术语表：[docs/ProjectTerms.md](docs/ProjectTerms.md)
- Phase 任务清单：[docs/PhaseBacklog.md](docs/PhaseBacklog.md)

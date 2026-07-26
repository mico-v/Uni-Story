# Uni-Story

Uni-Story 是从 Nova2 项目继续开发而来的 Godot 视觉小说运行时/框架。当前分支基于 Godot 4.6，保留 NovaScript 风格的剧本组织方式，并把演出脚本块编译为真正的 GDScript 执行，用于验证更轻量、可重放的视觉小说运行时架构。

本仓库延续自 Nova2，原项目采用 MIT License。继续开发、分发或再授权本项目时，需要保留 `LICENSE` 中的原版权声明和许可文本。

## 当前状态

- 引擎：Godot 4.6
- 主场景：`res://scene/game.tscn`
- 当前开发分支：`dev`
- 运行时路线：标准版 Godot 4.6 + GDScript，不需要 .NET 工具链
- 剧本路线：保留 NovaScript 格式，将 `<|...|>` / `@<|...|>` 演出块包装为 `BaseBlock` 子类并在运行时编译执行
- 开发阶段：全部 18 个 Phase 任务全部完成（Phase 0-18 ✅），项目达到 v1.0.0-rc1 里程碑

## 快速启动

1. 安装 Godot 4.6。
2. 使用 Godot 打开本仓库根目录。
3. 运行主场景 `res://scene/game.tscn`。

项目使用标准版 Godot 4.6；核心模型、演出运行时、UI 和测试均由 GDScript 驱动。

## 主要能力

- 剧本解析：将 NovaScript 剧本切分为 eager、lazy 和 text 块。
- 流程图：构建章节、节点、跳转和选项。
- 剧本静态检查：`scripts/tools/scenario_lint.py` 检查结构/属性、GDScript 编译、label/start/jump/branch/reachability、资源、canonical speaker 与常见内容/兼容陷阱，支持 text/JSON 报告和可配置失败阈值。
- 剧本静态分析与统计：`scripts/tools/scenario_stat.py` 基于不执行 eager code 的共享 IR，按文件、节点和 canonical speaker 汇总对白长度、最长对白与流程结构；同一 IR 将供后续分支可视化复用。
- 对话系统：支持说话人、逐字显示、对话框位置预设和文本回顾。
- 图片与立绘：支持图片显示/隐藏/移动/染色，多图层立绘合成和头像切换。
- 动画系统：支持 `o.anim` 链式动画，区分 per_dialogue/holding/ui/text 动画域，支持 pause/resume/stop，命名 holding 动画组，Nova 风格 easing 解析器。
- 音频接口：提供 BGM（交叉淡入淡出）、SE（池化抢占）、Voice 的运行时 API，支持 BGM/SE/Voice 独立音量总线。
- 自动语音：AutoVoiceProfile/AutoVoiceSystem 按 canonical speaker 解析 `显示名//内部名`，从角色目录生成 6 位语音编号；支持下一句一次性 delay、显式 `say()` 覆盖、存档/回跳恢复、Auto 等待语音结束和 Backlog 重播。
- 镜头与转场：支持逻辑相机移动、缩放、旋转，以及 fade、fade_out、fade_in、flash、dissolve、wipe。
- 变量与分支：支持运行时变量、条件跳转和分支选择，`v_` / `gv_` 变量前缀兼容。
- 预制体加载：PrefabLoader 支持 WORLD、UI、PERSISTENT 三类生命周期，运行时加载 .tscn、同名幂等复用、ObjectManager 注册和存读档快照。
- 资源预加载：PreloadSystem 提供 image/audio/prefab/other 分类型 LRU 缓存、优先级排序、引用计数取消和总体/分类型进度。
- 主题系统：ThemeManager 组合 `base_theme.tres` 结构主题与作品级 work theme，可在运行时切换并恢复当前作品主题。
- 存档与回顾：JSON 存档槽位，Checkpoint/Bookmark 双层模型，reached dialogue/end 追踪，回顾跳转优先从最近 checkpoint 恢复再 replay 到目标。
- 自动播放与快进：Auto 模式打字机结束后定时推进，Skip 模式跳过已读文本并在未读处自动停止。
- 视图管理：ViewManager 统一管理视图注册、切换和过渡动画（淡入淡出/滑动/瞬间），Title/UI/Game/InTransition/Alert 五种状态，过渡期输入屏蔽。
- 输入映射：ShortcutManager 管理可自定义快捷键，Settings 界面按键录制 + 冲突检测 + 恢复默认，持久化到 ConfigFile。
- UI 产品层：GALGAME 主菜单（开始/章节选择/继续/读取/设置/CG/音乐/帮助/退出），存读档界面（缩略图 + 章节名 + 位置 + 时间），回顾面板（语音重播 + 跳转确认），统一 Toast 通知和 Confirm 确认框。
- 设置界面：文字速度、自动模式速度、全局/BGM/SE/语音音量、全屏、字体大小、语言切换、对话框透明度、点击停止动画/语音、快进未读文本。
- 鉴赏界面：CG 图片鉴赏（缩略图网格 + 全屏预览）和音乐鉴赏（曲目列表 + 播放控制 + 多种播放模式）。
- VFX/Shader：对象特效（blur、grayscale、dissolve、glitch、ripple）、后处理特效（chromatic、vignette、grayscale、blur、glitch）、屏幕震动和 shader 转场。系统维护最多三层效果状态栈并支持按名称移除，但当前渲染只把栈顶材质应用到节点；真正的多 pass 合成和使用 captured texture 的转场仍待实现。
- 中断/小游戏：InterruptManager 支持 begin/end_interrupt 协议，中断期间暂停对话推进，结束后自动 checkpoint。
- 移动端：安卓/移动端强制横屏/全屏，viewport expand 自适应布局，背景/CG cover fit，触控操作和长按菜单。
- 自动化测试：31/31 个 headless 测试通过（约 55 秒），由 `scripts/tests/run_headless_suite.py` 统一发现和执行；CI 与 release 均先运行 Scenario lint 和完整套件，再构建 Windows、Linux、Android 产物。
- 资源扫描：`scenario_resource_scan_test.gd` 覆盖 `say(speaker, id)` 等剧本资源引用；当前 `referenced=369`、`found=367`、`virtual=2`、`missing=0`。

## 剧本静态检查

公共入口默认检查 `resources/scenarios/` 下的 28 个主剧本：

```bash
python scripts/tools/scenario_lint.py
```

当前默认结果为 `errors=0`、`warnings=133`，资源统计为 `referenced=372`、`found=370`、`virtual=2`、`missing=0`；lint 额外扫描 branch image，因此与独立严格资源回归的 `369/367/2/0` 口径不同。诊断格式为 `path:line:column: severity [rule] message`。

可用 `--godot` / `--project` 指定环境，传入文件或目录限制范围；`--format text|json`、`--output PATH` 控制报告，`--fail-on error|warning|never` 控制失败阈值。退出码为 0（未达到失败阈值）、1（存在达到阈值的诊断）、2（命令或基础设施错误）。默认只因 error 失败，warning 不阻断 CI/Release。

## 剧本对白统计

公共统计入口默认分析同一批 28 个主剧本：

```bash
python scripts/tools/scenario_stat.py --top 0
```

该命令建立 execution-free 的 `blocks/nodes/entries/silent_entries/edges/events` 共享 IR；eager block 只翻译供静态分析参考，绝不执行。统计是全量剧本 source inventory，不代表单次通关时长。`--top N` 控制最长对白列表（默认 10，`0` 关闭），其余常用参数为 `--godot`、`--project`、`--format text|json` 和 `--output PATH`；退出码为 0（成功）或 2（参数、输入、分析或基础设施失败）。

当前默认基线为 `files=28`、`blocks=360 (106 eager/254 lazy)`、`nodes=53`、`dialogues=731`、`spoken=111`、`narration=620`、`characters=15434`、`p50=14`、`p90=47`、`p95=62`、`jumps=23`、`branch_options=24`、`silent_entries=1`。`speakers=8` 表示 canonical speaker 分组数；另有 9 个 display speaker 和 1 条动态 speaker entry。

## 自动化测试

先导入项目，再运行 Scenario lint、Scenario stat 和完整测试套件：

```bash
godot --headless --path . --import
python scripts/tools/scenario_lint.py --godot godot
python scripts/tools/scenario_stat.py --godot godot --top 0
python scripts/tests/run_headless_suite.py --godot godot --timeout 180
```

当前 31 个测试为：

- `auto_voice_system_smoke_test.gd`
- `chapter_select_smoke_test.gd`
- `checkpoint_manager_smoke_test.gd`
- `editor_tools_smoke_test.gd`
- `export_smoke_test.gd`
- `game_state_smoke_test.gd`
- `i18n_switch_smoke_test.gd`
- `load_runtime_scripts_test.gd`
- `main_scene_smoke_test.gd`
- `minigame_smoke_test.gd`
- `minigame_templates_smoke_test.gd`
- `nova_ch1_playback_smoke_test.gd`
- `nova_compat_smoke_test.gd`
- `nova_lua_compat_smoke_test.gd`
- `nova_runtime_compile_test.gd`
- `nova_visual_compat_smoke_test.gd`
- `parse_scenarios_test.gd`
- `performance_baseline_test.gd`
- `prefab_loader_smoke_test.gd`
- `preload_system_smoke_test.gd`
- `sample_work_playback_smoke_test.gd`
- `sample_work_save_load_test.gd`
- `save_system_smoke_test.gd`
- `scenario_linter_smoke_test.gd`
- `scenario_resource_scan_test.gd`
- `scenario_stat_smoke_test.gd`
- `scenario_visualize_smoke_test.gd`
- `shader_effects_smoke_test.gd`
- `sprite_composer_smoke_test.gd`
- `theme_manager_smoke_test.gd`
- `vfx_stack_smoke_test.gd`

## 目录结构

```text
scene/
  game.tscn                 # 项目主场景，挂载 NovaController + 8 个 View
  view/                     # 顶层视图场景（标题/章节选择/游戏/设置/鉴赏/存读档/帮助）
  ui/                       # UI 组件（按钮环/对话框/通知/槽位行）
scripts/
  NovaController.gd          # Node 中枢协调器（Composition Root）
  core/                      # 纯模型、剧本解析、流程图、状态、存档、回顾、I18n、视图管理、中断
  runtime/                   # 演出脚本运行时、图像、动画、音频、镜头、转场、VFX 等系统
  ui/                        # 视图控制器（标题/游戏/设置/鉴赏/存读档/回顾/帮助）
  tests/                     # 31 个 Headless 测试 + run_headless_suite.py
  tools/                     # Scenario lint + stat + visualize + 9 个资源工具 + shaderproto_gen + vscode/
resources/
  auto_voice_profile.tres    # canonical speaker、角色语音目录、6 位编号规则
  Voices/                    # 按角色目录存放的自动/手动语音资源
  scenarios/                 # 示例剧本与综合自检剧本（28 个 Nova 原始剧本）
  characters/                # 示例角色素材
  demo_media/                # 示例演示素材
  prefabs/                   # 运行时可加载的预制体场景（.tscn）
  shaders/                   # 12 个 Godot shader（含对象版、后处理版和转场）
```

## 剧本 API

演出脚本块继承 `BaseBlock`，可使用下列运行时 API。完整说明见 [docs/NovaScript.md](docs/NovaScript.md)，开发计划见 [PLAN.md](PLAN.md)。

- 流程：`label`、`jump_to`、`jump_if`、`branch`、`is_start`、`is_end`
- 图像：`show`、`hide`、`move`、`tint`
- 立绘与头像：`show_char`、`set_layer`、`hide_char`、`set_avatar`、`clear_avatar`
- 动画：`o.anim.PropertyVector3(...)`、`o.anim.PropertyColor(...)`、`o.anim.PropertyFloat(...)`、`o.anim.MoveTo(...)`、`o.anim.FadeTo(...)`、`o.anim.RotateTo(...)`、`o.anim.ScaleTo(...)`、`o.anim.holding(...)`（命名 holding 动画组）
- 音频：`play_bgm`、`stop_bgm`、`play_se`、`play_voice`、`say`、`auto_voice_on`、`auto_voice_off`、`auto_voice_off_all`、`set_auto_voice_delay`、`auto_voice_skip`
- 镜头/转场/对话框：`cam`、`trans`、`set_box`
- VFX：`vfx`、`clear_vfx`、`clear_effect`、`capture_screen`、`post_fx`、`clear_post_fx`、`shake`
- 预制体：`load_prefab`、`load_ui_prefab`、`load_persistent_prefab`、`show_prefab`、`hide_prefab`、`destroy_prefab`
- 时间轴：`timeline().at(time, callable).play()`
- 视频：`play_video`
- 对话框：`show_toast`、`show_confirm`
- 预加载：`preload_asset`、`cancel_preload`、`cancel_all_preloads`
- 变量：`set_var`、`get_var`、`has_var`、`add_var`
- 中断：`begin_interrupt`、`end_interrupt`、`is_interrupt_active`
- 其它：`wait`、`print`

## 路线图

全部 18 个 Phase 任务已完成 ✅。项目达到 v1.0.0-rc1 里程碑。

| 维度 | 覆盖率 vs Nova |
|------|:---:|
| 工具链 | **93%** (25/27) |
| Shader 丰富度 | **87%** (84 gdshader / 49 shaderproto) |
| Editor 集成 | **55%** (17/31) |
| Lua 兼容 | **96%** |
| I18n 内容 | **90%** |
| 文档 | **95%** |

下一步：三平台（Windows/Linux/Android）真机验证后发布 v1.0.0。

更完整的路线图与执行记录请查看 [PLAN.md](PLAN.md)。发布流程请查看 [docs/ReleaseGuide.md](docs/ReleaseGuide.md)。

## 许可

本项目基于 Nova2 继续开发，遵循 MIT License。原版权声明为：

```text
Copyright (c) 2024 Lunatic Works
```

任何复制、修改、合并、发布、分发、再授权或销售本项目副本的行为，都必须在副本或实质性部分中包含 MIT 许可文本和上述版权声明。完整许可文本见 [LICENSE](LICENSE)。

# Uni-Story

Uni-Story 是从 Nova2 项目继续开发而来的 Godot 视觉小说运行时/框架。当前分支基于 Godot 4.6，保留 NovaScript 风格的剧本组织方式，并把演出脚本块编译为真正的 GDScript 执行，用于验证更轻量、可重放的视觉小说运行时架构。

本仓库延续自 Nova2，原项目采用 MIT License。继续开发、分发或再授权本项目时，需要保留 `LICENSE` 中的原版权声明和许可文本。

## 当前状态

- 引擎：Godot 4.6
- 主场景：`res://scene/game.tscn`
- 当前开发分支：`rewrite/godot4.6`
- 运行时路线：纯 GDScript 实现核心模型与演出运行时
- 剧本路线：保留 NovaScript 格式，将 `<|...|>` / `@<|...|>` 演出块包装为 `BaseBlock` 子类并在运行时编译执行
- 开发阶段：10 个 Phase 核心任务全部完成（Phase 0-10），已具备可做真实作品的引擎骨架

## 快速启动

1. 安装 Godot 4.6。
2. 使用 Godot 打开本仓库根目录。
3. 运行主场景 `res://scene/game.tscn`。

仓库中保留了 Godot .NET 项目文件，但当前 `rewrite/godot4.6` 分支的核心运行时主要由 GDScript 驱动。本地没有 .NET 环境时，也可以先使用 Godot 编辑器运行和验证 GDScript 侧功能。

## 主要能力

- 剧本解析：将 NovaScript 剧本切分为 eager、lazy 和 text 块。
- 流程图：构建章节、节点、跳转和选项。
- 对话系统：支持说话人、逐字显示、对话框位置预设和文本回顾。
- 图片与立绘：支持图片显示/隐藏/移动/染色，多图层立绘合成和头像切换。
- 动画系统：支持 `o.anim` 链式动画，区分 per_dialogue/holding/ui/text 动画域，支持 pause/resume/stop，命名 holding 动画组，Nova 风格 easing 解析器。
- 音频接口：提供 BGM（交叉淡入淡出）、SE（池化抢占）、Voice 的运行时 API，支持 BGM/SE/Voice 独立音量总线。
- 镜头与转场：支持逻辑相机移动、缩放、旋转，以及 fade、fade_out、fade_in、flash、dissolve、wipe。
- 变量与分支：支持运行时变量、条件跳转和分支选择，`v_` / `gv_` 变量前缀兼容。
- 预制体加载：PrefabLoader 子系统支持运行时加载 .tscn 场景，幂等加载（同名复用），注册到 ObjectManager 后可用 move/tint/o.anim 等现有 API 操作，支持存读档快照。
- 存档与回顾：JSON 存档槽位，Checkpoint/Bookmark 双层模型，reached dialogue/end 追踪，回顾跳转优先从最近 checkpoint 恢复再 replay 到目标。
- 自动播放与快进：Auto 模式打字机结束后定时推进，Skip 模式跳过已读文本并在未读处自动停止。
- 视图管理：ViewManager 统一管理视图注册、切换和过渡动画（淡入淡出/滑动/瞬间），Title/UI/Game/InTransition/Alert 五种状态，过渡期输入屏蔽。
- 输入映射：ShortcutManager 管理可自定义快捷键，Settings 界面按键录制 + 冲突检测 + 恢复默认，持久化到 ConfigFile。
- UI 产品层：GALGAME 主菜单（开始/章节选择/继续/读取/设置/CG/音乐/帮助/退出），存读档界面（缩略图 + 章节名 + 位置 + 时间），回顾面板（语音重播 + 跳转确认），统一 Toast 通知和 Confirm 确认框。
- 设置界面：文字速度、自动模式速度、全局/BGM/SE/语音音量、全屏、字体大小、语言切换、对话框透明度、点击停止动画/语音、快进未读文本。
- 鉴赏界面：CG 图片鉴赏（缩略图网格 + 全屏预览）和音乐鉴赏（曲目列表 + 播放控制 + 多种播放模式）。
- VFX/Shader：对象特效（blur、grayscale、dissolve、glitch、ripple）、后处理特效（chromatic、vignette、grayscale、blur、glitch）、屏幕震动、shader 转场，效果注册表驱动，支持多参数动画和存档恢复。
- 中断/小游戏：InterruptManager 支持 begin/end_interrupt 协议，中断期间暂停对话推进，结束后自动 checkpoint。
- 移动端：安卓/移动端强制横屏/全屏，viewport expand 自适应布局，背景/CG cover fit，触控操作和长按菜单。
- 自动化测试：7 个 headless smoke test（parse/game_state/save/checkpoint/nova_compat/sprite_composer/main_scene）+ 资源扫描工具，覆盖核心流程。
- 资源扫描：`scenario_resource_scan_test.gd` 自动扫描剧本文件中的资源引用并报告缺失项。

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
  tests/                     # Headless 自动化测试（8 个）
resources/
  scenarios/                 # 示例剧本与综合自检剧本（28 个 Nova 原始剧本）
  characters/                # 示例角色素材
  demo_media/                # 示例演示素材
  prefabs/                   # 运行时可加载的预制体场景（.tscn）
  shaders/                   # 8 个 GLSL shader（blur/grayscale/dissolve/chromatic/vignette/wipe/glitch/ripple）
```

## 剧本 API

演出脚本块继承 `BaseBlock`，可使用下列运行时 API。完整说明见 [docs/NovaScript.md](docs/NovaScript.md)，开发计划见 [PLAN.md](PLAN.md)。

- 流程：`label`、`jump_to`、`jump_if`、`branch`、`is_start`、`is_end`
- 图像：`show`、`hide`、`move`、`tint`
- 立绘与头像：`show_char`、`set_layer`、`hide_char`、`set_avatar`、`clear_avatar`
- 动画：`o.anim.PropertyVector3(...)`、`o.anim.PropertyColor(...)`、`o.anim.PropertyFloat(...)`、`o.anim.MoveTo(...)`、`o.anim.FadeTo(...)`、`o.anim.RotateTo(...)`、`o.anim.ScaleTo(...)`、`o.anim.holding(...)`（命名 holding 动画组）
- 音频：`play_bgm`、`stop_bgm`、`play_se`、`play_voice`
- 镜头/转场/对话框：`cam`、`trans`、`set_box`
- VFX：`vfx`、`clear_vfx`、`post_fx`、`clear_post_fx`、`shake`
- 预制体：`load_prefab`、`show_prefab`、`hide_prefab`、`destroy_prefab`
- 时间轴：`timeline().at(time, callable).play()`
- 视频：`play_video`
- 对话框：`show_toast`、`show_confirm`
- 预加载：`preload_asset`
- 变量：`set_var`、`get_var`、`has_var`、`add_var`
- 中断：`begin_interrupt`、`end_interrupt`、`is_interrupt_active`
- 其它：`wait`、`print`

## 路线图

全部 10 个 Phase 核心任务已完成。下一步优先补齐以下能力：

- 随意缩放窗口 / 对话框完整功能
- 手柄支持 / 立绘裁剪工具
- UI 主题资源拆分
- 导出 smoke test / 性能基线

更完整的路线图与执行记录请查看 [PLAN.md](PLAN.md)。

## 许可

本项目基于 Nova2 继续开发，遵循 MIT License。原版权声明为：

```text
Copyright (c) 2024 Lunatic Works
```

任何复制、修改、合并、发布、分发、再授权或销售本项目副本的行为，都必须在副本或实质性部分中包含 MIT 许可文本和上述版权声明。完整许可文本见 [LICENSE](LICENSE)。

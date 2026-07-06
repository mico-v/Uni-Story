# Uni-Story 项目术语表

本文统一后续 Phase 中会反复出现的核心术语，避免存档、回跳、章节解锁和脚本兼容讨论混用概念。

## 流程与脚本

- `node`：流程图节点，对应剧本中的一个 `label(...)`。一个 node 持有一组有序 entry，并可通过 `jump_to()` 或 `branch()` 指向后续 node。
- `entry`：node 内的一条对白或静默执行项。entry 可包含 `before_checkpoint`、默认 lazy block、`after_dialogue` 三个运行阶段。
- `chapter`：面向玩家展示的章节入口。技术上通常是被 `is_start()`、`is_unlocked_start()` 或 `is_debug()` 标记的 node；`is_chapter()` 只表示章节展示语义，不等同于起始入口。
- `branch mode`：分支的选择和跳转策略。当前包含 normal/show/enable/jump：normal 与 show 展示可选项，enable 展示但可禁用，jump 在条件满足时直接跳转。
- `runtime stage`：entry 运行脚本的阶段。`before_checkpoint` 先于 checkpoint 语义执行，默认 lazy block 在对白展示前执行，`after_dialogue` 在对白展示后执行。

## 存档与进度

- `checkpoint`：可恢复的运行时快照。包含当前 GameState、变量、各 restorable 子系统状态、node record、reached data，以及脚本 hash/version 等迁移信息。
- `bookmark`：玩家看到的存档槽 metadata + checkpoint envelope。bookmark 负责展示创建时间、章节名、entry index、缩略图路径和 global save id；真正恢复仍交给 checkpoint。
- `reached`：玩家历史上已经到达过的进度记录。当前至少包含 reached dialogue 和 reached ending，用于已读、回顾跳转、章节解锁和后续 skip unread。
- `node record`：对已访问 node 的摘要记录，包括 name、parent、begin/end dialogue、display name 和 variables hash，用于章节/回顾/迁移审查。
- `global save id`：bookmark 的全局唯一标识，用于后续云存档、跨槽引用或 UI 刷新去重。
- `slot metadata`：存档槽位的展示元数据（chapter、display_name、entry_index、created_at_unix、screenshot_path），由 `SaveSystem.slot_metadata()` 返回，用于存读档 UI 丰富列表。

## UI 与产品层

- `title view`：标题主菜单。只负责展示入口，具体导航由 `NovaController` 统一路由。
- `chapter select view`：章节选择页。按 Nova 规则展示 normal/unlocked/debug start node，并通过 reached dialogue 解锁章节。
- `help view`：帮助与首次提示页面。承载项目说明、基础操作和存档/回顾说明。
- `view manager`：视图切换器。负责注册、显示、隐藏和过渡动画（Fade/Slide），支持 Title/UI/Game/InTransition/Alert 五种状态。切出 GameView 时自动暂停动画域和语音。
- `GlobalUI`：主场景中独立于各 View 的 Control 层（z_index=1000），用于承载 Toast 通知等跨视图 UI 元素。

## 动画

- `animation domain`：动画域，分类为 PER_DIALOGUE（对白期间）、HOLDING（持续循环）、UI（界面动画）、TEXT（文字效果）。由 `AnimationSystem.Domain` 枚举定义。
- `holding animation group`：命名 holding 动画组。通过 `AnimationSystem.holding(group_name)` 创建，可通过 `stop_holding_group(group_name)` 按组停止。
- `easing`：缓动函数描述符（如 "inOutCubic"、"outElastic"），由 `AnimationSystem.parse_easing()` 解析为 Godot Tween 枚举。

## VFX / Shader

- `object VFX`：施加于单个场景对象（bg/fg/character）的 shader 特效。
- `post VFX`：施加于全屏后处理层的 shader 特效。
- `transition VFX`：用于屏幕转场的 shader（dissolve、wipe 等）。
- `shader registry`：VFXSystem 中的 `OBJECT_EFFECTS` / `POST_EFFECTS` / `TRANSITION_EFFECTS` 字典，记录 effect name → shader path + 默认参数 + 可动画参数。

## 中断 / 小游戏

- `interrupt`：VN 流程中断协议。`begin_interrupt()` 暂停对话推进、auto/skip 模式，小游戏结束后 `end_interrupt()` 恢复并创建 checkpoint。
- `fence`：中断边界标记，确保中断期间的 VN 状态不被意外修改。

## 资源 / 工具

- `scenario resource scan`：头部分析剧本文件中的资源引用（图片、音频、视频、预制体），报告缺失资源的自动检查工具。实现于 `scripts/tests/scenario_resource_scan_test.gd`。
- `StandingProfile`：立绘合成配置文件（`.tres`），定义角色目录、pose、layer order 和 offset fallback。
- `VisualProfile`：视觉资源 alias 配置文件（`.tres`），定义 CG 等资源的别名映射。

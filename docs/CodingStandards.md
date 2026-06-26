# Uni-Story 编码规范与记忆规则

本文记录开发 Uni-Story 时需要持续遵守的工程规则。它不是通用 GDScript 教程，而是本项目在演进过程中要记住的约束。

## 项目方向

- Uni-Story 是 Godot 4.6 + GDScript-first 的视觉小说引擎，不默认引入 Unity/C# 依赖，也不把 Lua VM 作为默认运行时。
- Nova 是架构参考，不是逐行复刻目标；遇到 Nova 实现与 Godot 可维护性冲突时，优先保留 Godot 原生结构。
- 新功能要服务真实 VN 作品能力，优先保证流程、存档、恢复、脚本兼容、工具链和 UI 稳定性。

## 架构边界

- `NovaController.gd` 是 composition root，只负责装配子系统、视图绑定和全局信号路由；新增业务逻辑优先放入 `scripts/core/*`、`scripts/runtime/*` 或 `scripts/ui/*` 的专门类。
- 新代码需要访问子系统时，优先考虑 `EngineContext` typed facade；兼容旧代码时才直接使用 `_ctx.xxx`。
- UI 结构放 `.tscn`，UI 逻辑放 controller/coordinator；不要把大型动态 UI 拼装继续堆进 `NovaController.gd`。
- Runtime 表现系统要实现清晰的 `snapshot()` / `restore(data)` 后再参与存档恢复。

## GDScript 风格

- 核心脚本尽量提供 `class_name`、明确返回值和关键变量类型；遇到 Godot 静态推断不稳定时显式标注类型。**避免使用 `:=` 类型推导式**
- 保存数据、checkpoint、配置数据必须保持 JSON 可序列化：只使用 Dictionary、Array、String、float、int、bool 和 null。
- 代码默认使用 ASCII；中文主要用于文档、UI 文案和已有中文资源。
- 注释只解释非显然约束、恢复顺序、兼容策略或复杂流程，不写重复代码含义的空注释。
- 不做无关重构；每次改动尽量收敛到当前 phase 需要的模块和行为面。

## 存档与恢复

- 所有可恢复子系统统一通过 `RestorableRegistry` 注册，遵守 `snapshot()` / `restore(data)` duck-typed 约定。
- Phase 3 以后手动存档、自动存档和回顾跳转应逐步走 `CheckpointManager`，`SaveSystem` 只负责 slot 文件管理和格式兼容。
- 新存档格式必须保留 `version` 和可迁移字段；读取逻辑要尽量兼容已有旧存档，不轻易破坏玩家数据。
- Checkpoint 数据要包含当前 `GameState`、变量快照、restorable 快照、reached dialogue/end、node record，以及为脚本升级预留的 hash/version 字段。
- 恢复顺序要谨慎：先恢复 `GameState`，再恢复其他表现/进度 restorable，避免 replay 与表现状态互相覆盖。
- 回顾或任意已读对白跳转必须优先走“最近 checkpoint restore + replay 到目标 entry”；直接 `jump_to_position()` 只能作为无法 replay 时的兜底。
- 修改 `before_checkpoint`、default lazy、`after_dialogue` 或 checkpoint/replay 顺序时，必须跑 `checkpoint_manager_smoke_test.gd` 和 `save_system_smoke_test.gd`。

## NovaScript 兼容

- 兼容 NovaScript 时优先做语义映射和转换层，避免把 Nova 的运行时实现细节直接搬进 Godot。
- `before_checkpoint`、default lazy、`after_dialogue` 的阶段语义不能随意调换；它们会影响 checkpoint 和 replay 的确定性。
- `v_` 是当前存档变量，`gv_` 是全局变量；新增脚本 API 时不要破坏这个约定。
- 解析或运行时错误要尽量保留脚本块类型、节点名和 Godot 编译错误，方便后续 lint 工具定位。

## 测试规则

- 涉及 parser、GameState、SaveSystem、CheckpointManager、runtime 编译的改动，需要补或更新 headless smoke test。
- 窄改动跑对应测试；触及核心流程或存档格式时，至少跑 `game_state_smoke_test.gd`、`save_system_smoke_test.gd` 和相关兼容测试。
- 测试资源优先写到 `user://tests/`，避免污染 `res://resources/`。
- 如果本机 Godot 报缺少可选 autoload，但测试退出码为 0，要在总结中说明这是环境噪音，不把它当成本次失败。

## 日志与错误

- 核心子系统优先使用 `EngineLog` 分类日志：parse、runtime、save、asset、config、restore、ui。
- 可以在很小的基础类里使用 Godot 原生 `push_warning`，但新 subsystem 的用户可见错误应尽量走统一日志分类。
- 损坏存档、版本不支持、资源缺失和脚本编译失败都要明确日志，不静默吞掉。

## 前端与场景

- `.tscn` 场景和 controller 职责保持分离；不要在 controller 里无边界创建复杂场景树。
- VN 产品界面要安静、可扫描、可反复操作；存读档、回顾、设置等工具界面优先密度和清晰状态。
- 不新增无意义的装饰性页面；功能入口应直接可用。

## Git 与协作

- 工作区可能有用户未提交改动；不要回滚自己没有创建的变化。
- 新增或修改文件使用 `apply_patch`；不要用 shell 重定向或脚本随意写文件。
- 文档与阶段进度同步：阶段完成或偏差明确后更新 `PLAN.md` 和必要的 review 文档。

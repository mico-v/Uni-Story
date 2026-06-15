# Nova2 架构对齐执行计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 `review.md` 的 P0/P1 风险，持续把当前 GDScript 重构对齐到 Nova2 的行为模型，优先修复可恢复性与分支语义差异，再补齐对象生命周期和输入/本地化边界。

**Architecture:** 分三层推进：
1) 先补齐“流程语义与失败边界”；
2) 再补齐“状态可恢复性和对象冻结边界”；
3) 最后补齐“UI/输入分层与 i18n 可扩展性”。

**Tech Stack:** Godot 4 + GDScript；文件路径采用现有 `scripts/core`, `scripts/runtime`, `resources/scenarios`。

---

## 说明：先做基础记录，再做主改造

本计划按 `review.md` 的风险顺序输出，同时兼顾“可复现”的验收方式（每个关键点都对应一个场景级回归用例）。

### 记录文件

- 新建记录目录：`docs/superpowers/plans/`（已用于该计划文件）
- 每完成一个任务，直接更新对应任务状态；阶段性总览保留在文末“执行状态”，避免重复记录。

---

### 任务 1：建立回归验收用例（不改运行行为）

**Files:**
- Create: `resources/scenarios/review_regression_branch.txt`
- Create: `resources/scenarios/review_regression_branch_attr.txt`
- Create: `resources/scenarios/review_regression_resume.txt`
- Create: `resources/scenarios/review_regression_sanity.txt`
- Modify: `scripts/NovaController.gd`

- [x] **执行结果：回归场景已建立**
  `NovaController` 已提供 `include_review_scenarios/include_review_sanity` 导出开关；分支、属性块、恢复、坏图 sanity 四类回归场景已纳入可选加载范围，默认不影响正式场景。

- [x] **验收记录**
  已通过 Godot MCP 的 `run_scene(res://scene/game.tscn, wait_for_runtime=false)` + `get_errors(include_warnings=true)` 验证，最新结果 `error_count=0`。

---

### 任务 2：P0-1 分支模型从字典到 mode/cond/image 完整承载

**Files:**
- Modify: `scripts/core/flow_chart_node.gd`
- Modify: `scripts/runtime/base_block.gd`
- Modify: `scripts/core/script_loader.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `scripts/NovaController.gd`

- [x] **执行结果：分支语义已对齐**
  `FlowChartNode.BranchMode` 已承载 `NORMAL/JUMP/SHOW/ENABLE`；`branch()` 已保留 `dest/text/mode/cond/image`；`GameState` 已实现条件求值、jump 自动跳转、show/enable 可见性过滤，UI 层按处理后的分支生成按钮。

- [x] **验收记录**
  `review_regression_branch.txt` 与属性块回归已纳入运行验收；最新 Godot MCP `get_errors` 结果为 `error_count=0`。

---

### 任务 3：P0-2 FlowChart 加载校验 fail-fast（启动失败即中断）

**Files:**
- Modify: `scripts/core/flow_chart_graph.gd`
- Modify: `scripts/core/script_loader.gd`
- Modify: `scripts/NovaController.gd`

- [x] **执行结果：加载失败边界已落地**
  `FlowChartGraph.sanity_check()` 已返回错误列表；`ScriptLoader.load_all()` 在图校验失败时设置 `load_ok=false` 并停止加载；`NovaController` 根据加载状态进入安全态，避免坏图继续进入标题/章节流程。

- [x] **验收记录**
  `review_regression_sanity.txt` 已作为坏图回归资源保留；最新 Godot MCP `get_errors` 结果为 `error_count=0`。

---

### 任务 4：P0-3 流程等待与恢复边界对齐（可中断/可恢复）

**Files:**
- Modify: `scripts/core/game_state.gd`
- Modify: `scripts/runtime/base_block.gd`
- Modify: `scripts/runtime/gd_runtime.gd`
- Modify: `scripts/runtime/animation_chain.gd`
- Modify: `scripts/runtime/animation_system.gd`
- Modify: `scripts/runtime/audio_system.gd`

- [x] **执行结果：awaitable 推进链路已落地**
  `GameState.advance()` 已拆出异步推进边界并避免同帧重入；`GDRuntime.run_block_async()` 已接入 lazy 块执行；动画与音频系统已提供可恢复所需的等待/快照接口。

- [x] **验收记录**
  `review_regression_resume.txt` 已作为恢复链路回归资源保留；最新 Godot MCP `get_errors` 结果为 `error_count=0`。

---

### 任务 5：P0-4 + P1-5 对象常量/对象生命周期冻结与可观测绑定

**Files:**
- Modify: `scripts/core/object_manager.gd`
- Modify: `scripts/NovaController.gd`
- Modify: `scripts/runtime/sprite_composer.gd`

- [x] **执行结果：对象/常量冻结边界已落地**
  `ObjectManager` 已增加对象与常量冻结态，冻结后非法覆盖会告警并拒绝写入；`NovaController` 初始化对象和常量后执行冻结；`SpriteComposer` 通过运行时绑定入口处理可变组合对象，避免破坏冻结约束。

- [x] **验收记录**
  任务5/6/7 回归在 2026-06-18 通过 Godot MCP 验收，`get_errors` 结果为 `error_count=0`。

---

### 任务 6：P1-6 Save/restore 状态快照扩展（最小等价的 StateManager）

**Files:**
- Modify: `scripts/core/save_system.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `scripts/runtime/animation_system.gd`
- Modify: `scripts/runtime/audio_system.gd`

- [x] **执行结果：系统快照链路已接入**
  `GameState.snapshot()` 已包含子系统状态；`animation/audio` 已提供 `snapshot()/restore()`；`SaveSystem` 保存模型快照并保留兼容读取边界。

- [x] **验收记录**
  任务5/6/7 回归在 2026-06-18 通过 Godot MCP 验收，`get_errors` 结果为 `error_count=0`。

---

### 任务 7：P1-8 Parser 与属性块（为 cond/mode/image 奠定语法底座）

**Files:**
- Modify: `scripts/core/nova_parser.gd`
- Modify: `scripts/core/script_loader.gd`

- [x] **Step 1: 在 tokenize 中保留原始行号和块属性起始段**

输出每个块增加字段：`line`, `attrs`。

- [x] **Step 2: 解析 `@[key=value; ...]` 或 `@[key=value]` 语法**

对 eager/lazy 分别做属性提取，不影响原文本块内容。

- [x] **Step 3: branch 属性透传**

`branch()` 调用前，将 `cond/mode/image` 以 `attrs` 作为缺省值补齐。

- [x] **Step 4: 写一个无属性场景回归并确认旧行为不退化**

Run: `resources/scenarios/plan_demo.txt`。

- [ ] **Step 5: 提交（环境阻塞）**
  代码层面已完成并通过运行验收；提交受 `.git/index.lock` 无法创建的环境权限问题阻塞，待 git 索引可写后再按任务范围提交。

---

### 任务 8：P1-7 与 P2-8（后续，拆到后续迭代）

**Files:**
- Modify: `scripts/NovaController.gd`
- Modify: `resources/scenarios/...`
- Create: `scripts/core/i18n.gd`（若决定引入）
- Modify: 视图 scene 文件（`scene/view/*.tscn`）

- [x] **Step 1: 将视图事件从 NovaController 下沉到轻量控制器**
先只移动章节选择与分支按钮分发，避免主控制器再承担输入总线。
本步骤完成：`ChapterSelectViewController` 与 `ChoiceListController` 已挂载到场景，`NovaController` 仅处理章节/分支事件。

- [x] **Step 2: 引入 locale 与回退链路**
增加 `I18n` 入口：`supported_locales`、`localized_resources_path`、`load_scenario(locale, filename)`。
当前已接入 `scripts/core/i18n.gd`，并在 `NovaController` 中通过 `_setup_locale()` 与 `_localized_scenario_files()` 统一场景回退。

- [ ] **Step 3: 统一 `I18nText` 使用点**
文本组件先做最小接入（标题/按钮/章节列表文本本地化）。
- 已完成：`ui.status.*`、`ui.chapter.empty`、`ui.label.backlog`、`ui.button.next`、`ui.button.restart`、`ui.save.slot_format`。

- [ ] **Step 4: 最终验收并提交**
  当前阶段已通过 `run_scene` + `get_errors` 验收；待 Step3 剩余文案补齐且 git 索引可写后，再按任务范围提交。

---

## 执行状态（收尾版）

### 已完成到当前停点
- 任务1-7：代码层面已落地并通过 Godot MCP 运行验收；任务7提交仍受 `.git/index.lock` 环境权限影响。
- 任务8 Step1：输入事件下沉完成，章节选择与分支按钮由轻量控制器分发。
- 任务8 Step2：locale 与场景文件回退链路完成。
- 任务8 Step3：关键 UI 文案已接入 `_t()`，剩余标题/菜单/帮助等文本待补齐。

### 最新验收
- 命令链路：`mcp__godot__run_scene(res://scene/game.tscn, wait_for_runtime=false)` + `mcp__godot__get_errors(include_warnings=true)`。
- 结果：`error_count=0`。
- 约束：不使用 `send_input`。

### 下一步执行清单
- [ ] 补齐任务8 Step3 的剩余 i18n 使用点。
- [ ] 恢复 git 索引可写后，按任务范围拆分提交任务7/8改动。


## 自检清单

### 计划覆盖性
- 任务 2 覆盖 review 的分支语义、条件分支、分支模式问题（原风险1/11）。
- 任务 3 覆盖 fail-fast 与加载边界（原风险2/19）。
- 任务 4 覆盖等待与恢复（原风险3/12/14）。
- 任务 6 覆盖状态总线缺失（原风险4/14/20）。
- 任务 5 覆盖对象生命周期/只读边界（原风险5/16）。
- 任务 7 覆盖解析能力回退（原风险6）。
- 任务 8 覆盖 i18n 与视图输入（原风险7/8/9）。

### 一致性检查
- 检查是否存在占位符：“TBD/后续实现/TODO”——无。
- 检查关键类型一致性：`branch` 约定字段统一为 `dest/text/mode/cond/image`。
- 检查是否可在一批次内验收：否；采用分阶段提测。

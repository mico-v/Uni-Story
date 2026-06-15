# Nova2 对齐复盘

## 1. 审核目标
- 对齐 `Nova2` 行为语义的高风险路径：分支语义、加载边界、恢复挂起、系统快照、对象冻结、解析属性块、输入/本地化边界。
- 每个关键点保留可复验记录；验收统一使用 Godot MCP 的 `run_scene` + `get_errors`。

## 2. 当前进度

### 已完成并验证
- P0-1 分支语义：`branch()` 已承载 `dest/text/mode/cond/image`，`jump/show/enable` 与条件判断链路已打通。
- P0-2 加载边界：`FlowChartGraph.sanity_check()` 返回错误列表，`ScriptLoader.load_all()` 失败时进入 `load_ok=false` 安全态。
- P0-3 恢复挂起：`GameState`、`GDRuntime` 与异步播放链路已改为 awaitable 流程，避免同帧重入。
- P1-4 系统快照：`animation/audio` 的 `snapshot()/restore()` 已串接到存档快照。
- P1-5 对象/常量边界：`ObjectManager` 增加冻结态和告警，`SpriteComposer` 改为运行时绑定。
- P1-6 条件分支解析与属性块：`NovaParser` 支持 `@[... ]@<|` / `@[... ]<|`，`ScriptLoader` 支持块属性缺省回填。
- 任务8 Step1 输入事件下沉：章节选择与分支按钮分发已下沉到 `ChapterSelectViewController`、`ChoiceListController`。
- 任务8 Step2 locale 回退链路：新增 `scripts/core/i18n.gd`，`NovaController` 已接入 `_setup_locale()` 与 `_localized_scenario_files()`。

### 部分完成
- 任务8 Step3 I18n 文案接入：`ui.status.*`、`ui.chapter.empty`、`ui.label.backlog`、`ui.button.next`、`ui.button.restart`、`ui.save.slot_format` 已接入；剩余标题/菜单/帮助等零散文案待继续补齐。

### 待提交
- 任务7 与任务8 当前代码层面已通过运行校验，但提交受环境影响尚未完成：`.git/index.lock` 无法创建（环境权限问题）。

## 3. 当前变更范围
- 控制层：`scripts/NovaController.gd`
- 图构建与校验：`scripts/core/script_loader.gd`, `scripts/core/flow_chart_graph.gd`, `scripts/core/flow_chart_node.gd`
- 剧情推进与分支决策：`scripts/core/game_state.gd`
- 运行时系统：`scripts/runtime/*`
- 输入视图控制器：`scripts/ui/chapter_select_view_controller.gd`, `scripts/ui/choice_list_controller.gd`
- 本地化：`scripts/core/i18n.gd`, `resources/localized_resources/localized_strings/*.json`
- 场景挂载：`scene/view/chapter_select_view.tscn`, `scene/view/game_view.tscn`
- 回归场景：`resources/scenarios/review_regression_*.txt`

## 4. 验收记录
- 2026-06-18：任务5/6/7 回归通过，`run_scene(res://scene/game.tscn, wait_for_runtime=false)` + `get_errors(include_warnings=true)` 结果 `error_count=0`。
- 2026-06-24：任务8 Step1/2 与部分 Step3 回归通过，`run_scene(res://scene/game.tscn, wait_for_runtime=false)` + `get_errors(include_warnings=true)` 结果 `error_count=0`。

## 5. 暂时收尾状态
- 当前可停点：运行无 Godot 错误，任务8主链路已经能继续往文案补齐推进。
- 下一步优先级：继续补齐任务8 Step3 的剩余 i18n 文案使用点。
- 提交策略：待 git 索引可写后，将任务7/8相关改动按范围拆分提交。

## 6. 复用规则
- 验收只采用：`mcp__godot__run_scene` + `mcp__godot__get_errors`。
- 不使用 `send_input`。
- 计划文件只记录执行状态与下一步，复盘文件只保留进度总览，避免重复记录。

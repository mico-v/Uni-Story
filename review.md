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
- 任务8 Step3 I18n 文案补齐：所有可见 UI 文本已通过 `_t()` 接入本地化；修复 `title.subtitle`、`title.first.selectchapter`、`ingame.log.button` 三个 JSON 翻译值与实际 UI 的不匹配；场景文件硬编码文案已对齐 i18n 值。
- 任务8 Step4 最终验收：`run_scene` + `get_errors` + 截图确认标题界面与游戏界面文案正确。
- VFX/Shader 系统：新增 `VFXSystem` 子系统、6 个 `.gdshader` 文件（blur/grayscale/dissolve/chromatic_aberration/vignette/wipe）；`BaseBlock` 新增 `vfx()`/`clear_vfx()`/`post_fx()`/`clear_post_fx()`/`shake()` API；`TransitionSystem` 扩展支持 dissolve/wipe shader 转场；`game_view.tscn` 新增 PostFXRect 全屏后处理节点；自检剧本 `test_vfx.txt` 已创建并纳入 SCENARIO_FILES。
- 自动播放与快进模式：新增 `ReadTracker` 子系统（持久化已读记录至 `user://read_tracker.json`）；`GameState` 在 `dialogue_changed` 前调用 `mark_read()`；`NovaController` 新增 Auto（打字机结束后定时推进）和 Skip（跳过已读文本、遇到未读自动停止）两种模式，互斥切换；`game_view.tscn` 新增 Auto/Skip 按钮；`SaveSystem` 集成 read_tracker snapshot/restore；所有暂停条件（分支、章节结束、打开面板）均调用 `_deactivate_modes()`。

### 待提交
- 任务7 与任务8 当前代码层面已通过运行校验，但提交受环境影响尚未完成：`.git/index.lock` 无法创建（环境权限问题）。

## 3. 当前变更范围
- 控制层：`scripts/NovaController.gd`（瘦身为协调器）
- 视图管理：`scripts/core/view_manager.gd`
- 图构建与校验：`scripts/core/script_loader.gd`, `scripts/core/flow_chart_graph.gd`, `scripts/core/flow_chart_node.gd`
- 剧情推进与分支决策：`scripts/core/game_state.gd`
- 已读追踪与存档：`scripts/core/read_tracker.gd`, `scripts/core/save_system.gd`
- 运行时系统：`scripts/runtime/*`（含 `transition_system.gd` fade 修复、`prefab_loader.gd` 新增）
- 视图控制器：`scripts/ui/title_view_controller.gd`, `scripts/ui/game_view_controller.gd`（含 `on_game_ended()`/`reset_world()` overlay 重置）, `scripts/ui/settings_view_controller.gd`, `scripts/ui/cg_gallery_controller.gd`, `scripts/ui/music_gallery_controller.gd`, `scripts/ui/chapter_select_view_controller.gd`, `scripts/ui/choice_list_controller.gd`, `scripts/ui/save_load_controller.gd`
- 本地化：`scripts/core/i18n.gd`, `resources/localized_resources/localized_strings/*.json`
- VFX/Shader：`scripts/runtime/vfx_system.gd`, `resources/shaders/*.gdshader`
- 场景：`scene/game.tscn`, `scene/view/title_view.tscn`, `scene/view/chapter_select_view.tscn`, `scene/view/game_view.tscn`, `scene/view/settings_view.tscn`, `scene/view/cg_gallery_view.tscn`, `scene/view/music_gallery_view.tscn`, `scene/view/save_load_view.tscn`
- 剧本：`resources/scenarios/test_all.txt`（合并 5 个测试脚本）, `resources/scenarios/plan_demo.txt`（增强演示）
- 回归场景：`resources/scenarios/review_regression_*.txt`

## 4. 验收记录
- 2026-06-16：任务5/6/7 回归通过，`run_scene(res://scene/game.tscn, wait_for_runtime=false)` + `get_errors(include_warnings=true)` 结果 `error_count=0`。
- 2026-06-16：任务8 Step1/2 与部分 Step3 回归通过，`run_scene(res://scene/game.tscn, wait_for_runtime=false)` + `get_errors(include_warnings=true)` 结果 `error_count=0`。
- 2026-06-16：任务8 Step3/4 完成，i18n 文案全部补齐并通过回归；截图确认标题界面 "Nova 2" + "开始游戏" 正确显示，`get_errors` 结果 `error_count=0`。
- 2026-06-16：VFX/Shader 系统完成，`run_scene(res://scene/game.tscn)` + `get_errors(include_warnings=true)` 结果 `error_count=0`；截图确认标题界面正常。
- 2026-06-16：自动播放与快进模式完成，`run_scene(res://scene/game.tscn)` + `get_errors(include_warnings=true)` 结果 `error_count=0`；ReadTracker 持久化、Auto/Skip 互斥、存读档集成均已就绪。
- 2026-06-16：ViewManager + GALGAME 菜单重构完成。新增 `ViewManager` 子系统（fade/slide/instant 过渡动画），`TitleViewController`（GALGAME 左侧列表菜单），`GameViewController`（从 NovaController 提取全部游戏逻辑），`SettingsViewController`（文字速度/音量/全屏/语言/字体大小），`CgGalleryController`（缩略图网格+全屏预览），`MusicGalleryController`（曲目列表+播放控制）。NovaController 从 760 行瘦身为 240 行协调器。`run_scene(res://scene/game.tscn)` + `get_errors(include_warnings=true)` 结果 `error_count=0`。
- 2026-06-18：独立存读档界面完成。新增 `SaveLoadController`（89 行）+ `SaveLoadView.tscn`，GALGAME 侧栏风格，主菜单"读取存档"直接进入。NovaController 新增 `_on_title_load()` / `_on_save_load_completed()` 桥接。`run_scene(res://scene/game.tscn)` + `get_errors(include_warnings=true)` 结果 `error_count=0`。
- 2026-06-18：测试剧本整合 + 演示增强。5 个独立测试脚本合并为 `test_all.txt`（6 项分支菜单），`plan_demo.txt` 增强为 5 章结构含说话人标签和 fade 转场。`run_scene` + `get_errors` 结果 `error_count=0`。
- 2026-06-18：`is_end()` 黑屏修复。`TransitionSystem.play("fade")` 改为完整淡出+淡入（Tween 链式 0→1→0），`flash` 改为顺序 Tween 避免并发冲突。`GameViewController.on_game_ended()` 和 `reset_world()` 新增 overlay 重置（visible=false, color.a=0）。`run_scene(res://scene/game.tscn)` + `get_errors` 结果 `error_count=0`。
- 2026-06-18：PrefabLoader 子系统完成。新增 `prefab_loader.gd`（幂等加载 .tscn 预制体，注册到 ObjectManager，世界/UI 双挂载，snapshot/restore 支持）。修改 `object_manager.gd`（加 `unbind_object_runtime`）、`NovaController.gd`（注册子系统）、`base_block.gd`（4 个 API：`load_prefab/show_prefab/hide_prefab/destroy_prefab`）、`game_state.gd`（snapshot/restore 集成）、`game_view_controller.gd`（reset_world 清理 + get_hud getter）。新建 `resources/prefabs/test_particles.tscn` 测试预制体。`test_all.txt` 新增 Section 6 Prefab 测试章节。`run_scene(res://scene/game.tscn)` + `get_errors` 结果 `error_count=0`。
- 2026-06-18：脚本热加载完成。新增 `scripts/core/hot_reload.gd`（轮询 `FileAccess.get_modified_time()` 检测文件变化，debounce 防误触，自动重新解析剧本并返回标题页）。修改 `gd_runtime.gd`（加 `clear_cache()` 清空编译缓存）。`NovaController.gd` 注册第 21 个子系统并在 `_ready()` 末尾启动监听。仅 `OS.is_debug_build()` 时启用。控制台输出 `[HotReload] watching N scenario files`。`run_scene(res://scene/game.tscn)` + `get_errors` 结果 `error_count=0`。
- 2026-06-18：快捷键系统完成。新增 `scripts/core/shortcut_manager.gd`（可定制键盘快捷键，ConfigFile 持久化到 `user://config/keybinds.cfg`，remap/reset_all API 供未来设置 UI 使用）。`project.godot` 新增 `[input]` 段定义 14 个默认键位。`GameViewController` 新增 `_unhandled_input()` 处理游戏内快捷键（Space 推进、A 自动、S 快进、F5/F7 存读档、F6/F8 快速存取、L 回顾、H 隐藏对话框、F11 全屏、Esc 返回标题、F5 调试重载、U 解锁章节）。`NovaController` 新增 `_unhandled_input()` 处理非游戏视图导航（Esc 从设置/鉴赏/读档返回标题、Space 在标题开始游戏）。面板打开时屏蔽非关键快捷键。`run_scene(res://scene/game.tscn)` + `get_errors` 结果 `error_count=0`。
- 2026-06-18：TimelineController 完成。新增 `scripts/runtime/timeline.gd`（轨道式调度器，`at(time, callable)` 精确时间偏移编排，支持 `show_at/hide_at/cam_at/trans_at/se_at` 便捷方法，`play()` 启动所有轨道并行执行，`await_finished()` 可等待完成）。`base_block.gd` 新增 `timeline()` 工厂方法。`gd_runtime.gd` 新增 `Timeline` 异步检测（自动 await 直到所有轨道完成）。NovaScript 用法：`var tl = timeline(); tl.at(0.0, func(): show(...)).at(0.5, func(): cam(...)).play()`。`run_scene(res://scene/game.tscn)` + `get_errors` 结果 `error_count=0`。

## 5. 暂时收尾状态
- 当前可停点：ViewManager + GALGAME 菜单 + 设置/鉴赏/独立存读档界面 + NovaController 重构 + is_end() 黑屏修复 + PrefabLoader + 脚本热加载 + 快捷键系统全部完成，运行无 Godot 错误。
- 下一步优先级：TimelineController / 视频、预加载系统 / 鼠标菜单。
- 提交策略：待 git 索引可写后，按范围拆分提交。

## 6. 复用规则
- 验收只采用：`mcp__godot__run_scene` + `mcp__godot__get_errors`。
- 不使用 `send_input`。
- 计划文件只记录执行状态与下一步，复盘文件只保留进度总览，避免重复记录。

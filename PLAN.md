# Uni-Story 成熟化开发计划

> 当前目标：使用 Godot 4.6 + GDScript，学习 Nova 的架构设计，逐步建设成熟、可维护、可扩展的视觉小说游戏引擎。  
> 参考工程：`Nova/` Unity + C# + Lua(ToLua#)  
> 当前工程：Godot + GDScript-first，不引入 Unity/C# 依赖，不把 Lua VM 作为默认运行时。  
> 计划日期：2026-06-24

---

## 一、项目定位

Uni-Story 的目标不是简单复刻 Nova 的 Unity 实现，而是在 Godot/GDScript 生态中吸收 Nova 的成熟架构：

- 学习 Nova 的流程图、检查点存档、回跳、章节解锁、资源预加载、动画分组、UI 视图管理和工具链设计。
- 保持 Godot 原生开发体验：GDScript、`.tscn` 场景、`Resource`、`ConfigFile`、`ResourceLoader`、Godot export pipeline。
- 建立可做真实作品的视觉小说引擎，而不是只跑 demo 的运行时原型。
- 文档与进度同步：`PLAN.md` 写路线和验收标准，`review.md` 写对比审查、阶段复盘和风险记录。

架构方向：

| 层级 | 目标职责 | Godot 实现方向 |
|------|----------|----------------|
| 组合根 | 统一装配子系统、场景、配置 | `NovaController.gd` 作为 Composition Root，逐步减少弱类型 `_ctx` 访问 |
| 脚本前端 | 解析 NovaScript 风格剧本 | 保持 GDScript runtime，补 NovaScript 兼容语义 |
| 流程核心 | 节点、分支、章节、结局、回跳 | `FlowChartGraph` + `GameState` + 新 `CheckpointManager` |
| 表现运行时 | 图像、立绘、动画、音频、镜头、VFX、视频、Prefab | 现有 runtime 子系统扩展为可存档、可暂停、可恢复 |
| UI 产品层 | 标题、章节、游戏、设置、存读档、回顾、鉴赏、帮助、通知、输入映射 | `.tscn` 场景 + 控制器，避免大型动态 UI 堆代码 |
| 工具链 | 剧本 lint、分支可视化、资源扫描、立绘工具、shader 生成、导出测试 | Godot/ Python 工具并行，优先自动化剧本与资源检查 |

---

## 二、当前基线

当前项目已经具备一套可运行的 GDScript 视觉小说框架：

- NovaScript 风格 eager/lazy/text 块解析。
- GDScript 动态编译运行时 `GDRuntime`。
- 流程图、分支、跳转、条件分支、命名结局。
- 变量、I18n、ReadTracker、Backlog、HotReload、PreloadSystem。
- 图片、立绘合成、头像、音频、镜头、动画链、转场、VFX、Prefab、视频、Timeline。
- 标题、游戏、设置、独立存读档、CG 鉴赏、音乐鉴赏、Toast/Confirm、右键菜单。
- JSON 存档、自动存档、动态 CG/BGM 解锁。
- Godot export presets 和 GitHub Actions 发布基础。

主要短板：

- 存档/回跳仍是 snapshot + replay 的简化模型，缺 Nova 的 checkpoint/node record/reached data/bookmark 体系。
- NovaScript 只是“风格相似”，尚未完整兼容 Nova 的 Lua 语义。
- UI 缺章节选择、Help、Notification、完整 Alert、输入映射、存档截图。
- 动画、VFX、预加载、工具链距离 Nova 成熟度还有明显差距。
- 子系统通过 `_ctx: Node` 互相访问，类型边界和职责边界需要继续收敛。

---

## 三、核心原则

1. **GDScript-first**：脚本块继续编译为 GDScript；兼容 NovaScript 时优先做语义映射和转换层，而不是默认嵌 Lua。
2. **存档能力优先于表现堆叠**：成熟 VN 引擎的核心是可回跳、可恢复、可升级，不是只增加更多演出 API。
3. **场景与控制器分离**：UI 结构进 `.tscn`，逻辑进 `scripts/ui/*`，避免大型控制器继续膨胀。
4. **可验证推进**：每个阶段必须有验收剧本、自动检查或明确手动测试清单。
5. **兼容与原生平衡**：Nova 作为设计目标，Godot 作为实现约束；遇到冲突时优先保留 Godot 可维护性。
6. **文档同步**：完成阶段后更新 `PLAN.md` 的状态，并把审查结论、偏差和风险写入 `review.md`。

---

## 四、阶段路线图

### Phase 0：计划锁定与基线整理

目标：把工程方向从“功能补丁列表”调整为“GDScript 成熟引擎路线图”。

任务：

- [x] 对比 `Nova/` 与当前工程，形成 `review.md` 差异报告。
- [x] 重写 `PLAN.md`，确立 GDScript-first 的成熟化路线。
- [ ] 为每个后续 Phase 建立 issue/commit 粒度清单。
- [ ] 统一术语：node、entry、checkpoint、bookmark、reached、chapter、branch mode、runtime stage。

验收：

- `PLAN.md` 能指导后续逐步开发。
- `review.md` 能解释为什么优先做 checkpoint、脚本兼容和工具链。

### Phase 1：架构边界与工程骨架

目标：先让现有 GDScript 架构更像一个可扩展引擎，而不是 demo 控制器集合。

任务：

- [x] 新增 headless 剧本解析 smoke test：`scripts/tests/parse_scenarios_test.gd`。
- [x] 新增 headless GameState 推进 smoke test：`scripts/tests/game_state_smoke_test.gd`，覆盖对白、lazy block、变量跳转、条件分支和命名结局。
- [x] 新增主场景生命周期 smoke test：`scripts/tests/main_scene_smoke_test.gd`，显式加载、校验并释放 `scene/game.tscn`。
- [x] 新增 `EngineContext` typed facade 草案，作为后续减少 `_ctx` 弱类型访问的入口。
- [x] 新增 `RestorableRegistry`，定义 `snapshot()` / `restore(data)` 的 duck-typed checkpoint 约定。
- [x] 抽出 `GalleryCoordinator`，把 CG/BGM 鉴赏配置、自动解锁和视图刷新从 `NovaController.gd` 下沉。
- [x] 新增代码优先使用 `EngineContext`：`GalleryCoordinator` 通过 typed facade 访问 `AudioSystem` 与 `ReadTracker`。
- [x] 新增 headless SaveSystem smoke test：`scripts/tests/save_system_smoke_test.gd`，覆盖可配置槽位、禁用自动存档、`RestorableRegistry` 快照与恢复。
- [x] 给核心子系统补 `class_name`、明确类型、返回值和错误策略。
- [x] 设计 `EngineContext` typed facade，减少新增代码的 `_ctx.xxx` 弱类型访问。
- [x] 把可配置路径、槽位数量、预加载容量、自动存档策略迁移为 `@export` 配置并传入子系统。
- [x] 梳理 `NovaController.gd`：保留装配、导航、全局信号路由；Gallery/Settings 业务逻辑下沉到 coordinator/service。
- [x] 建立统一日志/错误分级：parse error、runtime warning、save corruption、asset missing。
- [x] 扩展最小测试入口：跑一段无 UI 的 GameState。

验收：

- Godot 打开主场景无脚本错误。
- 能用命令或工具脚本解析所有 `resources/scenarios/*.txt`。
- 能在 headless 下推进最小 GameState 剧本并覆盖分支/结局。
- 能在 headless 下保存/读取最小状态，并通过 `RestorableRegistry` 恢复扩展子系统。
- 能在 headless 下加载并释放主场景，不留下 UID 或 ObjectDB/CanvasItem 泄漏警告。
- `NovaController.gd` 的职责说明写清楚，新增逻辑优先进入子系统。

### Phase 2：NovaScript 兼容基线

目标：在 GDScript runtime 上补 NovaScript 常用语义，让目标 Nova 剧本可以逐步迁移。

任务：

- [ ] 支持 `l_` 局部 label：按文件名生成稳定命名空间。
- [ ] 支持 `is_save_point()`，并先接入普通 checkpoint 标记。
- [ ] 支持 `is_debug()`、locked/unlocked/debug start 的完整分类。
- [ ] 支持 block attribute：如 `[stage = before_checkpoint]`、branch 默认属性。
- [ ] 支持 lazy block stage：default、before_checkpoint、after_dialogue。
- [ ] 支持文本插值：`{{var_name}}` 映射到变量系统。
- [ ] 支持 `v_` / `gv_` 变量兼容层：局部变量进入当前存档，全局变量进入 global save。
- [ ] 支持 Nova branch image tuple：`image = {"name", {x, y, scale}}` 映射为 Godot 可渲染数据。
- [ ] 支持条件表达式兼容：字符串条件继续编译为 GDScript；函数式条件先定义兼容限制。
- [ ] 迁移 Nova 测试剧本最小集：`test_branch.txt`、`test_variables.txt`、`test_empty_node.txt`。

验收：

- 以上三个迁移测试剧本可以被解析并完成基本播放。
- 兼容语法和不兼容语法在 `docs/NovaScript.md` 中明确列出。
- 解析错误能定位到文件、行号和块类型。

### Phase 3：Checkpoint / Bookmark 存档核心

目标：迁移 Nova 最关键的成熟能力：任意已读对白回跳、稳定恢复、全局进度和存档升级基础。

任务：

- [ ] 新增 `CheckpointManager.gd`，管理 node record、checkpoint、reached dialogue、reached end。
- [ ] 设计 `NodeRecord` 数据结构：name、parent、child/sibling 或等价历史关系、begin/end dialogue、variables hash。
- [ ] 设计 `GameStateCheckpoint`：当前 entry、变量快照、各 restorable 子系统状态、checkpoint restraint。
- [ ] 把 `SaveSystem` 拆分为 bookmark slot 管理；底层恢复交给 `CheckpointManager`。
- [ ] 保存 reached dialogue，用于回顾、已读、章节解锁、skip unread。
- [ ] 实现 bookmark metadata：创建时间、章节名、对白索引、截图路径、global save id。
- [ ] 实现存档截图：在游戏视图生成 thumbnail，存入 user data。
- [ ] 实现从最近 checkpoint restore + replay 到目标 entry。
- [ ] 为脚本升级预留 node text hash 和 save version 字段。

验收：

- 从回顾点击任意已读对白，可恢复到正确视觉状态。
- 手动存档/读档/自动存档都走 bookmark。
- 删除、覆盖、损坏存档都有明确 UI 提示。
- `test_all.txt` 增加回跳和读档自检段。

### Phase 4：章节选择、全局进度与标题体验

目标：补齐 Nova 标题层产品体验，让多章节作品能自然启动、继续、选择章节。

任务：

- [ ] 新建 `scene/view/chapter_select_view.tscn` 和 `ChapterSelectViewController.gd`。
- [ ] 按 start node 类型显示章节：normal、unlocked、debug。
- [ ] 用 reached dialogue 解锁章节。
- [ ] 标题菜单改为：开始/章节选择/继续/读取/设置/CG/音乐/帮助/退出。
- [ ] 新增 HelpView，承载项目说明、操作说明和首次提示。
- [ ] 新增首次提示策略：首次进入游戏、首次解锁章节、首次使用回顾跳转。
- [ ] 标题 BGM、UI 音效、视图切换音效接入 AudioSystem。

验收：

- 多 start node 剧本可进入章节选择。
- 只有一个 unlocked start 时可直接开始。
- Debug start 只在调试开关开启时显示。
- 标题、章节、游戏、设置、鉴赏之间导航无残留状态。

### Phase 5：ViewManager 与 UI 产品层成熟化

目标：让 UI 层达到可做作品的稳定度。

任务：

- [ ] `ViewManager` 增加状态：Title/UI/Game/InTransition/Alert。
- [ ] 切出 GameView 时暂停 per-dialogue/holding 动画和相关音频，切回时恢复。
- [ ] 增加 transition input blocker，防止过渡中重复点击。
- [ ] 新增 NotificationView 和 AlertView，Toast/Confirm 迁移到统一通知体系。
- [ ] 输入映射 UI：按键录制、恢复默认、冲突提示、保存到 ConfigFile。
- [ ] 存读档 UI 显示截图、章节名、时间、当前位置。
- [ ] 回顾 UI 支持语音重播、跳转确认、筛选未来文本。
- [ ] UI 主题资源拆分：默认主题、作品主题、调试主题。

验收：

- 游戏中打开/关闭所有 UI 不会破坏自动播放、快进、语音和动画状态。
- 所有弹窗可键盘/手柄/鼠标关闭。
- 存档列表可承载至少 100 个槽位而不卡顿或布局错乱。

### Phase 6：动画系统升级

目标：向 NovaAnimation 学习，形成 Godot 原生的动画编排系统。

任务：

- [ ] 区分动画域：per_dialogue、holding、ui、text。
- [ ] `AnimationChain` 支持 then/and 语义，而不是只靠链式 Tween。
- [ ] 支持 pause/resume/stop，ViewManager 可统一控制。
- [ ] 支持命名 holding animation group。
- [ ] 增加常用 property：position、scale、rotation、modulate、volume、shader float、dialogue text reveal。
- [ ] 增加 easing parser，兼容常见 Nova slope/easing 写法。
- [ ] Lazy block stage 与动画等待策略打通：是否阻塞对白推进可配置。

验收：

- Godot 版 `test_anim_hold.txt` 可覆盖 holding animation。
- 切到菜单再切回，holding animation 和 BGM 状态符合预期。
- 点击停止动画、快进、读档不会留下悬空 Tween。

### Phase 7：VFX / Shader / Transition 系统

目标：把当前固定几个 shader 的原型扩展为作品级效果系统。

任务：

- [ ] 建立 shader registry 资源文件，记录 effect name、shader path、默认参数、可动画参数。
- [ ] 支持对象 VFX、后处理 VFX、转场 VFX 三类。
- [ ] 支持多参数动画：float/color/vector/texture。
- [ ] 支持 shader layer 或等价 Godot material stack 策略。
- [ ] 支持 render target / screen capture，用于复杂转场。
- [ ] 迁移 Nova 常用效果子集：fade、wipe、blur、mono、glitch、shake、ripple、rain。
- [ ] 设计 Godot 版 shaderproto 或简化生成器，避免手写大量重复 shader。

验收：

- Godot 版 `test_transition.txt` 覆盖普通转场、shader 转场、对象 VFX、后处理。
- VFX 可存档恢复。
- 缺 shader 或参数错误时只报明确 warning，不崩溃。

### Phase 8：资源加载、预加载与内容生产工具

目标：让内容规模变大后仍能稳定开发。

任务：

- [ ] 静态扫描剧本，自动发现 show/audio/prefab/video/timeline/choice image 资源。
- [ ] `PreloadSystem` 支持优先级、取消、LRU、进度、资源类型。
- [ ] 缺失资源报告生成到 `review.md` 或独立 report。
- [ ] 迁移 Nova `Tools/Scenarios` 高价值工具：lint、show_branches、visualize、stat_dialogue_len、list_bg/list_bgm。
- [ ] 设计 Godot 版立绘导入约定：角色/图层/表情/口型/头像路径规则。
- [ ] 迁移或重写 PSD/图层/standing 工具链。
- [ ] 生成 localized resource path / charset 辅助文件。

验收：

- CI 能检查剧本引用资源是否存在。
- 能输出流程图或分支图。
- 能统计对白长度、角色台词量、使用过的背景/BGM/立绘。

### Phase 9：小游戏、中断与扩展接口

目标：支持 Nova 式“VN + gameplay”混合项目。

任务：

- [ ] 实现 interrupt/fence 协议：开始中断、等待外部信号、结束中断。
- [ ] `PrefabLoader` 扩展为 gameplay prefab manager，区分 UI prefab / world prefab / persistent prefab。
- [ ] 中断期间暂停自动/快进/点击推进。
- [ ] 小游戏结束后根据变量变化确保 checkpoint。
- [ ] 提供扩展脚本接口：自定义系统可注册为 restorable、preloadable、script API provider。
- [ ] 增加示例小游戏场景和测试剧本。

验收：

- Godot 版 `test_minigame.txt` 可以跑通。
- 小游戏中保存/读档/回跳有明确策略，不出现半恢复状态。
- 外部系统注册错误能被检测出来。

### Phase 10：平台、质量与发布

目标：形成可发布、可维护、可回归测试的引擎工程。

任务：

- [ ] Headless 测试：parser、flow graph、save/restore、checkpoint replay、resource scan。
- [ ] 场景 smoke test：主场景加载、标题导航、开始游戏、存读档、设置、鉴赏。
- [ ] 导出 smoke test：Windows/Linux/Android 产物基础检查。
- [ ] 性能基线：脚本解析耗时、资源预加载耗时、存档耗时、回跳耗时。
- [ ] 错误恢复：损坏存档、缺资源、脚本语法错误、循环图、未知跳转。
- [ ] 文档整理：快速开始、NovaScript 兼容表、资源规范、扩展系统、发布流程。
- [ ] 示例作品完善：至少一个 3 章节、含分支/结局/CG/BGM/回跳/小游戏的样例。

验收：

- 每次合并前能跑最小自动验证。
- Release 包可以给非开发者运行。
- README/SETUP/docs 能支持新作者建立第一个 VN 项目。

---

## 五、近期执行顺序

第一轮不要同时开太多战线，按下面顺序推进：

1. Phase 1：架构边界与测试入口。
2. Phase 2：NovaScript 兼容基线。
3. Phase 3：Checkpoint / Bookmark 存档核心。
4. Phase 4：章节选择与标题体验。
5. Phase 6：动画系统升级。
6. Phase 7：VFX / Shader / Transition 系统。
7. Phase 8：工具链和资源扫描。

建议每个 Phase 拆成 2-5 个小提交，每个提交都能运行主场景或对应测试脚本。

---

## 六、阶段状态表

| Phase | 名称 | 状态 | 优先级 |
|-------|------|------|--------|
| 0 | 计划锁定与基线整理 | 进行中 | P0 |
| 1 | 架构边界与工程骨架 | 完成 | P0 |
| 2 | NovaScript 兼容基线 | 待开始 | P0 |
| 3 | Checkpoint / Bookmark 存档核心 | 待开始 | P0 |
| 4 | 章节选择、全局进度与标题体验 | 待开始 | P0 |
| 5 | ViewManager 与 UI 产品层成熟化 | 待开始 | P1 |
| 6 | 动画系统升级 | 待开始 | P1 |
| 7 | VFX / Shader / Transition 系统 | 待开始 | P1 |
| 8 | 资源加载、预加载与内容生产工具 | 待开始 | P1 |
| 9 | 小游戏、中断与扩展接口 | 待开始 | P2 |
| 10 | 平台、质量与发布 | 待开始 | P2 |

---

## 七、文档同步规则

- `PLAN.md`：只记录路线、任务、状态、验收标准。
- `review.md`：记录 Nova 对比、阶段审查、风险和复盘。
- `docs/NovaScript.md`：记录脚本语法、兼容表和迁移说明。
- `README.md`：只放用户视角的快速开始和能力摘要。
- 每完成一个 Phase：更新状态表，补充验收结果，把实际偏差写入 `review.md`。

---

## 八、下一步具体任务

Phase 1 已完成。执行记录：

1. [x] 扩展 headless 测试：从“只解析流程图”推进到“无 UI 推进若干对白 entry”。
2. [x] 清理主场景 headless 退出时的 UID 与渲染资源泄漏警告，确认真实残留并修复。
3. [x] 梳理 `NovaController.gd` 目前职责，先拆出 gallery coordinator 作为业务下沉样板。
4. [x] 开始把新代码的上下文访问改用 `EngineContext`，旧系统暂不强迁移。
5. [x] 把 `RestorableRegistry` 接入 SaveSystem 的 restorable snapshot envelope，为下一版 Save/Checkpoint 设计预留接口。
6. [x] 拆出 settings coordinator，并将 save/preload/gallery/settings 配置和业务边界收敛到明确子系统。

下一步进入 Phase 2：NovaScript 兼容基线。优先从 `l_` 局部 label、`is_save_point()`、block attribute、文本插值、`v_` / `gv_` 变量兼容层开始。

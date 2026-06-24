# Nova 与 Uni-Story 差异评审

> 审查日期：2026-06-24  
> 目标工程：`Nova/`，Unity 2020.3.48f1 + C# + Lua(ToLua#)  
> 当前工程：仓库根目录，Godot 4.6 + GDScript  
> 结论范围：开发进度、运行时能力、架构差异、后续对齐优先级

---

## 一、总评

`Nova/` 是一个成熟的 Unity 视觉小说框架，包含完整示例工程、脚本解析、Lua 运行时、检查点式存档/回跳、章节选择、设置、鉴赏、输入映射、UI 预制体、shader 生成与素材处理工具链。

当前 Uni-Story 是 Godot 版重写工程，已经完成了核心视觉小说运行时原型，并补齐了很多常用演出 API：脚本解析、流程图、对话推进、分支、变量、基础存档、回顾、图片、立绘、头像、音频、镜头、转场、VFX、Prefab、视频、Timeline、设置、CG/音乐鉴赏、热重载等。

两者关系不是“同一代码库的进度差”，而是“目标框架能力向 Godot 的迁移差”。当前项目在核心运行时上已具备可跑 demo 的基础，但距离 Nova 的产品级框架还有明显差距，尤其是：

- Nova 的 checkpoint / node record / reached data / save upgrade 体系尚未迁移。
- NovaScript 兼容层还不完整，当前是 GDScript 风格 API，不是 Lua NovaScript 的行为等价实现。
- UI 产品层缺少章节选择、帮助页、通知系统、输入映射、存档截图、首次提示等 Nova 体验。
- 资源、shader、预加载、立绘裁剪、剧本检查与构建工具链差距较大。

按“能否承载 Nova 同类项目”的标准估算，当前进度大致为：

| 模块 | 当前完成度判断 | 说明 |
|------|----------------|------|
| 核心 VN 运行时 | 约 60%-70% | 可解析并播放 Godot 版脚本，基础演出 API 已覆盖较多 |
| NovaScript 行为兼容 | 约 35%-45% | 语法块概念相近，但 Lua 语义、局部 label、action stage、变量规则等未完整对齐 |
| 存档/回跳/升级体系 | 约 25%-35% | 有 JSON 存读档和 replay，但缺 Nova 最核心的 checkpoint 历史树 |
| UI 产品功能 | 约 45%-55% | 标题、游戏、设置、存读档、鉴赏已存在，章节/帮助/输入映射等缺失 |
| 资源与工具链 | 约 20%-30% | 当前资源较少，缺 Nova 的素材导入、shader 生成、剧本工具和构建工具 |
| 整体对齐 | 约 45%-55% | 已经是可继续推进的 Godot 框架骨架，但还不是 Nova 的完整替代品 |

---

## 二、工程规模与入口对比

| 项目项 | Nova 目标工程 | 当前 Uni-Story |
|--------|---------------|----------------|
| 引擎 | Unity 2020.3.48f1，URP | Godot 4.6 |
| 主场景 | `Nova/Assets/Scenes/Main.unity` | `scene/game.tscn` |
| 核心语言 | C# 组件 + Lua 剧本运行时 | GDScript 组件 + GDScript 剧本块运行时 |
| 运行时脚本 | `Nova/Assets/Nova/Lua/*.lua`，24 个核心 Lua 文件 | `scripts/runtime/*.gd` + `scripts/runtime/base_block.gd` |
| 核心 C#/GDScript | Nova `Core` + `Scripts` 约 233 个 C# 文件；全 Assets 约 307 个 C# 文件 | 当前 `scripts/` 下 46 个 `.gd` 文件 |
| UI 资产 | 大量 Unity prefab：Title、Game、Config、SaveLoad、Log、Choice、Alert、Gallery 等 | 14 个 Godot `.tscn` 场景 |
| 示例剧本 | 默认 28 个中文剧本 + 4 个英文本地化剧本 | 3 个示例/测试剧本 |
| 资源规模 | 背景、BGM、CG、Choices、Standings、Videos、Voices、Shaders、Prefabs 等完整示例资产 | 少量 demo 图片、音乐、立绘、shader、prefab |
| 构建/工具 | `Tools/Scenarios`、`Tools/Standings`、`Tools/Resources`、`Tools/Build` | GitHub Actions export presets + 少量 Godot 工具脚本 |

---

## 三、开发进度差异

### 3.1 已基本对齐的能力

| 能力 | Nova 目标 | 当前实现 | 差异 |
|------|-----------|----------|------|
| 剧本块模型 | eager block / lazy block / text chunk | `NovaParser` + `ScriptLoader` 支持 eager/lazy/text | 概念已对齐，但解析严谨度和 Lua 兼容不足 |
| 流程图 | `FlowChartGraph` / `FlowChartNode` / branch / jump / start / end | `FlowChartGraph` / `FlowChartNode` / branch / jump / start / end | 基础流程已对齐，缺 save point、局部 label 规则、章节解锁完整逻辑 |
| 对话推进 | `GameState.Step()` + dialogue events | `GameState.advance()` + signals | 基础推进可用，缺 Nova 历史树和精确回跳语义 |
| 分支 | normal / jump / show / enable | normal / jump / show / enable | 模式已覆盖，条件表达式语言不同 |
| 基础演出 API | show/hide/move/tint、音频、镜头、转场 | `BaseBlock` 暴露对应方法 | 常用 API 已覆盖，但参数兼容和资源解析规则不同 |
| 立绘/头像 | GameCharacterController、AvatarController | SpriteComposer、AvatarSystem | 基础功能可用，缺 Nova 的 standing asset/cropping 工具链 |
| 设置/鉴赏/存读档 UI | Config、ImageGallery、MusicGallery、SaveLoad | Settings、CG Gallery、Music Gallery、SaveLoad | 当前已有可用版本，但功能深度和 UI 交互不如 Nova |
| 热重载 | `GameState.ReloadScripts()` + upgrade | `HotReload` 文件轮询重载 | 当前是开发便利功能，未接入 save upgrade 体系 |

### 3.2 部分对齐但需要重构的能力

| 能力 | Nova 目标状态 | 当前状态 | 主要缺口 |
|------|---------------|----------|----------|
| 存档恢复 | `CheckpointManager` 保存 node record、checkpoint、reached data、bookmark、global save | `SaveSystem` 保存 JSON snapshot，`GameState.restore()` replay lazy block | 缺历史树、存档截图、全局进度、脚本升级、备份恢复、bookmark metadata |
| 回顾/回跳 | 基于 reached dialogue 与 checkpoint 精确回跳 | `Backlog` 保存文本，支持跳回指定 entry | 当前跳回直接展示目标行，未完整重建前置 checkpoint 历史 |
| 变量系统 | Lua 中 `v_` / `gv_` 自动映射局部/全局变量 | `Variables` 显式 `set_var/get_var/add_var` | 缺 Lua 风格自动变量、全局变量持久化、变量 hash 驱动的 node record 复用 |
| I18n | 同一节点维护多语言 display/dialogue/branch text，本地化资源路径 | UI JSON + 本地化剧本路径替换 | 缺按节点合并多语言 dialogue entries、localized branch text 校验 |
| 预加载 | Lua `add_preload_pattern` 自动分析剧本资源 | `PreloadSystem.preload_asset()` 手动 API | 缺自动预处理、资源类型识别、unpreload/need_preload 语义 |
| 动画 | `NovaAnimation` 支持 per-dialogue/holding/UI/text 四类、Then/And、pause/resume/stop/group | `AnimationChain` 基于 Godot Tween，链内顺序、跨语句并行 | 缺 holding animation、动画组、暂停恢复、丰富 property 类型和 easing 体系 |
| VFX/shader | 37 个 shaderproto 生成 176 个 shader，支持变体/PP/material pool/restorable material | 6 个 Godot shader + 固定 registry | 缺 shaderproto 生成链、变体层、MaterialPool、多参数动画、render target |
| View 管理 | `ViewManager` 追踪 UI/Game/InTransition/Alert，切 UI 时暂停游戏动画/音频 | `ViewManager` 字符串注册和切换淡入/滑动 | 缺视图状态枚举、切换输入阻挡、游戏动画/音频 pause/resume 策略 |
| 输入系统 | Unity Input System + 输入映射 UI + touch/pointer helper | Godot InputMap + `ShortcutManager` + 设置项 | 缺完整按键录制 UI、复合键、移动端输入分层 |

### 3.3 明显缺失的目标能力

| Nova 能力 | 目标位置 | 当前缺口 |
|-----------|----------|----------|
| 章节选择视图 | `ChapterSelectViewController.cs`、`ChapterSelectView.prefab` | 当前没有章节选择视图；标题页直接取第一个 start/unlocked start |
| Help / 新手提示 | `HelpViewController.cs`、`TitleController.ShowHints()` | 当前没有帮助页和首次提示流程 |
| Notification / Alert 完整系统 | `NotificationController.cs`、`AlertController.cs`、Alert prefab | 当前有 Toast/Confirm，但不是 Nova 的通知/警告体系 |
| 存档截图 | `ScreenCapturer.cs`、`Bookmark.screenshot` | 当前存档槽只有文本标签 |
| Script upgrade | `CheckpointUpgrader.cs`、`Differ.cs`、node text hash | 当前只有版本号校验，没有节点 diff 和旧存档升级 |
| before_checkpoint / after_dialogue stage | `[stage = before_checkpoint]`、`DialogueActionStage` | 当前 lazy block 只有单一执行阶段 |
| 中断/小游戏协议 | `minigame.lua`、`StartInterrupt/StopInterrupt`、fence | 当前只支持加载 prefab，没有中断恢复协议 |
| 输入映射界面 | `UI/InputMapping/*` | 当前设置界面有快捷键能力雏形，但没有完整输入录制界面 |
| 自动语音 | `AutoVoice.cs`、`auto_voice.lua` | 当前只有显式 `play_voice()` |
| 立绘裁剪/PSD 工具 | `Tools/Standings/*`、`SpriteCropping/*` | 当前没有对应工具链 |
| 剧本工具 | `Tools/Scenarios/lint.py`、`visualize.py`、`show_branches.py` 等 | 当前没有完整 NovaScript lint/可视化/统计工具 |
| shader 生成工具 | `Tools/Resources/generate_shaders.py` | 当前 shader 手写，数量少 |
| 构建工具 | `Tools/Build/build_all.py` | 当前有 Godot export presets 和 CI，但未形成 Nova 同等级发布脚本 |

---

## 四、架构差异

### 4.1 组合根与依赖方式

Nova 的 `NovaController.cs` 是 Unity prefab 里的组件聚合器，只负责查找 `GameState`、`DialogueState`、`CheckpointManager`、`ConfigManager`、`InputManager`、多组 `NovaAnimation` 等组件。业务能力分散在 MonoBehaviour、C# Core 类和 Lua 脚本之间。

当前 `scripts/NovaController.gd` 是 Godot 版的服务定位器和总协调器，直接创建 20 多个 `RefCounted` 子系统，并通过 `_ctx` 注入给所有系统访问。

差异判断：

- 当前架构更集中，启动路径清楚，适合快速重写。
- Nova 架构更贴近 Unity 的 prefab/inspector 组合方式，可视化配置和资产复用更成熟。
- 当前 `_ctx: Node` 弱类型访问会继续扩大耦合；若要长期维护，应逐步引入明确接口或专门 coordinator。

### 4.2 剧本运行时

Nova 的剧本块本质上是 Lua 代码，通过 `LuaRuntime`、`script_loader.lua`、`graphics.lua`、`animation.lua` 等脚本把 DSL 函数注入 Lua 环境。NovaScript 的许多行为来自 Lua 元表和 helper：

- `v_` / `gv_` 变量自动映射。
- `l_` 局部 label 自动加文件名前缀。
- `branch` 的 `cond` 可以是 Lua function 或字符串表达式。
- `__Nova` 暴露 C# 对象。
- `action_new_file`、`only_included_scenario_names`、`is_restoring()` 等运行时钩子。

当前把 `<|...|>` 和 `@<|...|>` 包装为 `extends BaseBlock` 的 GDScript，直接编译执行。这让 Godot 版实现简单、性能和调试路径也直观，但它不是 NovaScript 的语义兼容实现。

需要选择路线：

| 路线 | 优点 | 代价 |
|------|------|------|
| 保持 GDScript NovaScript 方言 | Godot 原生，维护简单 | 不能直接复用 Nova 既有剧本 |
| 做 Lua 兼容层 | 可迁移 Nova 剧本和工具 | 需要嵌 Lua 或实现 Lua 到 GDScript 转译 |
| 做语法兼容但语义映射到 GDScript | 不引入 Lua VM，兼容常用脚本 | 需要完整 parser/translator，边界复杂 |

如果 `Nova/` 是严格开发目标，建议至少实现“NovaScript 常用语义兼容层”，否则后续差异会越来越难收敛。

### 4.3 状态、存档与回跳

这是当前与 Nova 最大的架构差距。

Nova 的核心不是普通 slot 存档，而是 checkpoint 历史系统：

- `GameState` 维护 `NodeRecord` 历史树。
- `CheckpointManager` 持久化 checkpoint、reached dialogue、reached end、global save。
- 每隔若干对话或在关键点强制保存 checkpoint。
- 回跳时从最近 checkpoint restore，再向前 replay 到目标行。
- 剧本变化后通过 node hash、`Differ` 和 `CheckpointUpgrader` 尝试升级旧存档。
- bookmark 存储截图、创建时间、global save identifier。

当前 `SaveSystem` 是 JSON slot 存档：

- 保存 `GameState.snapshot()`、变量、部分子系统 snapshot。
- 读档时 `GameState.restore()` 从节点开头 replay lazy block 到目标 index。
- 回顾跳转目前直接定位并展示目标 entry，恢复精度低于 Nova。

当前实现适合小型 demo，但不足以支持 Nova 的“随时回跳到之前任意一句并保持状态一致”的核心卖点。后续必须把 `SaveSystem` 升级为 checkpoint / reached data / bookmark 三层模型。

### 4.4 UI 架构

Nova UI 是 prefab + controller 体系：

- `TitleController`
- `ChapterSelectViewController`
- `GameViewController`
- `ConfigViewController`
- `SaveViewController`
- `LogController`
- `ImageGalleryController`
- `MusicGalleryController`
- `HelpViewController`
- `AlertController`
- `NotificationController`
- `InputMappingController`

当前 UI 已有：

- TitleView
- GameView
- SettingsView
- SaveLoadView
- CgGalleryView
- MusicGalleryView
- Toast / Confirm / ContextMenu / Backlog / ChoiceList 等组件

主要差异：

- 缺章节选择和 start node 解锁逻辑。
- 缺帮助页、首次进入提示、通知列表。
- 缺完整输入映射 UI。
- 缺存档截图、更多 metadata、列表虚拟化。
- View 切换时没有像 Nova 那样统一暂停/恢复游戏动画、音频、语音。

### 4.5 资源与工具链

Nova 的目标工程包含大量非运行时代码：

- 剧本工具：lint、merge、visualize、show_branches、统计对白长度、列出 bg/bgm/pos。
- 立绘工具：PSD 图层导出、姿势排序、图层合成。
- 资源工具：shader 生成、本地化路径生成、charset 生成。
- 构建工具：多平台打包。

当前工程有 CI 和 Godot export presets，但还没有与 Nova 同级的内容生产工具。对于视觉小说框架来说，工具链不是外围功能，而是内容规模变大后的主要生产力来源。

---

## 五、文件级映射

| Nova 目标文件/目录 | 当前对应文件/目录 | 状态 |
|-------------------|-------------------|------|
| `Nova/Assets/Nova/Sources/Core/NovaController.cs` | `scripts/NovaController.gd` | 职责不同；当前更像总装配器 |
| `Core/GameState.cs` | `scripts/core/game_state.gd` | 基础推进已实现，缺 checkpoint 历史树 |
| `Core/Restoration/CheckpointManager.cs` | `scripts/core/save_system.gd`、`scripts/core/read_tracker.gd` | 主要缺口 |
| `Core/ScriptParsing/ScriptLoader.cs` | `scripts/core/script_loader.gd` | 部分对齐 |
| `Core/ScriptParsing/Parser/*` | `scripts/core/nova_parser.gd` | 当前 parser 更轻量 |
| `Nova/Lua/script_loader.lua` | `scripts/runtime/base_block.gd` + `script_loader.gd` | API 名称部分对齐，语义不同 |
| `Nova/Lua/built_in.lua` | 无直接对应 | 缺 `v_` / `gv_` / `__Nova` 等 Lua 环境语义 |
| `Nova/Lua/graphics.lua` | `scripts/runtime/graphics.gd` | 基础 show/hide/move/tint 对齐，参数/自动 fade/解锁规则不同 |
| `Nova/Lua/animation*.lua` + `Core/Animation/*` | `scripts/runtime/animation_system.gd`、`animation_chain.gd` | 当前为简化版 |
| `Nova/Lua/transition.lua`、`shader_info.lua`、`Core/VFX/*` | `scripts/runtime/transition_system.gd`、`vfx_system.gd` | 当前 shader/VFX 规模明显不足 |
| `Scripts/Controllers/*` | `scripts/runtime/*` | 功能被拆成 Godot 子系统，部分覆盖 |
| `Scripts/UI/Views/*` | `scripts/ui/*` + `scene/view/*` | 部分覆盖，缺多个视图 |
| `Scripts/UI/InputMapping/*` | `scripts/core/shortcut_manager.gd` + Settings UI | 只覆盖底层快捷键，缺完整 UI |
| `Tools/Scenarios/*` | 无 | 缺剧本工具链 |
| `Tools/Standings/*` | 无 | 缺立绘生产工具链 |
| `Tools/Resources/*` | `scripts/editor/generate_theme.gd` 等少量脚本 | 资源生成能力不足 |

---

## 六、优先级建议

### P0：先对齐 Nova 的核心卖点

1. 明确兼容目标：决定当前脚本语言是“Godot 方言”还是“NovaScript 兼容实现”。如果要以 `Nova/` 为开发目标，应补齐常用 NovaScript 语义：`l_` 局部 label、`v_` / `gv_` 变量、`is_save_point()`、`only_included_scenario_names`、`branch.image` 的 tuple 格式、`cond` function/string、文本插值、block attribute。
2. 重做存档核心：引入 checkpoint、node record、reached dialogue、reached end、bookmark metadata、全局存档、存档截图。
3. 实现章节选择：支持多 start node、locked/unlocked/debug start、按 reached history 解锁章节。
4. 把回顾跳转改成 checkpoint restore + replay，而不是直接定位 entry。

### P1：补齐运行时深度

1. 动画系统扩展为 per-dialogue / holding / UI / text 分组，支持 pause/resume/stop、并行动画、命名 holding animation、更多 property 类型和 easing。
2. VFX/shader 系统扩展为数据驱动 registry，支持多 shader 参数、后处理层、shader transition、render target，并规划 shaderproto 到 Godot shader 的生成路线。
3. 预加载系统支持剧本静态扫描，至少覆盖 show、audio、prefab、timeline、choice image。
4. 实现 minigame interrupt/fence 协议，支持小游戏结束后恢复视觉小说状态。
5. 完整迁移输入映射 UI 与移动端/指针输入处理。

### P2：产品化与工具链

1. 补 HelpView、Notification、Alert、首次提示、标题 BGM、UI sound、视图切换输入阻挡。
2. 扩充示例剧本和测试剧本，至少覆盖 Nova 的 `test_branch`、`test_minigame`、`test_transition`、`test_upgrade`、`test_variables`、`test_video`。
3. 建立 Godot 版剧本 lint/visualize/stat 工具，优先迁移 `Tools/Scenarios` 的高价值脚本。
4. 建立立绘导入和裁剪工具，补齐 standing asset 工作流。
5. 扩充 CI：加入 Godot headless 脚本解析测试、场景加载测试、导出产物 smoke test。

---

## 七、当前项目保留价值

当前 Uni-Story 并不是“偏离目标的无效重写”。它已经验证了几件有价值的事情：

- 用 Godot 4.6 + GDScript 可以搭出 Nova 风格 VN 运行时。
- `BaseBlock` 包装剧本块的方案足够轻量，适合 Godot 原生项目。
- 子系统拆分清楚，Graphics、Audio、VFX、Prefab、Video、Timeline 等都已有最小可用实现。
- UI 已经从纯原型推进到可导航的 GALGAME 主菜单、设置、存读档、鉴赏页面。
- 当前代码规模较小，仍适合做一次面向 Nova 目标的架构校准。

真正需要警惕的是：如果继续堆功能但不补 checkpoint / NovaScript 兼容 / 工具链，项目会变成“另一个轻量 VN runtime”，而不是 Nova 的 Godot 目标实现。

---

## 八、建议的近期里程碑

| 里程碑 | 目标 | 完成判据 |
|--------|------|----------|
| M1 NovaScript 兼容基线 | 补齐局部 label、变量前缀、is_save_point、block stage、文本插值、branch 兼容 | 能跑通从 Nova 迁移来的 `test_branch.txt`、`test_variables.txt`、`test_empty_node.txt` |
| M2 Checkpoint 存档骨架 | 引入 node record + checkpoint + reached dialogue | 能从任意已读对白回跳并正确重建视觉状态 |
| M3 章节选择与解锁 | 实现 ChapterSelectView 和 start node 解锁 | 多章节脚本可按已读进度解锁 |
| M4 动画/VFX parity 第一轮 | 扩展动画组和 shader registry | 能跑通 `test_anim_hold.txt`、`test_transition.txt` 的 Godot 等价测试 |
| M5 工具链最小集 | 剧本 lint、branch 可视化、资源扫描 | CI 中可自动检查示例剧本 |

---

## 九、结论

当前工程已经完成了 Godot 版 Nova 风格运行时的“骨架和多数基础器官”，但 Nova 目标工程真正成熟的部分集中在三块：checkpoint 回跳体系、Lua NovaScript 语义、内容生产工具链。后续若要继续以 `Nova/` 为开发目标，应优先迁移这三块，而不是继续只补单个演出 API。

推荐下一阶段从 P0 开始：先把 NovaScript 兼容基线和 checkpoint 存档骨架做实，再继续扩展 UI、动画、VFX 与工具链。

---

## 十、Phase 1 实施记录

### 2026-06-24：架构骨架与解析测试入口

已完成：

- 新增 `EngineContext` typed facade 草案，保留现有 `_ctx` 兼容路径，为后续逐步减少弱类型访问做入口。
- 新增 `RestorableRegistry`，用 duck typing 约定 `snapshot()` / `restore(data)`，并在 `NovaController` 中注册现有可恢复子系统。
- 新增 `scripts/tests/parse_scenarios_test.gd`，可用 Godot headless 解析 `resources/scenarios/*.txt` 并构建流程图。
- `GDRuntime` 增加 `had_error` / `last_error` / `clear_errors()`，`ScriptLoader` 在 eager block 编译失败时会把 `load_ok` 标为 false。

验证：

- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/parse_scenarios_test.gd`
- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --scene res://scene/game.tscn --quit-after 3`
- 注意：WinGet 的 `godot.exe` 指向非 console 版，不会显示脚本输出；验证需使用 `Godot_v4.6.3-stable_win64_console.exe`。
- 残留风险：主场景 headless 强制退出时有 CanvasItem/ObjectDB/resource leaked 警告，暂未确认是否为强制退出导致。

### 2026-06-24：GameState 推进测试与主场景生命周期清理

已完成：

- 新增 `scripts/tests/game_state_smoke_test.gd`，使用内嵌临时剧本在 headless 下驱动 `ScriptLoader` + `GameState`，覆盖 lazy block、`set_var/add_var`、`jump_if`、条件分支、禁用分支、`choose_branch()` 和命名 `is_end()`。
- 新增 `scripts/tests/main_scene_smoke_test.gd`，显式实例化 `scene/game.tscn`，校验 `NovaController`、脚本图、`GameState` 和 `ViewManager` 初始状态，再主动释放场景。
- `NovaController.gd` 增加 `_exit_tree()` 清理：停止 `HotReload`、关闭 `VideoSystem`、落盘 `ReadTracker`。
- 修复 `scene/game.tscn` 对 `scene/view/title_view.tscn` 的失效 UID 引用；`title_view.tscn` 补资源 UID。
- 将 `SaveLoadPanelController` 与 `BacklogPanelController` 从 `Control` 改为 `RefCounted`。二者实际是逻辑封装对象，原本用 `.new()` 创建但不加入场景树，会导致 headless 退出时泄漏两个 `Control`。

验证：

- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/parse_scenarios_test.gd`
- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/game_state_smoke_test.gd`
- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/main_scene_smoke_test.gd`
- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --scene res://scene/game.tscn --quit-after 3`

结果：

- `parse_scenarios_test` 解析 3 个 scenario、33 个节点。
- `game_state_smoke_test` 推进 5 条对白、2 个分支选项。
- 主场景 headless 加载和 `--quit-after` 对照均不再出现失效 UID、CanvasItem/ObjectDB/resource leaked 警告。

### 2026-06-24：Gallery 职责下沉与 typed facade 使用

已完成：

- 新增 `scripts/core/gallery_coordinator.gd`，承接 CG/BGM 鉴赏配置读取、已解锁状态套用、BGM/CG 自动解锁和视图刷新。
- `NovaController.gd` 保留 `cg_gallery_config` / `music_gallery_config` 导出配置与 `unlock_cg_by_path()` 兼容入口，实际逻辑委托给 `GalleryCoordinator`。
- `GalleryCoordinator` 内部通过 `EngineContext` 访问 `AudioSystem` 与 `ReadTracker`，作为后续新代码减少 `_ctx.xxx` 弱类型访问的样板。
- `scripts/tests/main_scene_smoke_test.gd` 增加 GalleryCoordinator 装配与 CG/BGM 配置加载断言。

验证：

- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/parse_scenarios_test.gd`
- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/game_state_smoke_test.gd`
- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --script res://scripts/tests/main_scene_smoke_test.gd`
- 通过：`Godot_v4.6.3-stable_win64_console.exe --headless --path <project> --scene res://scene/game.tscn --quit-after 3`

影响：

- `NovaController.gd` 的 Gallery 业务代码已从约 60 行降为装配/委托逻辑。
- 该抽取不改变现有剧本 API；`Graphics.show()` 仍可通过 `NovaController.unlock_cg_by_path()` 自动解锁 CG。
- 下一步适合按同样方式拆 `Save/Load`、`Settings` 和标题导航 coordinator。

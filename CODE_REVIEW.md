# Uni-Story 项目代码审阅报告

## 一、架构设计总评

Uni-Story 采用的是**服务定位器（Service Locator）模式**：NovaController 作为中央协调器，在 `_init_subsystems()` 中创建全部 24 个子系统（均为 `RefCounted` 对象），每个子系统通过 `_ctx: Node` 反向引用 NovaController 来访问兄弟系统。这是一个自洽的设计——对单场景视觉小说而言，整个应用就是一个场景树，NovaController 等效于"世界根节点"。

但这个架构有三个结构性问题值得重视：

**模型层不纯粹。** GameState 作为模型层（model），其文档注释声称"presentation is rebuilt by replay"，但实际上 `snapshot()` 和 `restore()` 方法（`game_state.gd:46-55, 99-110`）直接调用了 5 个表现层子系统：`animation`、`audio`、`prefab_loader`、`camera`、`graphics`。模型层直接依赖表现层，违反了 MVP/MVVM 的核心原则——模型不应知道视图的存在。虽然 save/restore 确实需要跨系统协调，但这个逻辑应该由 NovaController 或专门的 SaveCoordinator 来编排，而不是让 GameState 自己去够表现层。

**`_ctx: Node` 全局弱类型。** 为了避免 `class_name` 循环依赖（NovaController→GDRuntime→BaseBlock→NovaController），所有子系统的 `_ctx` 都声明为 `Node` 而非 `NovaController`。这个设计决策可以理解，但代价是失去了编译期类型检查和编辑器自动补全。NovaController.gd 开头是 `extends Node` 而没有 `class_name NovaController`——如果加上 `class_name`，GDScript 的循环引用检测在 4.6 中其实已经比早期版本更宽松，值得测试是否能直接打破这个循环。

**子系统间存在双向运行时依赖。** TransitionSystem 调用 `_ctx.vfx.transition()`，而 VFXSystem 在某些路径下又可能触发过渡——这是通过服务定位器间接互引，编译期不会报错，但运行时形成了一个逻辑环。GameState↔GDRuntime 之间也存在类似的情况：GameState 调用 `_ctx.runtime.run_block_async()`，而 GDRuntime 编译出的 BaseBlock 实例又通过 `_ctx` 回调 GameState。

### 值得肯定的架构决策

信号驱动的 model→view 通信是整个项目最干净的部分。GameState 声明了 6 个信号（`dialogue_changed`、`branch_requested`、`game_ended`、`chapter_started`、`ending_reached`、`dialogue_advanced`），由 NovaController 统一连接到 GameViewController 的处理方法。模型层完全不知道视图的存在，视图通过信号被动响应。视图控制器的导航请求（`title_requested`、`settings_requested`、`new_game_requested` 等）也通过信号向上传递给 NovaController 路由——这个方向同样是松耦合的。

ScriptLoader 的两遍解析设计（先 tokenize 再构建 FlowChartGraph）清晰可靠。FlowChartGraph.sanity_check() 包含 DFS 环路检测和 jump target 验证，是防御性编程的好实践。GDRuntime 将剧本块编译为 GDScript 原生类的方案非常巧妙——它让剧本作者可以直接使用 GDScript 语法（Vector3、方法链、条件表达式），而不需要发明一套新语言。

ObjectManager 的 freeze 机制（`object_manager.gd:12-13,42-47`）在设置完成后锁定 objects/constants 字典防止运行时篡改，这是一个很好的保护措施。


## 二、Godot 场景实例化实践

### 做得好的部分

game.tscn 正确实确地将 6 个视图场景作为子场景实例化（TitleView、GameView、SettingsView、CgGalleryView、MusicGalleryView、SaveLoadView），dialogue_box.tscn 作为独立场景被 game_view.tscn 实例化。共享按钮样式通过 button_ring.tscn 提取为独立 PackedScene，在 4 个控制器中通过 `preload` 引用。这些都是符合 Godot 理念的做法。

### 应实例化但用代码构建的 UI

项目中有多处本应定义为 .tscn 场景、却在代码中动态构建的 UI 层次结构：

**存档槽位行**是最明显的案例。`_open_save_panel()`（`game_view_controller.gd:782-809`）和 `_refresh_save_slots()`（859-882）两个方法几乎是完全重复的代码——都构建 `HBoxContainer` + `Button` + 删除 `Button` 的结构。这不仅违反 DRY 原则，而且如果槽位行的布局需要调整（比如加缩略图、时间戳），就要改两处。正确的做法是创建一个 `slot_row.tscn`，通过 `@export PackedScene` 引用后 `instantiate()`。

**鼠标右键菜单**完全在代码中构建（`game_view_controller.gd:887-946`）：`PanelContainer` + `VBoxContainer` + 9 个按钮，还包括手动视口钳制逻辑。这应该是一个 `context_menu.tscn` 场景，按钮通过代码填充文本和回调即可。

**Toast 通知**（`dialog_system.gd:83-103`）在代码中创建 `Label` + `ColorRect`，硬编码了颜色、字号、anchor 值——这些纯表现层数据应该放在场景文件里。

**CG 鉴赏预览覆盖层**（`cg_gallery_controller.gd:29-46`）在代码中构建 `ColorRect` + `TextureRect` 的全屏预览，同样应该是场景。

**对话框渐变遮罩**（`dialogue_box_system.gd:53-74`）在代码中创建 `ColorRect` 并应用 `StyleBoxFlat`，包括硬编码的 RGBA 颜色。

### 场景继承的缺失

4 个菜单视图（title、settings、save_load、cg_gallery、music_gallery）共享完全相同的"左侧栏 + 右侧内容区"的 HBox 布局——侧栏宽度都是 280px，VBox 的 alignment 都是 center，separation 都是 8，都有一个标题 Label + HSeparator + 按钮 + HSeparator + 返回按钮的结构。这些重复的节点层次应该通过场景继承来消除：创建 `base_menu_view.tscn` 定义侧栏骨架，各视图继承后只修改右侧内容区。

### `@export` 完全缺失

整个项目 36 个脚本中 `@export` 的使用次数为 **0**。所有可配置值都是代码中的 `const` 或硬编码值：`SCENARIO_FILES`、`SLOT_COUNT`、`AUTO_SAVE_SLOT`、`SE_POOL_SIZE`、`transition_duration`、`MAX_ENTRIES`、typewriter 默认 CPS、skip delay 等。这意味着设计师要调整任何一个参数都需要修改源代码。Godot 的 `@export` 机制正是为解决这个问题的——它让非程序员可以在 Inspector 面板中调整参数。

### `@onready` 使用不一致

大多数视图控制器使用标准的 `@onready var x = $path`（如 `title_view_controller.gd:15-22`、`settings_view_controller.gd` 有 36 个 `@onready`），但最大的控制器 GameViewController 反而在 `setup()` 中手动调用 31 次 `get_node_or_null()`（`game_view_controller.gd:93-125`）。虽然 .tscn 文件已经为每个节点声明了 `unique_id`，但脚本中从未使用 `%Name` 语法来引用——unique name 机制形同虚设。


## 三、代码模块耦合分析

### 耦合度排名

按 `_ctx` 字段直接访问数来衡量耦合度，从高到低：

GameViewController 以 95 次 `_ctx.` 访问位居榜首——它通过 `setup(self)` 接收了整个 NovaController，然后直接访问 `game_state`、`audio`、`backlog`、`read_tracker`、`save_system`、`dialog_system`、`dialogue_box`、`prefab_loader`、`composer`、`video_system`、`hot_reload`、`i18n`、`shortcut_manager`、`variables` 等 14 个子系统。这是一个知道太多的"上帝视图"。

BaseBlock 有 48 次委托调用——但这是 Facade 模式的有意设计，因为它是剧本 DSL 的 API 表面，耦合是必要的。问题是它暴露了 45 个方法，覆盖从图形到音频到视频到变量的全部领域，违反了单一职责原则。一个只需要 `show()` 的剧本块也继承了 `play_video`、`shake`、`load_prefab` 等全部能力。

GameState 有 29 次跨层访问——模型层直接调用了 5 个表现层子系统，这是最需要重构的耦合。

HotReload 有 28 次访问且引用了不存在的方法（`_ctx._refresh_chapters()`，`hot_reload.gd:120`），`has_method` 守卫使这段代码成为静默死代码。

SaveSystem 有 24 次访问，跨 6 个子系统做快照/恢复——与 GameState 的问题类似，序列化逻辑分散在多个系统中。

相对干净的系统：CameraSystem（仅访问 `object_manager.objects`）、ReadTracker（仅调用 `get_tree()`）、ViewManager（仅用 `get_tree()` 和 `get_viewport()`）、AudioSystem（仅访问 `object_manager.constants` 和 `get_tree()`）。这些系统遵循了"最少知识原则"。

### 死代码和断裂引用

`HotReload._refresh_chapters()`（`hot_reload.gd:120-121`）调用 `_ctx._refresh_chapters()`，但 NovaController 从未定义这个方法。`has_method` 守卫防止了崩溃，但热重载后章节列表不会刷新。

`PrefabLoader.get_game_vc()`（`prefab_loader.gd:231-236`）调用 `_ctx.get_game_vc()`，同样不存在。整个 fallback 块是死代码。主路径 `get_node_or_null("GameView")` 工作正常，所以 prefab 仍能加载，但 fallback 分支是误导性的。

`NovaController._register_objects()`（`NovaController.gd:212-214`）是空方法，注释承认"Objects already registered in _setup_game_view()"。应该直接删除。

`GDRuntime.run_block_async()` 中的超时处理（`gd_runtime.gd:79-88`）有一段死代码：`completed = true` 之后紧跟 `if not completed: return null`，这个分支永远不会执行。更严重的是，30 秒超时只打印错误但不终止被 await 的协程，`_running_async` 也不会被重置——如果剧本真的卡住，游戏会永久死锁。

### 条件缓存未失效的潜在 Bug

`GameState._cond_cache`（`game_state.gd:30-31`）缓存了分支条件的求值结果，采用 64 条上限的 quarter-eviction 策略。缓存在 `restore()` 和 `start_node()` 时清空，但 `Variables.set_var()` 时不清空。`Variables` 有 `changed` 信号（`variables.gd:13`）但 GameState 没有连接它。在实践中，条件求值发生在节点耗尽时（所有 lazy block 执行完毕后），所以当前可能是安全的。但如果未来在同一个节点内出现"先 set_var 再 branch"的模式，缓存会返回过时的结果。

### 存档版本无校验

`SaveSystem.save()` 写入 `"version": 1`（`save_system.gd:29`），但 `load_slot()` 从不检查版本号。如果未来格式变更，旧存档会静默解析失败而非给出明确的迁移提示。

### 安全性考量

GDRuntime 将剧本 `.txt` 文件中的代码块编译为真实 GDScript 执行（`gd_runtime.gd:37-46`），`_eval_condition`（`game_state.gd:329-330`）也会编译条件字符串。这意味着剧本文件等价于可信代码——可以执行 `OS.shell_open`、`FileAccess` 写入等任意操作。作为单机视觉小说引擎，这是可接受的设计决策（剧本作者是可信的），但值得在文档中明确声明这个信任模型。

### NovaScript 解析器健壮性

解析器（`nova_parser.gd`）是一个 tokenizer 而非完整 parser，将块内容的正确性委托给 GDScript 编译器——这是一个聪明的设计。但有两个结构性缺陷：

`_read_block` 在搜索 `|>` 闭合标记时不考虑字符串上下文（`nova_parser.gd:127,139`）。如果剧本行中出现 `<| show_toast("a |> b") |>`，解析器会在字符串内的 `|>` 处提前截断块。单行块用 `rfind("|>")`（最后一个），多行块用 `find("|>")`（第一个）——语义不一致。

`_split_speaker`（`script_loader.gd:96-110`）的冒号切分启发式有误判风险。`时间：10:00` 会被切分为说话人"时间"和文本"10:00"。虽然 `：：` 双冒号是无歧义的意图标记，但单冒号回退太贪婪。

`@[...]` 属性头的解析错误（如未闭合的 `]`）会静默回退为文本行，无任何警告（`nova_parser.gd:76-77`）。


## 四、UI/UX 设计审阅

### 整体布局

项目的 UI 采用**GALGAME 风格左侧菜单 + 右侧内容区**的布局，这与用户偏好一致。5 个菜单视图（标题、设置、存档/读档、CG鉴赏、音乐鉴赏）都使用相同的 `HBox` → `Sidebar(280px)` + `Content` 结构，视觉一致性较好。

游戏内 HUD 采用底部控制栏（存档/读档/回顾/自动/快进/重开/标题）+ 底部对话框 + 居中选择列表的布局，是标准 GALGAME 布局，用户上手门槛低。右键弹出上下文菜单提供了快捷访问，包含快速存档/读档等高级功能——对有经验的玩家友好。

### 布局问题

**对话框的 Avatar 区域锚点混乱。** `dialogue_box.tscn:10-19` 中，Avatar 的 `anchor_right = 0.102`、`anchor_bottom = 0.664`、`offset_right = 0.33`、`offset_bottom = 0.04`——anchor 和 offset 混合使用且值不直观。当对话框尺寸变化时（不同分辨率），Avatar 的位置和大小可能不可预测。应该使用固定的 `custom_minimum_size` + 整数 offset。

**Status 标签位置可能遮挡内容。** `game_view.tscn:43-48` 中 Status 标签使用 `anchors_preset = 10`（底部全宽），`offset_bottom = 104.0` 但 `offset_top` 默认为 0——这意味着它从对话框顶部延伸到 104px 高度，实际渲染范围依赖文本内容。如果状态文本较长，可能与对话框重叠。

**SavePanel 使用绝对比例锚点。** `anchor_left = 0.3, anchor_top = 0.18, anchor_right = 0.7, anchor_bottom = 0.82`——在不同宽高比下面板比例会变形。应该使用 `PRESET_CENTERED` + 固定 `custom_minimum_size`，或至少保持宽高比约束。

**BacklogPanel 同样使用比例锚点**（`0.15~0.85, 0.1~0.9`），在超宽屏或竖屏下会出现过大或过小的问题。

**ConfirmPanel 是唯一正确居中的面板**（`anchors_preset = 8` + ±200/±100 offset），但 `custom_minimum_size = Vector2(400, 200)` 在小窗口下可能溢出。

### 视觉一致性

**项目没有全局 Theme 资源。** 搜索整个 resources 目录没有找到任何 `.tres` 或 `.theme` 文件。所有控件的字体、颜色、间距都是默认值或通过 `theme_override` 逐个设置。这意味着：按钮在标题界面和设置界面可能看起来不同（取决于是否有 override），字号变更需要逐个控件修改，无法统一调整视觉风格。

**对话框没有视觉样式。** `dialogue_box.tscn` 中的 Panel 是默认灰色面板，Speaker 和 Story 标签也没有设置字体、颜色、间距。对于一个 GALGAME 来说，对话框是最核心的 UI 元素——它应该有明确的背景色（半透明黑色）、圆角、内边距、字体设置。目前这些都没有。

**按钮没有统一样式。** button_ring.tscn 只是设置了 `custom_minimum_size = Vector2(220, 44)`，没有任何视觉样式。HUD 底部的控制按钮（存档/读档等）直接使用原生 Button，与 GALGAME 的美学风格不符。考虑到用户偏好"现代简约暗色风格"，这些按钮至少应该有暗色背景、浅色文字、hover 状态变化。

**ContinueIcon 没有设置纹理。** `dialogue_box.tscn:41-48` 的 ContinueIcon 是个空的 TextureRect，没有 `texture` 属性——除非运行时通过代码设置，否则玩家看不到"点击继续"的视觉提示。

### 交互体验

**点击推进对话的逻辑**（`game_view_controller.gd:899-913`）：左键点击推进、右键弹出菜单。如果对话框不可见则左键也推进——这个逻辑合理，但没有处理对话框可见但用户想跳过对话框内文字的情况。标准 GALGAME 做法是：第一次点击完成打字机效果（如果正在打字），第二次点击才推进对话。当前代码看起来没有这个逻辑——需要确认 `_on_next()` 是否处理了"正在打字时点击"的情况。

**自动模式和快进**通过 toggle button 控制，状态保存在 `_is_auto` 和 `_is_skip`。快进有 `SKIP_DELAY = 0.05` 的固定间隔，自动模式有按字符数计算的延迟。但 `skip_unread` 设置项存在却需要确认其是否真的生效——设置面板中有这个选项，但需要验证 GameViewController 是否读取并应用了它。

**存档面板的槽位没有缩略图。** 每个槽位只显示文本标签（"存档位 1：xxx"），没有截图缩略图、时间戳、章节信息。对于视觉小说来说，缩略图是存档系统几乎必备的功能——玩家需要视觉提示来回忆存档进度。`slot_label()` 返回的文本可能包含章节信息，但纯文本远不如缩略图直观。

**文本回顾（Backlog）使用 RichTextLabel 列表**（`game_view_controller.gd:731-749`），每条记录手动设置 `custom_minimum_size` 并通过 `await` 一帧来锁定高度。这个方法在之前的项目笔记中已经标记为已知问题——动态创建的 RichTextLabel 的 `fit_content` 在添加后高度为 0。当前用"先显示 Panel → await 一帧 → 添加 labels → await 一帧 → 锁定高度"的 workaround，比较脆弱。

**设置页面的快捷键区域**在代码中动态构建（`settings_view_controller.gd:242-277`），每次打开都重建行。这意味着用户在设置页面修改快捷键后，如果返回再进入设置页面，行会被重建——但已修改的值应该从持久化存储读取，所以功能上应该没问题，只是效率不高。

### 无障碍设计

**字体大小有设置项**（`settings_view.tscn:165-178`，12~48px 范围），这是好的。但需要确认这个设置是否真的应用到了所有文本控件——如果没有全局 Theme，可能只影响部分 UI。

**颜色对比度**：由于使用默认控件样式，在暗色背景下默认浅色文字的对比度可能不够。对话框是灰色 Panel + 默认文字颜色，在不同背景图上可能可读性差。

**键盘导航**：SettingsViewController 有快捷键配置系统，但游戏中是否能完全用键盘操作（推进对话、打开存档、选择分支）需要验证。HUD 按钮可以通过 Tab 聚焦，但对话框区域和选择列表的键盘交互没有明确实现。

**分辨率适配**：大部分 UI 使用了 `anchors_preset = 15`（全屏锚点），基本能适配不同分辨率。但如前所述，SavePanel 和 BacklogPanel 的比例锚点在极端宽高比下会有问题。对话框使用 anchor 0.08~0.92 的比例，在超宽屏上会过宽。


## 五、GameViewController 过胖

GameViewController 是 1115 行的巨型控制器，职责包括：打字机效果、对话显示、分支选择、自动/快进模式、存档/读档面板、文本回顾面板、鼠标右键菜单、快捷键处理、热重载钩子。这至少应该拆分为 4-5 个类：

- `TypewriterController`：打字机效果和文字显示状态
- `SaveLoadPanelController`：存档/读档面板逻辑（包含槽位构建）
- `BacklogPanelController`：文本回顾面板
- `ContextMenuController`：右键上下文菜单
- `GameViewController`：作为 facade 协调上述控制器

NovaController（524 行）也有类似问题，但它主要是声明式地创建和连接子系统，拆分优先级较低。SettingsViewController（329 行）的快捷键录制逻辑（242-322 行）可以提取为独立的 `ShortcutRecorder` 类。


## 六、其他发现

**数组未使用类型标注。** Godot 4.6 支持类型化数组（`Array[FlowChartNode]`），但项目中全部使用裸 `Array`。`flow_chart_node.gd:18` 的 `entries: Array` 应该是 `Array[DialogueEntry]`，`flow_chart_graph.gd:5` 的 `nodes: Array` 应该是 `Array[FlowChartNode]`。这能在编译期捕获类型错误。

**AnimationSystem 方法名违反 GDScript 命名约定。** `PropertyVector3`、`PropertyColor`、`Delay`（`animation_system.gd:15-24`）使用 PascalCase 命名方法，应该用 `property_vector3` 等。虽然这是为了模拟流畅的 DSL builder 语法，但与 Godot 的 `snake_case` 方法约定冲突。

**PreloadSystem 缓存无上限。** `preload_system.gd:17` 的 `_cache` 字典无界增长，`clear_cache()` 仅在热重载时调用。长时间游戏会话中预加载大量 CG 会持续占用内存，没有 LRU 淘汰策略。

**Image.load_from_file 绕过导入管线。** `graphics.gd:119-123` 和 `sprite_composer.gd:37-41` 在 `load()` 失败时回退到 `Image.load_from_file()` 加载原始图片文件。这绕过了 Godot 的纹理导入和 VRAM 压缩，适合开发期临时资源但应加 `OS.is_debug_build()` 守卫。


## 七、改进建议优先级

**高优先级（影响正确性和可维护性）：**

1. 将 GameState 的 snapshot/restore 逻辑提取到 NovaController 或独立的 SaveCoordinator，消除模型层对表现层的直接依赖。
2. 修复 GDRuntime 超时处理：移除死代码分支，超时后重置 `_running_async` 并通知调用方失败。
3. 创建全局 Theme 资源（`.tres`），统一定义按钮、标签、面板的字体、颜色、间距。这是 UI/UX 改善的基础。
4. 将存档槽位行提取为 `slot_row.tscn` 场景，消除 `_open_save_panel` 和 `_refresh_save_slots` 的代码重复。
5. 删除死代码：`HotReload._refresh_chapters` 调用、`PrefabLoader.get_game_vc` 调用、`NovaController._register_objects` 空方法。

**中优先级（改善开发体验和架构质量）：**

6. 将 GameViewController 拆分为 4-5 个子控制器，减少单文件职责。
7. 为 NovaController 添加 `class_name`，测试是否能安全地让 `_ctx` 使用具体类型而非 `Node`。
8. 将右键菜单、toast、CG预览覆盖层等动态构建的 UI 迁移到 .tscn 场景文件。
9. 使用场景继承创建 `base_menu_view.tscn`，消除 5 个菜单视图的侧栏重复。
10. 将关键参数改为 `@export`，让设计师可在 Inspector 中调整。
11. 连接 `Variables.changed` 信号到 `_cond_cache` 的失效逻辑。
12. 在 `load_slot()` 中添加版本号校验。

**低优先级（代码质量提升）：**

13. 统一 `_bind_nodes()` 为 `@onready` 或 `%unique_name` 引用。
14. 使用类型化数组（`Array[FlowChartNode]` 等）。
15. 为 PreloadSystem 添加 LRU 淘汰策略。
16. 修复 NovaScript 解析器中 `|>` 在字符串内的截断问题。
17. 修正 AnimationSystem 方法命名为 snake_case。
18. 为存档系统添加截图缩略图功能。

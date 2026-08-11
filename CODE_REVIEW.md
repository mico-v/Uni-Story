# Uni-Story 代码评审报告

> 评审对象：`V:\github.com\mico-v\Uni-Story`（Godot 4.6 + GDScript 视觉小说引擎）
> 评审范围：`project.godot`、`.editorconfig`/`.gitignore`、架构（`NovaController` 组合根 + `EngineContext` 门面）、核心模型/运行时/UI 脚本、场景、测试与工具链
> 结论：**架构合理、符合 Godot 主流规范、可维护性良好**。存在少量需修正项，绝大多数是“内部文档/配置与官方规范、与代码实际”不一致，而非架构缺陷。

---

## 一、总体结论

| 维度 | 评价 |
|------|------|
| 架构合理性 | ✅ 优秀。清晰的 Composition Root + 分层（core / runtime / ui / tools），依赖注入（`new(self)`）+ 类型化 `EngineContext` 门面，快照/恢复存档模型解耦良好 |
| Godot 规范符合度 | ✅ 基本符合。类 PascalCase、方法/变量 snake_case、信号过去时、typed container、无 `yield`/`.instance()`/`load()` 反模式 |
| 配置与工程卫生 | ⚠️ `.editorconfig` 与代码实际缩进冲突；两份内部文档对 `:=` 表述矛盾 |
| 可继续开发/维护 | ✅ 良好。文档齐全（README/PLAN/CLAUDE/CodingStandards/docs）、31 个 headless 测试 + lint/stat 工具 + CI 门禁 |
| 易用性（复用为引擎） | ⚠️ 剧本清单硬编码进组合根（已 `@export`，可配置），未来可改为“目录扫描/配置资源” |

---

## 二、做得好的地方（值得保持）

1. **组合根精简、职责清晰**：`NovaController.gd` 只做装配、视图绑定、信号路由；游戏 UI 逻辑已下沉到 `GameViewController`。`_ready()` 顺序清晰，`_exit_tree()` 统一释放资源（audio/vfx/composer/video/prefab），无泄漏隐患。
2. **类型纪律扎实**：核心模型（`GameState`、`EngineContext`）大量使用显式类型与 typed container（`Dictionary[String, bool]`、`Array[StringName]`、`Array[Dictionary]`），`snapshot() -> Dictionary` / `restore(data: Dictionary)` 契约明确。信号也带类型参数（`signal branch_requested(options: Array[Dictionary])`）。
3. **存档模型解耦优雅**：`RestorableRegistry` 用 duck-typed `snapshot/restore` 统一编排；`GameState` 只管模型态，其余 restorable 由组合根按层恢复，避免 replay 与表现态互相覆盖。这是成熟 VN 引擎的正确做法。
4. **配置外置到位**：可调参数全部 `@export`；角色/立绘/视觉/主题均走 `.tres`（`StandingProfile`/`VisualProfile`/`AutoVoiceProfile`/themes），无内容配置硬编码进运行时脚本——符合 `CodingStandards.md` 的前端规则。
5. **工程卫生正确**：`.gitignore` 正确排除 `.godot/`、`*.import`、`Nova/`（参考 Unity 子模块）、`android/`、`release/`；`Nova/` 作为 git 子模块隔离，不污染主仓库。
6. **编辑器插件安全**：`addons/` 下无 `@tool` 关键字（grep 0 命中），headless 导入不会被编辑器脚本拖慢或打断。
7. **`project.godot` 规范**：`config_version=5`、主场景、`features=PackedStringArray("4.6","Mobile")`、stretch `canvas_items`/`expand`、输入映射带 deadzone、移动端 VRAM 压缩 `import_etc2_astc=true`——都很到位。
8. **无反模式**：全仓无 `yield(`、无 `.instance()`（均为 `.instantiate()`）、无 `class_name` 重名冲突。

---

## 三、需要改进的点（按优先级）

### P1 — `.editorconfig` 与实际代码冲突（LOW，但应立刻修）
- 现象：`.editorconfig` 写 `indent_style=space`，但 `scripts/` 下 **115/115** 个 `.gd` 文件实际用 **TAB** 缩进。
- 澄清：**TAB 缩进本身符合 Godot 官方风格指南**（官方默认即 Tabs）。问题不在代码，而在 `.editorconfig` 与 Godot 默认、与代码现实不一致。
- 建议：把 `.editorconfig` 改为 `indent_style=tab`（或在 `[*.gd]` 段单独设 `indent_style=tab`）。一行改动即可消除“配置与代码打架”的风险（否则用空格编辑器的协作者可能引入 tab/space 混排，触发解析错误）。

### P2 — 两份内部文档对 `:=` 表述矛盾（LOW，文档对齐）
- 现象：`CLAUDE.md` 说 `:=` “preferred”；`docs/CodingStandards.md` 说“**避免使用 `:=` 类型推导式**”。代码实际大量使用 `:=`。
- 澄清：Godot 官方风格指南**推荐使用 `:=`** 做类型推导。代码是对的，`CodingStandards.md` 这条与官方规范、与代码现实都冲突。
- 建议：以 `CLAUDE.md` 为准，更新 `CodingStandards.md` 第 20 行，改为“公开 API 与跨边界数据用显式类型；局部字面量/ `preload` 可用 `:=`”——与 Godot 习惯和代码一致。

### P3 — 绕过类型化门面，使用字符串化 `_ctx.get("x")` / `call("get", ...)`（MED，渐进重构）
- 位置：`scripts/runtime/base_block.gd`（`_ctx.call("get", "game_view_controller")`、`_ctx.get("composer")` 等）、`chapter_select_view_controller.gd:175,184,191`、`view_manager.gd:224`。
- 问题：`EngineContext` 类型化门面已存在且 `CodingStandards.md` 明确要求“优先用 `EngineContext` typed facade；兼容旧代码时才用 `_ctx.xxx`”。但 Hot path 仍在用字符串动态查找，牺牲了类型安全、且重命名子系统会静默失效。
- 建议：把 `GameViewController` 也纳入 `EngineContext` 属性，并逐步将 `base_block.gd` 与子系统里的 `_ctx.get(...)` 改为 `EngineContext.xxx`。这是“渐进式、低风险”的重构，不必一次性完成。

### P4 — 场景缺唯一节点名（`%`），依赖字符串 `get_node`（MED，健壮性）
- 位置：`NovaController._bind_view_controllers()` 用 `get_node_or_null("TitleView")` 等字符串按名查找；`cg_gallery_controller.gd:37` 用 `overlay.get_node("TextureRect")`。
- 建议：对稳定引用的节点改用 **唯一节点名（`%TitleView`）** 或 `@onready` 绑定。重命名节点时字符串查找会静默失败，唯一名可在编辑器内安全重构。

### P5 — 剧本清单硬编码进组合根（LOW–MED，未来改进）
- 位置：`NovaController.gd:16-45` 的 `scenario_files: Array[String]`（27 条 `res://resources/scenarios/*.txt`）。
- 说明：已用 `@export`，可在 Inspector 改，对“示例/样例引擎”可接受。但若要作为可复用引擎分发，建议改为**目录扫描**（读 `resources/scenarios/` 下所有 `.txt`）或用一个 `ScenarioManifest` 资源配置，避免引擎与示例内容耦合。

### P6 — 待确认的 minor 项（LOW，验证即可）
- `android/` 被 `.gitignore` 忽略：确认其仅为导出产物/模板（Godot Android 导出会重新生成），而非运行时必需的源码配置。
- `addons/.../build_hooks.gd`：确认只在**导出时**执行重逻辑，不在导入期跑（否则可能影响 headless import 速度/稳定性）。目前无 `@tool`，风险低。

---

## 四、关于“规范符合度”的澄清（避免误报）

自动化扫描曾把以下三点标为“违规/HIGH”，经核对 Godot 官方风格指南，结论如下——**代码其实是对的，问题在内部配置/文档**：

| 扫描结论 | 实际 | 处置 |
|----------|------|------|
| TAB 缩进“违反风格指南、解析器拒收” | Godot 官方**默认即 Tabs**，解析器接受纯 TAB；项目能跑（与 31/31 测试一致） | 修 `.editorconfig`（P1）即可 |
| 文件名 snake_case“违反 PascalCase 约定” | 多个 Godot GDScript 风格指南**推荐 snake_case 文件名** | 非问题，保持 |
| `:=` “应避免” | 官方风格指南**推荐 `:=`** | 修 `CodingStandards.md`（P2）即可 |

> 真正的规范风险只有一条：**`.editorconfig` 说空格、代码用 TAB**——这是配置漂移，不是代码错误。

---

## 五、优先级行动清单

1. **（立即可做）** 改 `.editorconfig`：`indent_style=space` → `tab`（仅一行，消除配置/代码冲突）。
2. **（文档）** 对齐 `CodingStandards.md` 与 `CLAUDE.md` / Godot 官方：明确 `:=` 可用、TAB 合规。
3. **（渐进重构）** 将 `GameViewController` 纳入 `EngineContext`，替换 hot path 里的 `_ctx.get("x")` / `call("get", ...)`。
4. **（健壮性）** 场景稳定引用改用唯一节点名 `%`，替换字符串 `get_node`。
5. **（未来）** 评估剧本“目录扫描 / ScenarioManifest”以解耦引擎与示例内容。
6. **（验证）** 确认 `android/` 忽略策略与 `build_hooks` 仅导出期执行。

---

## 六、最终判断

这是一份**工程质量高于平均水平**的 Godot 项目：架构分层清晰、依赖注入与类型门面到位、存档模型成熟、配置外置彻底、测试与工具链完整。它没有会阻碍继续开发的架构性债务。最需要做的不是重写，而是**三件“对齐”小事**——修正 `.editorconfig`、统一两份内部文档口径、把字符串化 `_ctx` 访问收敛到 `EngineContext` 门面。做完这些，规范符合度与长期可维护性会更稳。

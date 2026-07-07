# Nova 与 Uni-Story 差异评审

> 审查日期：2026-06-24 · 最后更新：2026-07-06  
> 目标工程：`Nova/`，Unity 2020.3.48f1 + C# + Lua(ToLua#)  
> 当前工程：仓库根目录，Godot 4.6 + GDScript

---

## 一、总评

Uni-Story 已完成 Godot 版 Nova 风格运行时的核心建设。10 个 Phase 全部推进到「核心完成」状态：脚本解析、流程图、对话/分支、Checkpoint/Bookmark 存档、章节选择/标题体验、UI 产品层、动画域+easing、VFX/Shader 注册表、资源扫描工具、InterruptManager 中断协议、以及 8 个 headless 自动化测试。

当前完成度估算：

| 模块 | 完成度 | 说明 |
|------|--------|------|
| 核心 VN 运行时 | ~85-90% | 演出 API 完整覆盖，可播放 28 个 Nova 原始剧本 |
| NovaScript 行为兼容 | ~70-80% | 兼容层覆盖常用语法；不是完整 Lua VM |
| 存档/回跳/升级体系 | ~80-85% | Checkpoint/bookmark 核心完成，restore+replay 可用 |
| UI 产品功能 | ~85-90% | 标题/游戏/设置/存读档/鉴赏/章节/帮助/通知/输入映射 |
| 资源与工具链 | ~40-50% | 资源扫描就绪；Nova 工具链迁移待后续 |
| **整体对齐** | **~75-85%** | 10 Phase 核心完成，引擎骨架就绪 |

主要剩余差距集中在三块：完整 Lua 语义兼容、内容生产工具链（lint/visualize/立绘裁剪/shader 生成）、以及导出/性能/示例作品产品化。

---

## 二、工程规模对比

| 项目项 | Nova 目标工程 | 当前 Uni-Story |
|--------|---------------|----------------|
| 引擎 | Unity 2020.3，URP | Godot 4.6 |
| 主场景 | `Nova/Assets/Scenes/Main.unity` | `scene/game.tscn` |
| 核心语言 | C# + Lua(ToLua#) | GDScript |
| 脚本文件数 | C# ~233 + Lua ~24 | GDScript ~46 |
| UI 资产 | 大量 Unity prefab | 16 个 Godot `.tscn` 场景 |
| 剧本 | 28 个中文 + 4 个英文 | 28 个 Nova 中文剧本（已导入） |
| 工具链 | Scenarios/Standings/Resources/Build | GitHub Actions + 资源扫描 + headless 测试 |

---

## 三、架构差异

### 3.1 组合根

- **Nova**：`NovaController.cs` 是 prefab 组件聚合器，业务分散在 MonoBehaviour、C# Core 和 Lua 之间。
- **Uni-Story**：`NovaController.gd` 是 Composition Root，直接创建 ~28 个 `RefCounted` 子系统。架构更集中，启动路径清楚，但 `_ctx: Node` 弱类型访问需要继续收敛。

### 3.2 剧本运行时

- **Nova**：Lua VM 执行，`v_`/`gv_` 元表自动映射，Lua 闭包和协程可用。
- **Uni-Story**：`<|...|>` 编译为 `BaseBlock` 的 GDScript，通过 `NovaScriptCompat` 翻译层支持 `l_` label、`v_`/`gv_` 变量、文本插值、branch tuple 等。不是完整 Lua VM，但覆盖了常用 NovaScript 语义。

### 3.3 存档与回跳

- **Nova**：`CheckpointManager` + `NodeRecord` 历史树 + reached data + `Differ`/`CheckpointUpgrader` 脚本升级。
- **Uni-Story**：已实现 CheckpointManager（node record / reached dialogue / position checkpoint）+ Bookmark metadata（缩略图/时间/章节）+ restore_to_position（最近 checkpoint restore + replay）。脚本升级（diff/upgrader）待后续。

### 3.4 UI 架构

- **Nova**：12 个 controller + prefab 体系。
- **Uni-Story**：9 个 View + 对应 controller，外加 Toast/Confirm/ContextMenu/Backlog/ChoiceList。ViewManager 支持 Title/UI/Game/InTransition/Alert 状态，切出 GameView 自动暂停动画/语音。

### 3.5 动画与 VFX

- **Nova**：`NovaAnimation` 四种域 + Then/And + pause/resume/stop/group + 37 shaderproto 生成 176 shader。
- **Uni-Story**：AnimationSystem 四种域 + pause/resume/stop 按域控制 + 命名 holding group + 12 种 easing + 更丰富的 property。VFX 8 种 shader 效果 + 注册表驱动，缺 shaderproto 生成链。

---

## 四、文件级映射（关键项）

| Nova | Uni-Story | 状态 |
|------|-----------|------|
| `Core/NovaController.cs` | `scripts/NovaController.gd` | 职责不同：当前是总装配器 |
| `Core/GameState.cs` | `scripts/core/game_state.gd` | 基础推进已实现 |
| `Core/Restoration/CheckpointManager.cs` | `scripts/core/checkpoint_manager.gd` + `save_system.gd` | ✅ 已对齐 |
| `Core/ScriptParsing/*` | `scripts/core/nova_parser.gd` + `nova_script_compat.gd` | 翻译层已覆盖常用语法 |
| `Nova/Lua/graphics.lua` | `scripts/runtime/graphics.gd` | ✅ 基本对齐 |
| `Nova/Lua/animation*.lua` | `scripts/runtime/animation_system.gd` + `animation_chain.gd` | ✅ 域/easing/pause/resume 已实现 |
| `Nova/Lua/transition.lua` + `Core/VFX/*` | `scripts/runtime/transition_system.gd` + `vfx_system.gd` | 8 shader 效果 + 注册表 |
| `Scripts/UI/Views/*` | `scripts/ui/*` + `scene/view/*` | ✅ 9 视图 + 输入映射 + 通知 |
| `Scripts/UI/InputMapping/*` | `scripts/core/shortcut_manager.gd` | ✅ 按键录制 + 冲突检测 |
| `Tools/Scenarios/*` | `scripts/tests/scenario_resource_scan_test.gd` | 🔲 仅资源扫描，缺 lint/visualize |
| `Tools/Standings/*` | 无 | 🔲 缺立绘工具链 |
| `Tools/Resources/*` | 少量 editor 脚本 | 🔲 缺 shader 生成 |

---

## 五、里程碑

| 里程碑 | 目标 | 状态 |
|--------|------|------|
| M1 NovaScript 兼容基线 | 局部 label、变量、stage、文本插值、branch tuple | ✅ |
| M2 Checkpoint 存档骨架 | node record + checkpoint + reached dialogue，任意回跳 | ✅ |
| M3 章节选择与解锁 | ChapterSelectView + start node 解锁 | ✅ |
| M4 动画/VFX parity | 动画域/easing/shader 注册表/new effects | ✅ |
| M5 工具链最小集 | 资源扫描 | ✅ |
| M6 中断/小游戏 | interrupt/fence 协议 | ✅ |
| M7 平台与质量 | 8 smoke tests + 文档对齐 | ✅ |

---

## 六、后续方向

按优先级：

1. **UI 主题拆分** — 支持作品级定制
2. **PreloadSystem 升级** — 优先级/LRU/进度
3. **Nova 工具链迁移** — lint/visualize/stat/立绘导入
4. **Shader 深度** — shader layer、render target、shaderproto 生成器
5. **产品化** — 导出 smoke test、性能基线、示例作品完善

---

## 七、文档索引

| 文档 | 用途 |
|------|------|
| `PLAN.md` | 路线、任务、状态、验收标准 |
| `review.md` | 本文档 — Nova 对比、阶段审查、风险记录 |
| `docs/NovaScript.md` | 脚本语法、兼容表、API 参考 |
| `docs/PhaseBacklog.md` | 各 Phase commit 粒度清单 |
| `docs/ProjectTerms.md` | 术语表 |
| `docs/CodingStandards.md` | 编码规范 |
| `README.md` | 用户视角快速开始 |
| `SETUP.md` | 环境搭建与架构概览 |

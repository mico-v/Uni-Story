# Nova 与 Uni-Story 差异评审

> 审查日期：2026-06-24 · 最后更新：2026-07-10
> 目标工程：`Nova/`，Unity 2020.3.48f1 + C# + Lua(ToLua#)
> 当前工程：仓库根目录，Godot 4.6 + GDScript

---

## 一、总评

Uni-Story 已完成 Godot 版 Nova 风格运行时的主要骨架：脚本解析、流程图、对话/分支、Checkpoint/Bookmark 存档、章节选择与标题体验、UI 产品层、动画域与 easing、VFX/Shader 注册表、InterruptManager，以及 AutoVoiceSystem、ThemeManager、PreloadSystem、PrefabLoader 等运行时基础设施。Scenario lint 已纳入 CI/Release，Scenario stat 与 execution-free 共享 IR 已落地；当前完整 headless suite 为 20/20 PASS（约 55 秒），由统一 runner 逐个隔离执行，并作为导出任务的前置质量门禁。

这表示核心运行时已经可持续开发和回归验证，不表示 Nova 的演出 API 或 Lua 语义已完整覆盖。AutoVoice 已具备 canonical speaker、6 位编号、一次性 delay、显式覆盖、Auto/Backlog 协同和存档恢复；`box_tint()`、部分输入/快进/文本排版接口等仍只是兼容入口或 no-op，复杂 Lua 和若干上游工具仍未迁移。

当前完成度估算：

| 模块 | 完成度 | 说明 |
|------|--------|------|
| 核心 VN 运行时 | ~85-90% | 核心推进、演出、存档链路可用；演出 API 仍有缺口和兼容 no-op |
| NovaScript 行为兼容 | ~70-80% | 常用语法与 API 子集可用；不是完整 Lua VM，也不保证上游脚本无修改运行 |
| 存档/回跳/升级体系 | ~80-85% | Checkpoint/bookmark 核心完成，restore+replay 可用 |
| UI 产品功能 | ~85-90% | 标题/游戏/设置/存读档/鉴赏/章节/帮助/通知/输入映射 |
| 运行时基础设施 | ~80-85% | Theme/Preload/Prefab 核心完成；仍需更深的产品场景验证 |
| VFX 与转场 | ~60-70% | 12 个 shader 资产与基础注册表可用；多 pass 合成和 capture transition 未完成 |
| 资源与工具链 | ~60-70% | 资源扫描、Scenario lint/stat、共享静态 IR 与测试 runner 就绪；visualize、立绘与 shader 工具待后续 |
| **整体对齐** | **~75-85%** | 核心里程碑已落地，兼容与产品化边界如上 |

当前优先差距集中在三块：scenario 分支展示/流程可视化等剩余内容工具、VFX 多 pass/capture transition，以及导出启动 smoke、性能基线和可交付样例。

---

## 二、工程规模对比

| 项目项 | Nova 目标工程 | 当前 Uni-Story |
|--------|---------------|----------------|
| 引擎 | Unity 2020.3，URP | Godot 4.6 |
| 主场景 | `Nova/Assets/Scenes/Main.unity` | `scene/game.tscn` |
| 核心语言 | C# + Lua(ToLua#) | GDScript |
| 脚本文件数 | C# ~233 + Lua ~24 | 88 个 GDScript |
| 场景资产 | 大量 Unity prefab | 19 个 Godot `.tscn` 场景 |
| Shader 资产 | 37 shaderproto 生成 176 shader | 12 个 `.gdshader` |
| 剧本 | 28 个中文 + 4 个英文 | 28 个 Nova 中文剧本（已导入） |
| 自动化测试 | Unity/NUnit 与工程内工具 | 20 个 headless 测试，20/20 PASS + `run_headless_suite.py` |
| 工具链 | Scenarios/Standings/Resources/Build | Scenario lint/stat + 共享静态 IR + CI/release quality gate + 资源扫描 + headless runner |
| 参考工程元数据 | 独立 Nova 仓库 | `Nova` gitlink + `.gitmodules`（上游 URL 已登记） |

---

## 三、架构差异

### 3.1 组合根

- **Nova**：`NovaController.cs` 是 prefab 组件聚合器，业务分散在 MonoBehaviour、C# Core 和 Lua 之间。
- **Uni-Story**：`NovaController.gd` 是 Composition Root，直接装配约 32 个核心子系统、协调器与 facade。架构更集中，启动路径清楚，但 `_ctx: Node` 弱类型访问需要继续收敛。

### 3.2 剧本运行时

- **Nova**：Lua VM 执行，`v_`/`gv_` 元表自动映射，Lua 闭包和协程可用。
- **Uni-Story**：`<|...|>` 编译为 `BaseBlock` 的 GDScript，通过 `NovaScriptCompat` 翻译层支持 `l_` label、`v_`/`gv_` 变量、文本插值、branch tuple，以及 `显示名//内部名` canonical speaker。不是完整 Lua VM，只覆盖常用 NovaScript 语义；`box_tint`、`minigame()`、部分输入/快进/文本接口当前仍为 no-op 兼容桩。

### 3.3 存档与回跳

- **Nova**：`CheckpointManager` + `NodeRecord` 历史树 + reached data + `Differ`/`CheckpointUpgrader` 脚本升级。
- **Uni-Story**：已实现 CheckpointManager（node record / reached dialogue / position checkpoint）+ Bookmark metadata（缩略图/时间/章节）+ restore_to_position（最近 checkpoint restore + replay）。脚本升级（diff/upgrader）待后续。

### 3.4 UI 架构

- **Nova**：12 个 controller + prefab 体系。
- **Uni-Story**：8 个 View + 对应 controller，外加 Toast/Confirm/ContextMenu/Backlog/ChoiceList。ViewManager 支持 Title/UI/Game/InTransition/Alert 状态，切出 GameView 自动暂停动画/语音。

### 3.5 动画与 VFX

- **Nova**：`NovaAnimation` 四种域 + Then/And + pause/resume/stop/group + 37 shaderproto 生成 176 shader。
- **Uni-Story**：AnimationSystem 四种域 + pause/resume/stop 按域控制 + 命名 holding group + 12 种 easing + 更丰富的 property。当前有 12 个 `.gdshader` 和对象/全屏后处理注册表，但所谓 effect stack 目前主要保存最多 3 层的状态，实际渲染只把最顶部材质赋给目标，并不是真正的多 pass 合成。`capture_screen()` 能生成捕获纹理，但 `capture_transition()` 目前没有把该纹理绑定到转场 shader，捕获结果尚未参与最终合成。

### 3.6 AutoVoice

- **Nova**：`AutoVoiceConfig` 维护角色、目录前缀和索引，Lua 在 lazy block 后按内部角色名调度并递增编号。
- **Uni-Story**：`AutoVoiceProfile` 把 canonical speaker/别名映射到大小写敏感的角色目录，默认以 6 位编号生成 `.ogg`；`AutoVoiceSystem` 支持一次性 delay、prefix/index tuple、`auto_voice_skip()`、显式 `say()` 覆盖和 pending cue 取消。
- 对话 parser 将 `？？？//张浅野：：...` 分为显示名 `？？？` 与内部名 `张浅野`，并在当前 node 内继承该映射。AutoVoice 使用内部名，UI 使用显示名。
- 自动 cue 在 Backlog 记录前附加精确路径、记录后开始播放；Auto 模式等待 pending delay 和 voice finished。enabled/index/prefix、下一次 delay、override 与当前 cue 都进入 snapshot，restore 时避免历史语音重播或编号双重消费。

### 3.7 Theme、Preload 与 Prefab

- **ThemeManager**：基础主题、作品主题与运行时字号覆盖的分层结构已完成，支持 snapshot/restore。
- **PreloadSystem**：按 image/audio/prefab/other 分桶，具备优先级、LRU、引用计数、进度、取消和 snapshot/restore，核心能力完成。
- **PrefabLoader**：WORLD/UI/PERSISTENT 三分类、按类别清理、对象注册和 snapshot/restore 已完成；PERSISTENT 默认跨节点保留。

### 3.8 测试、lint/stat 与参考工程

- 20 个 `scripts/tests/*_test.gd` 由 `scripts/tests/run_headless_suite.py` 分进程执行；当前 20/20 PASS，约 55 秒；非零退出码、超时或 Godot `SCRIPT ERROR` 都会使 suite 失败。
- 公共 Scenario lint 命令为 `python scripts/tools/scenario_lint.py`，支持 text/JSON、输出文件、失败阈值与文件/目录参数。默认 28 个主剧本结果为 `errors=0`、`warnings=133`、`referenced=372`、`found=370`、`virtual=2`、`missing=0`。
- lint 诊断稳定输出 `path:line:column: severity [rule] message`，退出码为 0/1/2。CI 与 release 使用 `--fail-on error`，因此 warning 默认不阻断导出。
- 公共 Scenario stat 命令为 `python scripts/tools/scenario_stat.py`。它基于不执行 eager code 的共享 IR 做 source inventory，支持 text/JSON、输出文件、`--top` 和文件/目录参数，退出码为 0/2。默认结果为 360 blocks（106 eager/254 lazy）、53 nodes、731 dialogues、111 spoken、620 narration、15434 characters、23 jumps、24 branch options、1 silent entry。
- 独立严格资源扫描已覆盖 `say(speaker, id)`，结果仍为 `referenced=369`、`found=367`、`virtual=2`、`missing=0`；lint 额外包含 branch image 引用。
- `Nova/` 继续作为参考工程 gitlink，`.gitmodules` 已登记 `https://github.com/Lunatic-Works/Nova.git`，新 clone 可恢复其元数据。

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
| `Nova/Lua/auto_voice.lua` + `AutoVoice.cs` | `scripts/runtime/auto_voice_profile.gd` + `auto_voice_system.gd` | ✅ canonical speaker、6 位编号、delay、显式覆盖、Auto/Backlog 与恢复 |
| `Nova/Lua/transition.lua` + `Core/VFX/*` | `scripts/runtime/transition_system.gd` + `vfx_system.gd` | 12 个 shader 资产；stack 仅顶部材质生效，capture texture 尚未合成 |
| `Scripts/UI/Views/*` | `scripts/ui/*` + `scene/view/*` | ✅ 8 视图 + 输入映射 + 通知 |
| `Scripts/UI/InputMapping/*` | `scripts/core/shortcut_manager.gd` | ✅ 按键录制 + 冲突检测 |
| Nova theme/config | `scripts/core/theme_manager.gd` + `resources/themes/*` | ✅ 分层主题核心完成 |
| Nova preload/cache | `scripts/core/preload_system.gd` | ✅ 分桶、LRU、优先级、取消与快照核心完成 |
| Nova prefab lifecycle | `scripts/runtime/prefab_loader.gd` | ✅ WORLD/UI/PERSISTENT 三分类核心完成 |
| `Tools/Scenarios/*` | `scenario_lint.py` / `scenario_linter.gd` + `scenario_analysis.gd` / `scenario_statistics.gd` / `scenario_stat.gd` / `scenario_stat.py` + 资源扫描测试 | 🔄 lint/资源扫描/stat 完成，visualize 待补 |
| `Tools/Standings/*` | 无 | 🔲 缺立绘工具链 |
| `Tools/Resources/*` | 少量 editor 脚本 | 🔲 缺 shader 生成 |

---

## 五、里程碑

| 里程碑 | 目标 | 状态 |
|--------|------|------|
| M1 NovaScript 兼容基线 | 局部 label、变量、stage、文本插值、branch tuple | ✅ |
| M2 Checkpoint 存档骨架 | node record + checkpoint + reached dialogue，任意回跳 | ✅ |
| M3 章节选择与解锁 | ChapterSelectView + start node 解锁 | ✅ |
| M4 动画/VFX 核心 | 动画域/easing/shader 注册表/new effects | 核心完成；多 pass/capture 合成待补 |
| M5 工具链最小集 | 资源扫描 + Scenario lint/stat + 共享静态 IR | ✅；visualize 留待后续 |
| M6 中断协议 | interrupt/fence 协议 | ✅ 核心协议完成；`minigame()` 便捷入口仍为 no-op |
| M7 平台与质量 | 20/20 个 headless 测试 + runner + lint + CI/release 门禁 | ✅ |
| M8 运行时基础设施 | Theme/Preload/Prefab | ✅ 核心完成 |
| M9 AutoVoice | canonical speaker、6 位编号、delay、显式覆盖、Backlog/Auto、存档恢复 | ✅ |

---

## 六、后续方向

按优先级：

1. **Scenario visualize / branch visualization** — 复用 `scenario_analysis.gd` 的 nodes/edges/events，补分支展示和流程可视化工具。
2. **VFX multi-pass / capture transition** — 用 SubViewport 或等价链路实现真正的多材质合成，并让捕获纹理实际参与 dissolve/wipe 转场。
3. **产品化验证** — 增加导出产物启动 smoke、性能基线和完整样例作品；继续验证 Windows/Linux/Android 的真实启动与游玩路径。

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
| `Setup.md` | 环境搭建与架构概览 |
